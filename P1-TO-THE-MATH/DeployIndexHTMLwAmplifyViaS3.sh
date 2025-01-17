#!/bin/bash

# This script will:

# 1. Check if index.html exists

# 2. Check if a deployment.zip exists and remove it if found

# 4. Create a zip file containing your index.html

# 5. Create a temporary S3 bucket and upload the zip file

# 6. Create a new Amplify app with a unique name using the first cli argument and a generated timestamp

# 7. Create a main branch on amplify

# 8. Create a deployment and get the job ID

# 9. Source your zipped file to start the deployment

# 10. Check status of deployment until timeout or completion

# 10. Clean up the zip file and temporary S3 bucket if successful

# 11. Open the deployed app in the default browser if successful

####################################################

# Before running the script:

# Make sure you have AWS CLI installed

# Configure AWS credentials ( aws configure)

# Make the script executable: chmod +x DeployIndexHTMLwAmplify.sh

# Have your index.html in the same directory as the script

# To run the script: ./DeployIndexHTMLwAmplifyviaS3.sh <app name>


####################################################


# After deployment, you can check the status in the AWS Amplify Console. The script will output the App ID which you can use to track your deployment.

# Note: This script creates a new Amplify app each time it runs. For repeated deployments to the same app, you would want to modify the script to accept an existing App ID as a parameter or store it in a configuration file.


####################################################

export AWS_PAGER=""  # Disable the AWS CLI pager so we don't get json output

# Exit on any error
set -e

# Check if app name parameter was provided
if [ -z "$1" ]; then
    echo "terminating process - no app name parameter provided"
    exit 1
fi


# Check and clean up any existing deployment.zip
echo "Cecking for existing deployment.zip..."
if [ -f "deployment.zip" ]; then
    echo "  Found existing deployment.zip - removing..."
    rm deployment.zip
fi


echo "Starting Amplify deployment process..."

# Check if index.html exists
if [ ! -f "index.html" ]; then
    echo "Error: index.html file not found!"
    exit 1
fi

# Create a zip file containing index.html
echo "Creating zip file..."
zip -r deployment.zip index.html

# Get the current timestamp for unique app name
TIMESTAMP=$(date +%Y.%m.%d.%H:%M:%S)
NAME=$1
APP_NAME="${NAME} - ${TIMESTAMP}"

# Create a new Amplify app
echo "Creating Amplify app..."
APP_ID=$(aws amplify create-app --name "${APP_NAME}" --query 'app.appId' --output text)

if [ -z "$APP_ID" ]; then
    echo "Error: Failed to create Amplify app"
    exit 1
fi



# Create a unique bucket name using timestamp
TIMESTAMP=$(date +%Y%m%d%H%M%S)
BUCKET_NAME="amplify-deploy-temp-${TIMESTAMP}"

# Create S3 bucket and upload
echo "Creating temporary S3 bucket..."
aws s3 mb "s3://${BUCKET_NAME}" --region ${AWS_REGION:-us-east-1}

# Create bucket policy
echo "Adding bucket policy..."
BUCKET_POLICY='{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AmplifyAccess",
            "Effect": "Allow",
            "Principal": {
                "Service": "amplify.amazonaws.com"
            },
            "Action": [
                "s3:GetObject",
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::'${BUCKET_NAME}'",
                "arn:aws:s3:::'${BUCKET_NAME}'/*"
            ]
        }
    ]
}'

# Apply the bucket policy
aws s3api put-bucket-policy --bucket "${BUCKET_NAME}" --policy "$BUCKET_POLICY"





echo "Uploading deployment.zip to S3..."
aws s3 cp deployment.zip "s3://${BUCKET_NAME}/deployment.zip"

# Wait a moment to ensure S3 consistency
sleep 5

# Verify S3 upload with timeout
echo "Verifying S3 upload..."
TIMEOUT=60  # 1 minute timeout for upload verification
ELAPSED=0
INTERVAL=5  # Check every 5 seconds

