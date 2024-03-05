#!/bin/bash

# Configuration file
config_file=".gistmirror.config"

# Create an empty config file if it doesn't exist
if [ ! -f "$config_file" ]; then
    echo "Creating empty config file: $config_file"
    cat <<EOF > "$config_file"
token=
output_dir=
EOF
fi

# Read the access token and output directory from the config file
while IFS='=' read -r key value; do
    case $key in
        token)
            token="$value"
            ;;
        output_dir)
            output_dir="$value"
            ;;
        *)
            ;;
    esac
done < "$config_file"

# Check if both token and output_dir are set
if [ -z "$token" ] || [ -z "$output_dir" ]; then
    echo "Token or output directory not found in config file."
    exit 1
fi

# Convert relative output directory path to absolute path
if ! [[ "$output_dir" =~ ^/ ]]; then
    output_dir="$(realpath "$output_dir")"
fi

# Create the output directory if it doesn't exist
if [ ! -d "$output_dir" ]; then
    echo "Creating directory $output_dir..."
    mkdir -p "$output_dir"
fi

# Create a temporary file to store gist URLs
temp_file=$(mktemp)

# Fetch gist URLs from GitHub API
echo "Fetching gist URLs..."
curl_output=$(curl -s -H "Authorization: token $token" "https://api.github.com/gists")

# Check if curl command was successful
if [ $? -ne 0 ]; then
    echo "Error: Failed to fetch gist URLs."
    exit 1
fi

# Check if the output is empty
if [ -z "$curl_output" ]; then
    echo "Error: No gist URLs returned."
    exit 1
fi

# Extract gist URLs and process them
echo "$curl_output" | grep -Eo 'https://gist\.github\.com/[[:alnum:]]+\.git' | sort -u > "$temp_file"

# Read each gist URL from the temporary file and clone/update it
echo "Cloning/Updating gists..."
while IFS= read -r gist_url; do
    # Extract the gist ID from the URL
    gist_id=$(basename "$gist_url" .git)
    pull_url="https://gist.github.com/$gist_id"

    # Check if the repository directory already exists
    if [ -d "$output_dir/$gist_id" ]; then
        # If exists, update the repository
        echo "Updating $gist_id..."
        git_output=$(git -C "$output_dir/$gist_id" pull 2>&1)
        # Check if git command had errors
        if [ $? -ne 0 ]; then
            echo "Error: $git_output"
        fi
    else
        # If not, clone the repository
        echo "Cloning $gist_id..."
        git_output=$(git -C "$output_dir" clone "$gist_url" 2>&1)
        # Check if git command had errors
        if [ $? -ne 0 ]; then
            echo "Error: $git_output"
        fi
    fi
done < "$temp_file"

# Clean up temporary file
rm -f "$temp_file"

echo "Sync complete."

