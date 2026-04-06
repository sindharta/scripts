# Find Duplicate Files

This repository includes a macOS-friendly Bash script for finding duplicate files recursively and exporting the results to CSV.

## Script

`bin/find-duplicate-files.sh`

## What it does

- Scans a folder recursively
- Detects duplicate files using a staged check: file size, then `cksum`, then SHA-256
- Writes a CSV report grouped by duplicate set
- Uses the SHA-256 value as the group code shown above each duplicate set
- Adds an empty row between duplicate groups
- Sorts duplicate groups by file size in descending order
- Shows progress for each major processing step

## CSV format

Each duplicate group is written like this:

```csv
"sha256-group-code"
"/full/path/to/file1.txt","123","2026-04-05 12:00:00","2026-04-05 12:00:00"
"/full/path/to/file2.txt","123","2026-04-05 12:00:00","2026-04-05 12:00:00"
,,,
```

The file rows contain:

- `file_path`
- `file_size_bytes`
- `date_created`
- `date_modified`

## Usage

```bash
./bin/find-duplicate-files.sh "/path/to/folder"
```

This creates `found-duplicates.csv` in your current working directory.

You can also provide a custom output path:

```bash
./bin/find-duplicate-files.sh "/path/to/folder" "/path/to/report.csv"
```

To print the external commands being run:

```bash
./bin/find-duplicate-files.sh --verbose "/path/to/folder"
```

The script also prints progress to the console, including the current step. The initial file-size scan shows a live processed-file count, and later stages show percentages.

## Notes

- The first parameter is required and must be a directory.
- The second parameter is optional.
- Use `--verbose` to print the external commands executed by the script.
- For speed, SHA-256 is only computed for files that already matched on file size and `cksum`.
- Only duplicate files are included in the CSV output.
- If no duplicates are found, the CSV file is created as an empty file.
- The script is intended for macOS and uses the macOS `stat` command format.
