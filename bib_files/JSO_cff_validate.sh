#!/bin/bash

# Path to the file containing the names
file="../pkgs_data/list_jso_packages.dat"

# File to store the validation results
validate_file="validate.dat"

# Clear the validation file if it already exists
> "$validate_file"

# Read the file line by line
while IFS= read -r line; do
  # Build the URL for validation
  url="https://github.com/JuliaSmoothOptimizers/${line}.jl"

  # Run the cffconvert command and append the result to validate.dat
  echo "Validating ${url}..."
  cffconvert --validate --url "$url" >> "$validate_file"
  echo "" >> "$validate_file"  # Add a blank line between results for readability

done < "$file"

echo "Validation results have been concatenated into $validate_file."
