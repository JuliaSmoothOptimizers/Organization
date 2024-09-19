#!/bin/bash

# Path to the file containing the names
file="../pkgs_data/list_jso_packages.dat"

# Final file containing all the citations in BibTeX
output_file="jso.bib"

# Clear the citation file if it already exists
> "$output_file"

# Read the file line by line
while IFS= read -r line; do
  # Build the URL to download the CITATION.cff file
  cff_url="https://raw.githubusercontent.com/JuliaSmoothOptimizers/${line}.jl/main/CITATION.cff"
  bib_url="https://raw.githubusercontent.com/JuliaSmoothOptimizers/${line}.jl/main/CITATION.bib"

  # Download the CITATION.cff file using curl
  curl -o "${line}_CITATION.cff" "$cff_url"

  # Check if the download was successful
  if [ $? -eq 0 ]; then
    echo "CITATION.cff file downloaded for ${line}."

    # Convert the CFF file to BibTeX and append the result to jso.bib
    cffconvert -f bibtex -i "${line}_CITATION.cff" >> "$output_file"
    echo "" >> "$output_file"  # Add a blank line between entries for readability

    # Remove the downloaded CITATION.cff file
    rm "${line}_CITATION.cff"
  else
    # If CITATION.cff doesn't exist, try to download CITATION.bib directly
    curl -o "${line}_CITATION.bib" -s --fail "$bib_url"
    
    if [ $? -eq 0 ]; then
      echo "CITATION.bib file downloaded for ${line}."

      # Append the CITATION.bib file directly to jso.bib
      cat "${line}_CITATION.bib" >> "$output_file"
      echo "" >> "$output_file"  # Add a blank line between entries for readability

      # Remove the downloaded CITATION.bib file
      rm "${line}_CITATION.bib"
    
    else
      echo "Error: No CITATION.cff or CITATION.bib file found for ${line}."
    fi
  fi
  
  # Apply post-treatment to update BibTeX entries
  # Replace @misc{YourReferenceHere, with @misc{${line}.jl,
  sed -i "s/@misc{[^,]*,@misc{${line}.jl,/g" "$output_file"
done < "$file"

echo "All citations have been concatenated into $output_file."
