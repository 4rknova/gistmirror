#!/bin/bash

# Configuration file
config_file=".gistmirror.config"

# Function to fetch gist URLs
fetch_gist_urls() {
    local page_num=1
    while true; do
        local curl_output=$(curl -s -H "Authorization: token $token" "https://api.github.com/gists?page=$page_num")
        # Check if the output is empty
        if [ -z "$curl_output" ]; then
            break
        fi
        # Extract gist URLs and process them
        local urls=$(echo "$curl_output" | jq -r '.[] | .html_url + " " + .description')
        if [ -z "$urls" ]; then
            break
        fi
        echo "$urls"
        ((page_num++))
    done
}

# Create an empty config file if it doesn't exist
if [ ! -f "$config_file" ]; then
    echo "Creating empty config file: $config_file"
    cat <<EOF > "$config_file"
token=
output_dir=
EOF
fi

# Read the access token and output directory from the config file
source "$config_file"

# Check if all required configurations are set
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

# Fetch gist URLs from GitHub API
urls=$(fetch_gist_urls)

# Extract gist URLs and process them
while read -r gist_info; do
    gist_url=$(echo "$gist_info" | awk '{print $1}')
    gist_title=$(echo "$gist_info" | cut -d ' ' -f2-)
    
    # Extract the gist ID from the URL
    gist_id=$(basename "$gist_url" .git)
    
    # Clone the repository or report an error if it's not a valid repository
    if git ls-remote "$gist_url" &>/dev/null; then
        if [ -d "$output_dir/$gist_id" ]; then
            echo "Pulling $gist_title..."
            git -C "$output_dir/$gist_id" pull origin > /dev/null 2>&1
            if [ $? -ne 0 ]; then
                echo "Error: Failed to update $gist_title."
            fi
        else
            echo "Cloning $gist_title..."
            git -C "$output_dir" clone "$gist_url" > /dev/null 2>&1
            if [ $? -ne 0 ]; then
                echo "Error: Failed to clone $gist_title."
            fi
        fi
    else
        echo "Error: $gist_title is not a valid Git repository."
    fi
done <<< "$urls"
