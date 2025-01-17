#!/bin/bash

# This script will:

# 1. Check if index.html exists

# 2. Create a zip file containing your index.html

# 3. Create a new Amplify app with a unique name [2]

# 4. Create a main branch

# 5. Start a deployment

# 6. Upload your zipped file

# 7. Clean up the zip file

####################################################

# Before running the script:

# Make sure you have AWS CLI installed

# Configure AWS credentials ( aws configure)

# Make the script executable: chmod +x deploy.sh

# Have your index.html in the same directory as the script

# To run the script:

# ./DeployHTMLwAmplify.sh <app name>

####################################################


# After deployment, you can check the status in the AWS Amplify Console. The script will output the App ID which you can use to track your deployment.

# Note: This script creates a new Amplify app each time it runs. For repeated deployments to the same app, you would want to modify the script to accept an existing App ID as a parameter or store it in a configuration file.

####################################################


# Exit on any error
set -e

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
TIMESTAMP=$(date +%Y%m%d%H%M%S)
NAME=$1


APP_NAME="${NAME}-${TIMESTAMP}"

# Create a new Amplify app
echo "Creating Amplify app..."
APP_ID=$(aws amplify create-app --name "${APP_NAME}" --query 'app.appId' --output text)

if [ -z "$APP_ID" ]; then
    echo "Error: Failed to create Amplify app"
    exit 1
fi

# Create a new branch (default to 'main')
echo "Creating branch..."
aws amplify create-branch --app-id "${APP_ID}" --branch-name "main"

# Start the deployment
echo "Starting deployment..."
DEPLOYMENT_ID=$(aws amplify create-deployment --app-id "${APP_ID}" --branch-name "main" --query 'jobId' --output text)

# Upload the zip file
echo "Uploading files..."
aws amplify start-deployment --app-id "${APP_ID}" --branch-name "main" --job-id "${DEPLOYMENT_ID}" --file-upload deployment.zip

echo "Cleaning up..."
rm deployment.zip

echo "Deployment initiated successfully!"
echo "App ID: ${APP_ID}"
echo "You can check the status in the AWS Amplify Console"
