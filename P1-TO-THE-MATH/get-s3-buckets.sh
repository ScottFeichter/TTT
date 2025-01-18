#!/bin/bash

# Print header in terminal
printf "\n%-50s %-20s %-12s %-60s %-50s\n" "BUCKET NAME" "CREATION DATE" "REGION" "BUCKET URL" "BUCKET ARN"
printf "%s\n" "------------------------------------------------------------------------------------------------------------------------------------------------"

# Get list of buckets and store in array for reuse
bucket_data=()
while IFS=$'\t' read -r bucket_name creation_date; do
    # Get bucket region
    region=$(aws s3api get-bucket-location --bucket "$bucket_name" --query 'LocationConstraint' --output text)

    # Handle us-east-1 region (returns null)
    if [ "$region" == "null" ] || [ -z "$region" ]; then
        region="us-east-1"
    fi

    # Format creation date (remove time zone and 'T')
    creation_date=$(echo "$creation_date" | sed 's/T/ /' | cut -d'.' -f1)

    # Construct bucket URL (using virtual-hosted style URL)
    if [ "$region" == "us-east-1" ]; then
        bucket_url="https://${bucket_name}.s3.amazonaws.com"
    else
        bucket_url="https://${bucket_name}.s3.${region}.amazonaws.com"
    fi

    # Construct bucket ARN
    bucket_arn="arn:aws:s3:::${bucket_name}"

    # Print to terminal
    printf "%-50s %-20s %-12s %-60s %-50s\n" "$bucket_name" "$creation_date" "$region" "$bucket_url" "$bucket_arn"

    # Store data for later use
    bucket_data+=("$bucket_name|$creation_date|$region|$bucket_url|$bucket_arn")

done < <(aws s3api list-buckets --query 'Buckets[].[Name,CreationDate]' --output text)

printf "%s\n\n" "------------------------------------------------------------------------------------------------------------------------------------------------"

# Prompt user for CSV file creation
read -p "Would you like to create a spreadsheet file with S3 bucket information? (y/n): " answer

# Convert answer to lowercase using tr instead
answer=$(echo "$answer" | tr '[:upper:]' '[:lower:]')

if [ "$answer" = "y" ]; then
    # Create CSV file with timestamp in the name
    timestamp=$(date +"%Y%m%d_%H%M%S")
    filename="s3_buckets_${timestamp}.csv"

    # Create header in the CSV file
    echo "BUCKET NAME,QUOTE,CREATION DATE,QUOTE,REGION,QUOTE,BUCKET URL,QUOTE,BUCKET ARN,QUOTE" > "$filename"

    # Write stored data to CSV
    for data in "${bucket_data[@]}"; do
        IFS='|' read -r bucket_name creation_date region bucket_url bucket_arn <<< "$data"
        echo "\"$bucket_name\",\"\"\"\",\"$creation_date\",\"\"\"\",\"$region\",\"\"\"\",\"$bucket_url\",\"\"\"\",\"$bucket_arn\",\"\"\"\"" >> "$filename"
    done

    echo "Spreadsheet file created: $filename"

    # Open the file with default application based on OS
    case "$(uname)" in
        "Darwin") # macOS
            open "$filename"
            ;;
        "Linux")
            if command -v xdg-open > /dev/null; then
                xdg-open "$filename"
            else
                echo "Could not automatically open the file. Please open $filename manually."
            fi
            ;;
        "MINGW"*|"MSYS"*|"CYGWIN"*) # Windows
            start "$filename"
            ;;
        *)
            echo "Could not automatically open the file. Please open $filename manually."
            ;;
    esac
else
    echo "No spreadsheet file created"
fi
