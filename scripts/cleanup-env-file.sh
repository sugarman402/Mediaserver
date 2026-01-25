#!/bin/bash
# Creates/updates default.env from .env
# Lines preceded by #sensitive will have their values replaced with CHANGE_ME
# All other lines are copied as-is
# Usage: ./cleanup-env-file.sh

DIR="$(cd "$(dirname "$0")/.." && pwd)"
INPUT_FILE="$DIR/.env"
OUTPUT_FILE="$DIR/default.env"

if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: $INPUT_FILE not found"
    exit 1
fi

strip_next=false

{
    while IFS= read -r line; do
        # Check if this line is a #sensitive marker (case-insensitive)
        if [[ "${line,,}" == "#sensitive" ]]; then
            strip_next=true
            continue  # Don't output the #sensitive marker
        fi
        
        if $strip_next && [[ "$line" == *"="* ]]; then
            # Replace value with CHANGE_ME for sensitive lines
            echo "${line%%=*}=CHANGE_ME"
            strip_next=false
        else
            # Output line as-is
            echo "$line"
            strip_next=false
        fi
    done < "$INPUT_FILE"
} > "$OUTPUT_FILE"

echo "Updated: $OUTPUT_FILE"
