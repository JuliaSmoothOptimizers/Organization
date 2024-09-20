require 'cff'

# Check if a file was passed as an argument
if ARGV.length != 1
  puts "Usage: ruby hello.rb <path_to_CITATION.cff>"
  exit
end

# Read the argument (first argument from ARGV)
cff_file = ARGV[0]

# Read the CFF file and convert it to BibTeX
begin
  cff = CFF::File.read(cff_file)
  puts cff.to_bibtex
rescue => e
  puts "Error reading the file: #{e.message}"
end
