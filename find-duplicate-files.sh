#!/bin/bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: find-duplicate-files.sh <folder_to_scan> [output_csv]

Arguments:
  folder_to_scan  Folder to scan recursively for duplicate files
  output_csv      Optional path to the CSV file that will be created
                  Default: found-duplicates.csv
EOF
}

csv_escape() {
  local value="${1//\"/\"\"}"
  printf '"%s"' "$value"
}

write_group() {
  local group_hash="$1"
  local group_size="$2"
  local group_file="$3"
  shift 3

  local file_path created modified
  for file_path in "$@"; do
    created="$(stat -f "%SB" -t "%Y-%m-%d %H:%M:%S" "$file_path")"
    modified="$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$file_path")"

    {
      csv_escape "$group_hash"
      printf ','
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

inventory_file="$(mktemp)"
sorted_file="$(mktemp)"
groups_dir="$(mktemp -d)"
groups_index_file="$(mktemp)"

cleanup() {
  rm -f "$inventory_file" "$sorted_file" "$groups_index_file"
  rm -rf "$groups_dir"
}

trap cleanup EXIT

while IFS= read -r -d '' file_path; do
  file_size="$(stat -f "%z" "$file_path")"
  file_hash="$(shasum -a 256 "$file_path" | awk '{print $1}')"
  printf '%s\t%s\t%s\n' "$file_hash" "$file_size" "$file_path" >> "$inventory_file"
done < <(find "$SEARCH_DIR" -type f -print0 2>/dev/null)

sort -t $'\t' -k1,1 -k2,2 -k3,3 "$inventory_file" > "$sorted_file"

printf '"group_id","sha256","file_path","file_size_bytes","date_created","date_modified"\n' > "$OUTPUT_CSV"

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
display_group_id=0
while IFS=$'\t' read -r _ group_file; do
  if [ ! -f "$group_file" ]; then
    continue
  fi

  display_group_id=$((display_group_id + 1))

  if [ "$group_files_found" -eq 1 ]; then
    printf '\n' >> "$OUTPUT_CSV"
  fi

  while IFS= read -r group_line; do
    printf '"%s",%s\n' "$display_group_id" "$group_line" >> "$OUTPUT_CSV"
  done < "$group_file"

  group_files_found=1
done < <(sort -t $'\t' -k1,1nr -k2,2 "$groups_index_file")

printf 'CSV report written to %s\n' "$OUTPUT_CSV"
