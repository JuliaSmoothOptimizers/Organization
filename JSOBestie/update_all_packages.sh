#!/bin/bash

# Path to the file containing the list of package names
PKG_LIST_URL="https://raw.githubusercontent.com/JuliaSmoothOptimizers/Organization/main/pkgs_data/list_jso_packages.dat"
PKG_LIST_FILE="list_jso_packages.dat"

# Download the package list file
curl -o "$PKG_LIST_FILE" "$PKG_LIST_URL"

# Check if the file was downloaded successfully
if [ ! -f "$PKG_LIST_FILE" ]; then
    echo "Failed to download $PKG_LIST_URL."
    exit 1
fi

DEV_PATH="$HOME/.julia/dev"
SETUP_PATH="$DEV_PATH/Organization/JSOBestie"
BRANCH_NAME="update-jso-bestietemplate"

# Read each package name from the file and process it
while IFS= read -r PACKAGE_NAME; do
    echo "Processing package: $PACKAGE_NAME"
    
    # Define the package path and repository URL
    REPO_URL="https://github.com/JuliaSmoothOptimizers/${PACKAGE_NAME}.jl"
    PACKAGE_PATH="${DEV_PATH}/${PACKAGE_NAME}.jl"

    # Check if the package has already been cloned
    if [ -d "$PACKAGE_PATH" ]; then
        echo "Package $PACKAGE_NAME already cloned. Skipping clone step."
    else
        # Clone the package repository if not already cloned
        git clone "$REPO_URL" "$PACKAGE_PATH"
    fi

    # Navigate to the package directory
    cd "$PACKAGE_PATH" || { echo "Failed to enter $PACKAGE_PATH"; continue; }

    # Create and checkout a new branch
    # Check if the branch already exists
    if git rev-parse --verify "$BRANCH_NAME" >/dev/null 2>&1; then
        echo "Branch $BRANCH_NAME already exists. Switching to it."
        git checkout "$BRANCH_NAME"
    else
        echo "Creating and switching to new branch $BRANCH_NAME."
        git checkout -b "$BRANCH_NAME"
    fi

    # Apply the setup_package.sh script with an absolute path
    "$SETUP_PATH/apply_jsobestietemplate.sh" "$PACKAGE_NAME"

    # Commit changes
    git add .
    git commit -m "Apply JSOBestieTemplate update"

    # Push the new branch to origin
    git push origin "$BRANCH_NAME"

    # Make a pull request (requires GitHub CLI)
    gh pr create --title "Update with JSOBestieTemplate for $PACKAGE_NAME" --body "Automated update using JSOBestieTemplate" --base main

    # Navigate back to the initial directory
    cd - || exit

done < "$PKG_LIST_FILE"

echo "All packages processed."
