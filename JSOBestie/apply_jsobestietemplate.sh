#!/bin/bash

# Check if an argument is provided
if [ -z "$1" ]; then
    echo "Please provide the package name as an argument."
    exit 1
fi

# Set variables for paths and values
PACKAGE_NAME=$1
PACKAGE_OWNER="JuliaSmoothOptimizers"
SRC_PATH="https://github.com/JuliaSmoothOptimizers/JSOBestieTemplate.jl"
COMMIT="v0.13.0"
ADD_BREAKAGE=true
ADD_BENCHMARK=false
ADD_BENCHMARK_CI=true

# Detect the OS and set paths accordingly
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
    # Windows path setup
    ENV_PATH="C:\\Users\\tangi\\.julia\\dev\\Organization\\JSOBestie\\."
    PACKAGE_PATH="C:\\Users\\tangi\\.julia\\dev\\${PACKAGE_NAME}.jl\\Project.toml"
    OUTPUT_FILE="C:\\Users\\tangi\\.julia\\dev\\${PACKAGE_NAME}.jl\\copier-answers.jso.yml"
    JULIA_CMD="julia"
elif [[ "$OSTYPE" == "linux-gnu"* || "$OSTYPE" == "darwin"* ]]; then
    # Linux or macOS path setup
    ENV_PATH="$HOME/.julia/dev/Organization/JSOBestie/."
    PACKAGE_PATH="$HOME/.julia/dev/${PACKAGE_NAME}.jl/Project.toml"
    OUTPUT_FILE="$HOME/.julia/dev/${PACKAGE_NAME}.jl/copier-answers.jso.yml"
    JULIA_CMD="julia"
else
    echo "Unsupported OS: $OSTYPE"
    exit 1
fi

# Check if Project.toml exists
if [ ! -f "$PACKAGE_PATH" ]; then
    echo "Project.toml file not found at $PACKAGE_PATH."
    exit 1
fi

# Extract the UUID from the Project.toml file
UUID=$(grep -oP '(?<=uuid = ")[^"]+' "$PACKAGE_PATH")
if [ -z "$UUID" ]; then
    echo "UUID not found in Project.toml."
    exit 1
fi

# Create the copier-answers.jso.yml file with the specified content
cat << EOF > "$OUTPUT_FILE"
PackageName: "$PACKAGE_NAME"
PackageOwner: "$PACKAGE_OWNER"
PackageUUID: "$UUID"
_src_path: "$SRC_PATH"
_commit: "$COMMIT"
AddBreakage: $ADD_BREAKAGE
AddBenchmark: $ADD_BENCHMARK
AddBenchmarkCI: $ADD_BENCHMARK_CI
EOF

echo "Created file $OUTPUT_FILE with the specified content."

# Execute the Julia commands
$JULIA_CMD --project=$ENV_PATH -e 'using Pkg; Pkg.update(); Pkg.instantiate()'
yes | $JULIA_CMD --project=$ENV_PATH -e "using BestieTemplate; BestieTemplate.Copier.copy(\"$SRC_PATH\", raw\"C:\Users\tangi\.julia\dev\\${PACKAGE_NAME}.jl\", answers_file = \".copier-answers.jso.yml\")"
