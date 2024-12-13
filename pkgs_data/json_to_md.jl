using JSON

# Function to generate a Markdown table from JSON data
function generate_markdown_table(json_file)
    # Read the JSON file
    data = JSON.parsefile(json_file)

    # Extract column headers from the keys of the first dictionary
    headers = keys(data[1])

    # Generate the Markdown table
    markdown = ""

    # Add headers
    markdown *= "| " * join(headers, " | ") * " |\n"
    markdown *= "| " * join(["---" for _ in headers], " | ") * " |\n"

    # Add rows
    for row in data
        values = [get(row, key, "") for key in headers]
        markdown *= "| " * join(values, " | ") * " |\n"
    end

    return markdown
end

# Path to the JSON file
name = "packages"
json_file = name * ".json"  # Replace with the actual path

# Generate the Markdown table
markdown_table = generate_markdown_table(json_file)

# Print the Markdown table
open(name * ".md", "w") do io
    println(io, markdown_table)
end
