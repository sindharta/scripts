#!/bin/bash

set -euo pipefail

usage() {
    cat <<'EOF'
Usage: find-duplicate-files.sh [--verbose] <folder_to_scan> [output_csv]

Arguments:
    folder_to_scan  Folder to scan recursively for duplicate files
    output_csv      Optional path to the CSV file that will be created
                    Default: found-duplicates.csv

Options:
    --verbose       Print the external commands being run
EOF
}

csv_escape() {
    local value="${1//\"/\"\"}"
    printf '"%s"' "$value"
}

absolute_path() {
    local target="$1"
    local parent_dir base_name

    parent_dir="$(cd "$(dirname "$target")" && pwd -P)"
    base_name="$(basename "$target")"
    printf '%s/%s\n' "$parent_dir" "$base_name"
}

log_command() {
    if [ "${VERBOSE:-0}" -eq 1 ]; then
        printf '+' >&2
        for arg in "$@"; do
            printf ' %q' "$arg" >&2
        done
        printf '\n' >&2
    fi
}

write_group() {
    local group_hash="$1"
    local group_size="$2"
    local group_file="$3"
    shift 3

    csv_escape "$group_hash" > "$group_file"
    printf '\n' >> "$group_file"

    local file_path created modified
    for file_path in "$@"; do
        log_command stat -f "%SB" -t "%Y-%m-%d %H:%M:%S" "$file_path"
        created="$(stat -f "%SB" -t "%Y-%m-%d %H:%M:%S" "$file_path")"
        log_command stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$file_path"
        modified="$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$file_path")"

        {
            csv_escape "$file_path"
            printf ','
            csv_escape "$group_size"
            printf ','
            csv_escape "$created"
            printf ','
            csv_escape "$modified"
            printf '\n'
        } >> "$group_file"
    done
}

VERBOSE=0

while [ "$#" -gt 0 ]; do
    case "$1" in
        --verbose)
            VERBOSE=1
            shift
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            break
            ;;
    esac
done

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    usage >&2
    exit 1
fi

SEARCH_DIR="$1"
OUTPUT_CSV="${2:-found-duplicates.csv}"

if [ ! -d "$SEARCH_DIR" ]; then
    printf 'Error: folder does not exist or is not a directory: %s\n' "$SEARCH_DIR" >&2
    exit 1
fi

mkdir -p "$(dirname "$OUTPUT_CSV")"

SEARCH_DIR="$(cd "$SEARCH_DIR" && pwd -P)"
OUTPUT_CSV="$(absolute_path "$OUTPUT_CSV")"

inventory_file="$(mktemp)"
size_sorted_file="$(mktemp)"
size_candidates_file="$(mktemp)"
cksum_inventory_file="$(mktemp)"
cksum_sorted_file="$(mktemp)"
hash_candidates_file="$(mktemp)"
hash_inventory_file="$(mktemp)"
sorted_file="$(mktemp)"
groups_dir="$(mktemp -d)"
groups_index_file="$(mktemp)"
output_tmp_file="$(mktemp)"

cleanup() {
    rm -f \
        "$inventory_file" \
        "$size_sorted_file" \
        "$size_candidates_file" \
        "$cksum_inventory_file" \
        "$cksum_sorted_file" \
        "$hash_candidates_file" \
        "$hash_inventory_file" \
        "$sorted_file" \
        "$groups_index_file" \
        "$output_tmp_file"
    rm -rf "$groups_dir"
}

trap cleanup EXIT

while IFS= read -r -d '' file_path; do
    file_size="${file_path%% *}"
    file_path="${file_path#* }"
    printf '%s\t%s\n' "$file_size" "$file_path" >> "$inventory_file"
done < <(
    log_command find "$SEARCH_DIR" -type f ! -path "$OUTPUT_CSV" -exec stat -f "%z %N" '{}' +
    find "$SEARCH_DIR" -type f ! -path "$OUTPUT_CSV" -exec stat -f '%z %N' {} + 2>/dev/null
)

log_command sort -t $'\t' -k1,1n -k2,2 "$inventory_file"
sort -t $'\t' -k1,1n -k2,2 "$inventory_file" > "$size_sorted_file"

current_size=""
size_group_count=0
size_group_files=()

while IFS=$'\t' read -r file_size file_path; do
    if [ "$file_size" = "$current_size" ]; then
        size_group_files+=("$file_path")
        size_group_count=$((size_group_count + 1))
        continue
    fi

    if [ "$size_group_count" -gt 1 ]; then
        for candidate_path in "${size_group_files[@]}"; do
            printf '%s\t%s\n' "$current_size" "$candidate_path" >> "$size_candidates_file"
        done
    fi

    current_size="$file_size"
    size_group_files=("$file_path")
    size_group_count=1
done < "$size_sorted_file"

