#!/bin/bash

export AWS_PAGER=""  # Disable the AWS CLI pager so we don't get json output

# Array of bucket names - change them to suit your needs
BUCKETS=(

    "amplify-deploy-temp-20250117120037"
    "amplify-deploy-temp-20250117121124"
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
