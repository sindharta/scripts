# Find Duplicate Files

This repository includes a macOS-friendly Bash script for finding duplicate files recursively and exporting the results to CSV.

## Script

`find-duplicate-files.sh`

## What it does

- Scans a folder recursively
- Detects duplicate files using SHA-256 and file size
- Writes a CSV report grouped by duplicate set
- Adds an empty row between duplicate groups
- Sorts duplicate groups by file size in descending order

## CSV columns

- `group_id`
- `sha256`
- `file_path`
- `file_size_bytes`
- `date_created`
- `date_modified`

## Usage

```bash
./find-duplicate-files.sh "/path/to/folder"
```

This creates `found-duplicates.csv` in your current working directory.

You can also provide a custom output path:

```bash
./find-duplicate-files.sh "/path/to/folder" "/path/to/report.csv"
```

## Notes

- The first parameter is required and must be a directory.
- The second parameter is optional.
- Only duplicate files are included in the CSV output.
- If no duplicates are found, the CSV file is still created with just the header row.
- The script is intended for macOS and uses the macOS `stat` command format.
