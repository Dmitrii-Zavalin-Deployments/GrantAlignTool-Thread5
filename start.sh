#!/bin/bash

# Function to print a separator for better readability
print_separator() {
    echo "----------------------------------------"
}

# Function to refresh the access token
refresh_access_token() {
    local refresh_token=$1
    local client_id=$2
    local client_secret=$3
    local url="https://api.dropbox.com/oauth2/token"
    local data="grant_type=refresh_token&refresh_token=$refresh_token&client_id=$client_id&client_secret=$client_secret"
    local response=$(curl -s -X POST $url -d $data)
    echo $(echo $response | jq -r '.access_token')
}

# Function to download PDFs from Dropbox
download_pdfs_from_dropbox() {
    local dropbox_folder=$1
    local local_folder=$2
    local access_token=$3

    mkdir -p "$local_folder"
    local result=$(curl -s -X POST https://api.dropboxapi.com/2/files/list_folder \
        --header "Authorization: Bearer $access_token" \
        --header "Content-Type: application/json" \
        --data "{\"path\": \"$dropbox_folder\"}")

    local entries=$(echo $result | jq -c '.entries[]')
    for entry in $entries; do
        local name=$(echo $entry | jq -r '.name')
        local path_lower=$(echo $entry | jq -r '.path_lower')
        if [[ $name == *.pdf ]]; then
            curl -s -X POST https://content.dropboxapi.com/2/files/download \
                --header "Authorization: Bearer $access_token" \
                --header "Dropbox-API-Arg: {\"path\": \"$path_lower\"}" \
                --output "$local_folder/$name"
        fi
    done
}

# Ask the user to enter Dropbox credentials
echo "Please enter your Dropbox credentials:"
read -p "Enter Dropbox App Key (client_id): " client_id
read -p "Enter Dropbox App Secret (client_secret): " client_secret
read -p "Enter Dropbox Refresh Token (refresh_token): " refresh_token
print_separator

# Ask the user to enter the project name from the Projects folder
read -p "Enter the name (without extension) of the project from the Projects folder: " project_name
print_separator

# Ask the user to enter the number of runs or use default value 15
read -p "Enter the number of runs (default is 15): " num_runs
num_runs=${num_runs:-15}
print_separator

# Directory containing the PDF files
pdf_dir="pdfs"
dropbox_folder="/GrantAlignTool"

# Ensure the pdfs folder is clean
echo "Cleaning up the folder $pdf_dir..."
rm -rf "$pdf_dir"
print_separator

# Refresh the access token
echo "Refreshing Dropbox access token..."
access_token=$(refresh_access_token $refresh_token $client_id $client_secret)
print_separator

# Download PDFs from Dropbox
echo "Downloading PDF files from Dropbox folder $dropbox_folder..."
download_pdfs_from_dropbox $dropbox_folder $pdf_dir $access_token
print_separator

# Get all PDF file names from the directory and store them in an array
echo "Fetching PDF files from $pdf_dir..."
pdf_files=($(ls "$pdf_dir"/*.pdf | xargs -n 1 basename))
echo "Found ${#pdf_files[@]} PDF files."
print_separator

# Calculate the number of files per run
num_files=${#pdf_files[@]}
files_per_run=$((num_files / num_runs))
remainder=$((num_files % num_runs))

# Split the array into the number of runs
echo "Splitting files into $num_runs runs..."
start_index=0
for ((i=0; i<num_runs; i++)); do
    end_index=$((start_index + files_per_run))
    if [ $i -lt $remainder ]; then
        end_index=$((end_index + 1))
    fi
    run_files=("${pdf_files[@]:start_index:end_index-start_index}")
    echo "Run $((i+1)) files: ${run_files[@]}"
    start_index=$end_index
    print_separator
done

# Delete the pdfs folder
echo "Deleting the folder $pdf_dir..."
rm -rf "$pdf_dir"
print_separator

echo "All tasks completed successfully!"