while [ $ELAPSED -lt $TIMEOUT ]; do
    if aws s3 ls "s3://${BUCKET_NAME}/deployment.zip" &> /dev/null; then
        echo "  Upload verified successfully!"
        break
    else
        echo "  Waiting for upload to complete... Timeout in ${TIMEOUT}... Time elapsed: ${ELAPSED}s..."
        sleep $INTERVAL
        ELAPSED=$((ELAPSED + INTERVAL))
    fi
done

if [ $ELAPSED -ge $TIMEOUT ]; then
    echo "  Upload verification timed out after ${TIMEOUT} seconds"
    echo "Exiting deployment..."
    echo "Please check S3 to verify upload..."
    exit 1
fi

# Create a branch first
echo "Creating branch..."
aws amplify create-branch --app-id "${APP_ID}" --branch-name "main"


# Create the deployment and get the job ID
echo "Creating deployment..."
DEPLOYMENT_ID=$(aws amplify create-deployment \
    --app-id "${APP_ID}" \
    --branch-name "main" \
    --query 'jobId' \
    --output text)


# Start the deployment with verification
echo "Starting deployment..."
aws amplify start-deployment \
    --app-id "${APP_ID}" \
    --branch-name "main" \
    --source-url "s3://${BUCKET_NAME}/deployment.zip" \
    --source-url-type "ZIP"


# Wait for deployment to complete
echo "Verifying deployment status do not exit..."
DEPLOY_TIMEOUT=300  # 5 minute timeout for deployment start
ELAPSED=0
INTERVAL=10  # Check every 10 seconds

while [ $ELAPSED -lt $DEPLOY_TIMEOUT ]; do
    # Get the active job ID first
    ACTIVE_JOB_ID=$(aws amplify get-branch \
        --app-id "${APP_ID}" \
        --branch-name "main" \
        --query 'branch.activeJobId' \
        --output text)

    # Get the status of the active job
    JOB_STATUS=$(aws amplify get-job \
        --app-id "${APP_ID}" \
        --branch-name "main" \
        --job-id "${ACTIVE_JOB_ID}" \
        --query 'job.summary.status' \
        --output text)

    if [ "$JOB_STATUS" = "SUCCEED" ]; then
        echo "Deployment completed successfully!"
        break
    elif [ "$JOB_STATUS" = "FAILED" ]; then
        echo "Deployment failed. Please check the AWS Amplify Console"
        exit 1
    else
        echo "  Deployment status: ${JOB_STATUS}... Timeout after: ${DEPLOY_TIMEOUT}s... Time elapsed: ${ELAPSED}s..."
        sleep $INTERVAL
        ELAPSED=$((ELAPSED + INTERVAL))
    fi
done

if [ $ELAPSED -ge $DEPLOY_TIMEOUT ]; then
    echo "  Deployment verification timed out after ${DEPLOY_TIMEOUT} seconds"
    echo "Please check the AWS Amplify Console for deployment status..."
    exit 1
fi







# Get the full URL of the app
echo "Getting app information..."
FULL_URL=$(aws amplify get-app --app-id "${APP_ID}" --query 'app.defaultDomain' --output text)
FULL_URL="https://main.${FULL_URL}"
echo "App ID: ${APP_ID}"
echo "App URL: ${FULL_URL}"


# Clean up
echo "Cleaning up temporary files..."
aws s3 rm "s3://${BUCKET_NAME}/deployment.zip"
aws s3 rb "s3://${BUCKET_NAME}"
rm deployment.zip
echo "  removed deployment.zip"
echo "Deployment initiated successfully!"


# Open the URL in the default browser based on the operating system
echo "Opening app in default browser..."
sleep 5
case "$(uname -s)" in
    Linux*)     xdg-open "$FULL_URL";;
    Darwin*)    open "$FULL_URL";;
    CYGWIN*|MINGW32*|MSYS*|MINGW*) start "$FULL_URL";;
    *)          echo "Please visit: $FULL_URL";;
esac


echo "Your app is now deployed via AWS Amplify!"
