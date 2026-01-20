#!/bin/bash

input_file=".env"

while IFS= read -r line
do
  if [[ -z "$line" ]]; then
    # Empty line - print as is
    echo ""
  elif [[ "$line" == *"="* ]]; then
    # Line contains '=', preserve key and '=' only
    key="${line%%=*}="
    echo "$key"
  else
    # Line with no '=' - print as is
    echo "$line"
  fi
done < "$input_file"
