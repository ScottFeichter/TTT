#!/bin/bash

# This script:

# 1. Sets the AWS CLI output format to JSON for consistent parsing

# 2. Creates a formatted header for the output

# 3. Uses the aws amplify list-apps command to get all apps [1]

# 4. Uses the --query parameter to extract only the name, status, and appId fields

# 5. Formats the output in a clean, tabulated format

#######################################################

# 1. To use this script:

# 2. Save it to a file (e.g., list-amplify-apps.sh)

# 3. Make it executable: chmod +x list-amplify-apps.sh

# 4. Run it: ./list-amplify-apps.sh

#######################################################

# Make sure you have:

# 1. AWS CLI installed [2]

# 2. Proper AWS credentials configured

# 3. Appropriate permissions to list Amplify apps

#######################################################

# The output will look something like this:

# Listing Amplify Apps...
# ----------------------------------------
# APP NAME                                 STATUS              APP ID
# ----------------------------------------
# my-react-app                            ACTIVE              d123456789
# my-next-app                             ACTIVE              a987654321
# test-application                        DELETED             b111222333
# ----------------------------------------



# HERE IS THE SCRIPT:
#######################################################

# Set the output format to ensure consistent JSON parsing
export AWS_DEFAULT_OUTPUT="json"

# Get the list of apps and format the output
echo "Listing Amplify Apps..."
echo "----------------------------------------"
printf "%-50s %-20s\n" "APP NAME" "APP ID"
echo "----------------------------------------"

# Get all apps, sort by name, and format output
aws amplify list-apps --query "apps[].[name,appId]" --output text | sort | while IFS=$'\t' read -r name appid; do
    printf "%-50s %-20s\n" "$name" "$appid"
done

echo "----------------------------------------"

# Prompt user for JSON file creation
read -p "Would you like to create a JSON file with this list? (y/n): " answer

# Convert answer to lowercase using tr instead
answer=$(echo "$answer" | tr '[:upper:]' '[:lower:]')

if [ "$answer" = "y" ]; then
    # Create JSON file with timestamp in the name
    timestamp=$(date +"%Y%m%d_%H%M%S")
    filename="amplify_apps_${timestamp}.json"

    # Get the full JSON output and save to file
    aws amplify list-apps > "$filename"

    echo "JSON file created: $filename"
else
    echo "No JSON file created"
fi
