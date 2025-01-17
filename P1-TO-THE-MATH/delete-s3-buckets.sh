#!/bin/bash

# Array of bucket names - change them to suit your needs
BUCKETS=(
    "amplify-deploy-temp-20250117005928"
    "amplify-deploy-temp-20250117012931"
    "amplify-deploy-temp-20250117013357"
    "amplify-deploy-temp-20250117013944"
    "amplify-deploy-temp-20250117014619"
    "amplify-deploy-temp-20250117014738"
    "amplify-deploy-temp-20250117014950"
    "amplify-deploy-temp-20250117015423"
    "amplify-deploy-temp-20250117020100"
    "amplify-deploy-temp-20250117020212"
    "amplify-deploy-temp-20250117020553"
)

# Function to delete a bucket and its contents
delete_bucket() {
    local bucket=$1
    echo "Processing bucket: $bucket"

    # Check if bucket exists
    if aws s3 ls "s3://$bucket" &>/dev/null; then
        echo "  Removing all objects from bucket..."
        aws s3 rm "s3://$bucket" --recursive

        echo "  Deleting bucket..."
        aws s3 rb "s3://$bucket"

        if [ $? -eq 0 ]; then
            echo "  Successfully deleted bucket: $bucket"
        else
            echo "  Failed to delete bucket: $bucket"
        fi
    else
        echo "  Bucket does not exist: $bucket"
    fi
    echo "----------------------------------------"
}

# Main execution
echo "Starting bucket deletion process..."
echo "----------------------------------------"

for bucket in "${BUCKETS[@]}"; do
    delete_bucket "$bucket"
done

echo "Bucket deletion process complete!"
