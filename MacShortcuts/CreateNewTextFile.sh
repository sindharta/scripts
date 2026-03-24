dir="$1"


name_ext="untitled.txt"

# If input was a file, go to its directory
if [ -f "$dir" ]; then
    abs_dir="$(dirname "$dir")"
else
    abs_dir="$dir"
fi



# Split name / extension safely
if [[ "$name_ext" == *.* && "$name_ext" != .* ]]; then
    name="${name_ext%.*}"
    ext=".${name_ext##*.}"
else
    name="$name_ext"
    ext=""
fi

# Initial path
filepath="${abs_dir}/${name}${ext}"

# Increment if file exists
i=2
while [ -e "$filepath" ]; do
    filepath="${abs_dir}/${name}_${i}${ext}"
    ((i++))
done

# Create file
touch "$filepath"

