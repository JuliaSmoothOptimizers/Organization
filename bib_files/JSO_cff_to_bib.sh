#!/bin/bash

# Path to the file containing the names
file="../pkgs_data/list_jso_packages.dat"

# Final file containing all the citations in BibTeX
output_file="jso.bib"

# Clear the citation file if it already exists
> "$output_file"

# Final file containing all the citations in BibTeX
output_int_file="jso_parse.bib"

# Read the file line by line
while IFS= read -r line; do
  # Skip JSOTemplate as it is not a real citation file
  if [ "$line" == "JSOTemplate" ]; then
    echo "Skipping JSOTemplate."
    continue
  fi

  # Build the URL to download the CITATION.cff file
  cff_url="https://raw.githubusercontent.com/JuliaSmoothOptimizers/${line}.jl/main/CITATION.cff"
  bib_url="https://raw.githubusercontent.com/JuliaSmoothOptimizers/${line}.jl/main/CITATION.bib"

  # Check if CITATION.cff file exists
  http_status=$(curl -o /dev/null -s -w "%{http_code}\n" "$cff_url")

  # Check if the download was successful
  if [ "$http_status" -eq 200 ]; then
    echo "CITATION.cff file found for ${line}."

    # Download the CITATION.cff file
    curl -o "${line}_CITATION.cff" "$cff_url"

    # Convert the CFF file to BibTeX and append the result to jso.bib
    #cffconvert -f bibtex -i "${line}_CITATION.cff" >> "$output_file"
    > "$output_int_file"
    ruby cff_to_bib.rb "${line}_CITATION.cff" >> "$output_int_file"
    # Replace @misc{YourReferenceHere, with @misc{${line}.jl,
    sed -i "s|@misc{[^,]*|@software{${line}_jl|g" "$output_int_file"
    sed -i "s|@Misc{[^,]*|@software{${line}_jl|g" "$output_int_file"
    sed -i "s|@article{[^,]*|@article{${line}_jl|g" "$output_int_file"
    sed -i "s|@software{[^,]*|@software{${line}_jl|g" "$output_int_file"
    cat "$output_int_file" >> "$output_file"
    echo "" >> "$output_file"  # Add a blank line between entries for readability

    # Remove the downloaded CITATION.cff file
    rm "${line}_CITATION.cff"
  else
    # echo "CITATION.cff file not found for ${line}. Checking for CITATION.bib."

    # Check if CITATION.bib file exists
    http_status=$(curl -o /dev/null -s -w "%{http_code}\n" "$bib_url")

    if [ "$http_status" -eq 200 ]; then
      echo "CITATION.bib file found for ${line}."

      # Download the CITATION.bib file
      curl -o "${line}_CITATION.bib" "$bib_url"

      # Append the CITATION.bib file directly to jso.bib
      > "$output_int_file"
      cat "${line}_CITATION.bib" >> "$output_int_file"
      # Replace @misc{YourReferenceHere, with @misc{${line}.jl,
      sed -i "s|@misc{[^,]*|@software{${line}_jl|g" "$output_int_file"
      sed -i "s|@Misc{[^,]*|@software{${line}_jl|g" "$output_int_file"
      sed -i "s|@article{[^,]*|@article{${line}_jl|g" "$output_int_file"
      sed -i "s|@software{[^,]*|@software{${line}_jl|g" "$output_int_file"
      cat "$output_int_file" >> "$output_file"
      echo "" >> "$output_file"  # Add a blank line between entries for readability

      # Remove the downloaded CITATION.bib file
      rm "${line}_CITATION.bib"
    
    else
      echo "Error: No CITATION.cff or CITATION.bib file found for ${line}."
    fi
  fi
done < "$file"

# Normalize the title fields by ensuring double braces {{...}} for all titles
sed -i "s|title = {\(.*\)}|title = {{\1}}|g" "$output_file"

rm "$output_int_file"

echo "All citations have been concatenated into $output_file."
