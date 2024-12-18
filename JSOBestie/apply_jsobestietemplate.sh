#!/bin/bash

# Example:
# ./apply_jsobestietemplate.sh "QuadraticModels" "C:\\Users\\username\\"

# Check if sufficient arguments are provided
if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: $0 <package_name> <base_path>"
    echo "Example: $0 MyPackage C:\\Users\\username\\"
    exit 1
fi

# Set variables for paths and values
PACKAGE_NAME=$1
BASE_PATH=$2
PACKAGE_OWNER="JuliaSmoothOptimizers"
SRC_PATH="https://github.com/JuliaSmoothOptimizers/JSOBestieTemplate.jl"
REPO_NAME="JSOBestieTemplate.jl"
TEMP_REPO_DIR="/tmp/$REPO_NAME"
COMMIT="unknown"  # Default value if commit ID cannot be fetched
ADD_BREAKAGE=true
ADD_BENCHMARK=false
ADD_BENCHMARK_CI=true
ADD_CIRRUS_CI=false

# Detect the OS and set paths accordingly
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
    # Windows path setup
    ENV_PATH="${BASE_PATH}.julia\\dev\\Organization\\JSOBestie\\."
    PACKAGE_PATH="${BASE_PATH}.julia\\dev\\${PACKAGE_NAME}.jl\\Project.toml"
    CIRRUS_FILE_PATH="${BASE_PATH}.julia\\dev\\${PACKAGE_NAME}.jl\\.cirrus.yml"
    OUTPUT_FILE="${BASE_PATH}.julia\\dev\\${PACKAGE_NAME}.jl\\.copier-answers.jso.yml"
    JULIA_CMD="julia"
elif [[ "$OSTYPE" == "linux-gnu"* || "$OSTYPE" == "darwin"* ]]; then
    # Linux or macOS path setup
    ENV_PATH="$HOME/.julia/dev/Organization/JSOBestie/."
    PACKAGE_PATH="$HOME/.julia/dev/${PACKAGE_NAME}.jl/Project.toml"
    CIRRUS_FILE_PATH="$HOME/.julia/dev/${PACKAGE_NAME}.jl/.cirrus.yml"
    OUTPUT_FILE="$HOME/.julia/dev/${PACKAGE_NAME}.jl/.copier-answers.jso.yml"
    JULIA_CMD="julia"
else
    echo "Unsupported OS: $OSTYPE"
    exit 1
fi

# Fetch the latest commit ID from the JSOBestieTemplate repository
COMMIT=$(curl -s "https://api.github.com/repos/JuliaSmoothOptimizers/JSOBestieTemplate.jl/commits/main" | grep '"sha":' | head -n 1 | sed -E 's/.*"sha": "([^"]+)".*/\1/')

# Check if Project.toml exists
if [ ! -f "$PACKAGE_PATH" ]; then
    echo "Project.toml file not found at $PACKAGE_PATH."
    exit 1
fi

# Check if .cirrus.yml exists and set ADD_CIRRUS_CI
if [ -f "$CIRRUS_FILE_PATH" ]; then
    ADD_CIRRUS_CI=true
fi

# Extract the UUID from the Project.toml file
UUID=$(grep -oP '(?<=uuid = ")[^"]+' "$PACKAGE_PATH")
if [ -z "$UUID" ]; then
    echo "UUID not found in Project.toml."
    exit 1
fi

# Create the .copier-answers.jso.yml file with the specified content
cat << EOF > "$OUTPUT_FILE"
PackageName: "$PACKAGE_NAME"
PackageOwner: "$PACKAGE_OWNER"
PackageUUID: "$UUID"
_src_path: "$SRC_PATH"
_commit: "$COMMIT"
AddBreakage: $ADD_BREAKAGE
AddBenchmark: $ADD_BENCHMARK
AddBenchmarkCI: $ADD_BENCHMARK_CI
AddCirrusCI: $ADD_CIRRUS_CI
EOF

echo "Created file $OUTPUT_FILE with the specified content."

# Execute the Julia commands
$JULIA_CMD --project=$ENV_PATH -e 'using Pkg; Pkg.update(); Pkg.instantiate()'
yes | $JULIA_CMD --project=$ENV_PATH -e "using BestieTemplate; BestieTemplate.Copier.copy(\"$SRC_PATH\", raw\"${BASE_PATH}.julia\\dev\\${PACKAGE_NAME}.jl\", answers_file = \".copier-answers.jso.yml\")"
# Make sure the formatter is correct
$JULIA_CMD --project=$ENV_PATH -e "using Pkg; Pkg.add(\"JuliaFormatter\"); using JuliaFormatter; format(raw\"${BASE_PATH}.julia/dev/${PACKAGE_NAME}.jl\", verbose = false)"