if [ "$size_group_count" -gt 1 ]; then
    for candidate_path in "${size_group_files[@]}"; do
        printf '%s\t%s\n' "$current_size" "$candidate_path" >> "$size_candidates_file"
    done
fi

while IFS=$'\t' read -r file_size file_path; do
    log_command cksum "$file_path"
    cksum_output="$(cksum "$file_path")"
    cksum_value="${cksum_output%% *}"
    printf '%s\t%s\t%s\n' "$cksum_value" "$file_size" "$file_path" >> "$cksum_inventory_file"
done < "$size_candidates_file"

log_command sort -t $'\t' -k1,1 -k2,2n -k3,3 "$cksum_inventory_file"
sort -t $'\t' -k1,1 -k2,2n -k3,3 "$cksum_inventory_file" > "$cksum_sorted_file"

current_cksum=""
current_size=""
cksum_group_count=0
cksum_group_files=()

while IFS=$'\t' read -r cksum_value file_size file_path; do
    if [ "$cksum_value" = "$current_cksum" ] && [ "$file_size" = "$current_size" ]; then
        cksum_group_files+=("$file_path")
        cksum_group_count=$((cksum_group_count + 1))
        continue
    fi

    if [ "$cksum_group_count" -gt 1 ]; then
        for candidate_path in "${cksum_group_files[@]}"; do
            printf '%s\t%s\n' "$current_size" "$candidate_path" >> "$hash_candidates_file"
        done
    fi

    current_cksum="$cksum_value"
    current_size="$file_size"
    cksum_group_files=("$file_path")
    cksum_group_count=1
done < "$cksum_sorted_file"

if [ "$cksum_group_count" -gt 1 ]; then
    for candidate_path in "${cksum_group_files[@]}"; do
        printf '%s\t%s\n' "$current_size" "$candidate_path" >> "$hash_candidates_file"
    done
fi

while IFS=$'\t' read -r file_size file_path; do
    log_command shasum -a 256 "$file_path"
    log_command awk '{print $1}'
    file_hash="$(shasum -a 256 "$file_path" | awk '{print $1}')"
    printf '%s\t%s\t%s\n' "$file_hash" "$file_size" "$file_path" >> "$hash_inventory_file"
done < "$hash_candidates_file"

log_command sort -t $'\t' -k1,1 -k2,2n -k3,3 "$hash_inventory_file"
sort -t $'\t' -k1,1 -k2,2n -k3,3 "$hash_inventory_file" > "$sorted_file"

printf '"path","size","date created","date modified"\n' > "$output_tmp_file"

current_hash=""
current_size=""
group_id=0
group_count=0
group_files=()

while IFS=$'\t' read -r file_hash file_size file_path; do
    if [ "$file_hash" = "$current_hash" ] && [ "$file_size" = "$current_size" ]; then
        group_files+=("$file_path")
        group_count=$((group_count + 1))
        continue
    fi

    if [ "$group_count" -gt 1 ]; then
        group_id=$((group_id + 1))
        group_file="$groups_dir/group_$(printf '%06d' "$group_id").csv"
        write_group "$current_hash" "$current_size" "$group_file" "${group_files[@]}"
        printf '%s\t%s\n' "$current_size" "$group_file" >> "$groups_index_file"
    fi

    current_hash="$file_hash"
    current_size="$file_size"
    group_files=("$file_path")
    group_count=1
done < "$sorted_file"

if [ "$group_count" -gt 1 ]; then
    group_id=$((group_id + 1))
    group_file="$groups_dir/group_$(printf '%06d' "$group_id").csv"
    write_group "$current_hash" "$current_size" "$group_file" "${group_files[@]}"
    printf '%s\t%s\n' "$current_size" "$group_file" >> "$groups_index_file"
fi

group_files_found=0
log_command sort -t $'\t' -k1,1nr -k2,2 "$groups_index_file"
while IFS=$'\t' read -r group_size group_file; do
    if [ ! -f "$group_file" ]; then
        continue
    fi

    if [ "$group_files_found" -eq 1 ]; then
        printf ',,,\n' >> "$output_tmp_file"
    fi

    group_hash=""
    while IFS= read -r first_line; do
        group_hash="${first_line%%,*}"
        break
    done < "$group_file"

    if [ -n "$group_hash" ]; then
        printf '%s\n' "$group_hash" >> "$output_tmp_file"
    fi

    skip_first_line=1
    while IFS= read -r group_line; do
        if [ "$skip_first_line" -eq 1 ]; then
            skip_first_line=0
            continue
        fi

        printf '%s\n' "$group_line" >> "$output_tmp_file"
    done < "$group_file"

    group_files_found=1
done < <(sort -t $'\t' -k1,1nr -k2,2 "$groups_index_file")

log_command mv "$output_tmp_file" "$OUTPUT_CSV"
mv "$output_tmp_file" "$OUTPUT_CSV"
printf 'CSV report written to %s\n' "$OUTPUT_CSV"
