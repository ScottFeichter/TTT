// This script is translated from shell to js by Amazon Q

// Key differences from the shell script:

// 1. Uses AWS SDK v3 instead of AWS CLI

// 2. Uses Promises and async/await for asynchronous operations

// 3. Has built-in error handling

// 4. Uses Node.js native file system operations

// 5. Uses the 'open' package to open the browser

////////////////////////////////////////////////////////////////

// Make sure you have:

// 1. AWS credentials configured (either through environment variables or AWS credentials file)

// 2. The index.html file in the same directory

// 3. Proper permissions to create S3 buckets and Amplify apps

// The script maintains the same general flow as the shell script but uses JavaScript and the AWS SDK instead of shell commands and the AWS CLI.

////////////////////////////////////////////////////////////////

// To use this script:

// 1. First install the required dependencies:

    // npm init -y
    // npm install @aws-sdk/client-amplify @aws-sdk/client-s3 open jszip

// 2. Save the script as DeployIndexHTMLwAmplifyViaS3.js

// 3. Run it with:

    // node DeployIndexHTMLwAmplifyViaS3.js



////////////////////////////////////////////////////////////////

// Import required AWS SDK clients and commands
const { AmplifyClient, CreateAppCommand, CreateBranchCommand, CreateDeploymentCommand, StartDeploymentCommand, GetBranchCommand, GetJobCommand } = require("@aws-sdk/client-amplify");
const { S3Client, CreateBucketCommand, PutBucketPolicyCommand, PutObjectCommand, DeleteObjectCommand, DeleteBucketCommand } = require("@aws-sdk/client-s3");
const fs = require('fs');
const path = require('path');
const JSZip = require("jszip");



// Initialize AWS clients
const amplifyClient = new AmplifyClient({ region: "us-east-1" });
const s3Client = new S3Client({ region: "us-east-1" });

// Helper function to sleep
const sleep = (ms) => new Promise(resolve => setTimeout(resolve, ms));

async function deployToAmplify(appName) {
    try {
        // Create timestamp for unique names
        const timestamp = new Date().toISOString().replace(/[-:]/g, '').split('.')[0].replace('T', '.');
        const bucketName = `amplify-deploy-temp-${timestamp.replace(/\./g, '')}`;

        console.log("Starting Amplify deployment process...");

        // Check if index.html exists
        if (!fs.existsSync('index.html')) {
            throw new Error("Error: index.html file not found!");
        }

        // Create S3 bucket
        console.log("Creating temporary S3 bucket...");
        await s3Client.send(new CreateBucketCommand({
            Bucket: bucketName
        }));

        // Create bucket policy
        console.log("Adding bucket policy...");
        const bucketPolicy = {
            Version: "2012-10-17",
            Statement: [{
                Sid: "AmplifyAccess",
                Effect: "Allow",
                Principal: {
                    Service: "amplify.amazonaws.com"
                },
                Action: [
                    "s3:GetObject",
                    "s3:ListBucket"
                ],
                Resource: [
                    `arn:aws:s3:::${bucketName}`,
                    `arn:aws:s3:::${bucketName}/*`
                ]
            }]
        };

        await s3Client.send(new PutBucketPolicyCommand({
            Bucket: bucketName,
            Policy: JSON.stringify(bucketPolicy)
        }));

        // // Create zip file and upload to S3
        // console.log("Creating zip file...");
        // const zipBuffer = fs.readFileSync('deployment.zip');
        // await s3Client.send(new PutObjectCommand({
        //     Bucket: bucketName,
        //     Key: 'deployment.zip',
        //     Body: zipBuffer
        // }));









        // Create zip file and upload to S3
        console.log("Creating zip file...");
        const zip = new JSZip();

        try {
            // Read the index.html file
            const indexContent = await fs.promises.readFile('index.html', 'utf-8');

            // Add index.html to the zip
            zip.file('index.html', indexContent);

            // Generate the zip file as a buffer
            const zipBuffer = await zip.generateAsync({
                type: 'nodebuffer',
                compression: 'DEFLATE',
                compressionOptions: {
                    level: 9 // maximum compression
                }
            });

            // Upload the zip buffer to S3
            await s3Client.send(new PutObjectCommand({
                Bucket: bucketName,
                Key: 'deployment.zip',
                Body: zipBuffer
            }));

            console.log("Zip file created and uploaded successfully");
        } catch (error) {
            console.error("Error creating or uploading zip file:", error);
            throw error;
        }











        // Create Amplify app
        console.log("Creating Amplify app...");
        const createAppResponse = await amplifyClient.send(new CreateAppCommand({
            name: `${appName} - ${timestamp}`
        }));
        const appId = createAppResponse.app.appId;

        // Create branch
        console.log("Creating branch...");
        await amplifyClient.send(new CreateBranchCommand({
            appId: appId,
            branchName: "main"
        }));

        // Create deployment
        console.log("Creating deployment...");
        const deploymentResponse = await amplifyClient.send(new CreateDeploymentCommand({
            appId: appId,
            branchName: "main"
        }));

        // Start deployment
        console.log("Starting deployment...");
        await amplifyClient.send(new StartDeploymentCommand({
            appId: appId,
            branchName: "main",
            sourceUrl: `s3://${bucketName}/deployment.zip`,
            sourceUrlType: "ZIP"
        }));

        // Monitor deployment status
        console.log("Verifying deployment status...");
        const deployTimeout = 300000; // 5 minutes
        const startTime = Date.now();

        while (Date.now() - startTime < deployTimeout) {
            const branchDetails = await amplifyClient.send(new GetBranchCommand({
                appId: appId,
                branchName: "main"
            }));

            const activeJobId = branchDetails.branch.activeJobId;

            if (activeJobId) {
                const jobDetails = await amplifyClient.send(new GetJobCommand({
                    appId: appId,
                    branchName: "main",
                    jobId: activeJobId
                }));

                const status = jobDetails.job.summary.status;

                if (status === "SUCCEED") {
                    console.log("Deployment completed successfully!");
                    break;
                } else if (status === "FAILED") {
                    throw new Error("Deployment failed. Please check the AWS Amplify Console");
                }

                console.log(`Deployment status: ${status}`);
            }

            await sleep(10000); // Wait 10 seconds before checking again
        }

        // Clean up
        console.log("Cleaning up temporary files...");
        await s3Client.send(new DeleteObjectCommand({
            Bucket: bucketName,
            Key: 'deployment.zip'
        }));

        await s3Client.send(new DeleteBucketCommand({
            Bucket: bucketName
        }));

        // Get the app URL
        const defaultDomain = createAppResponse.app.defaultDomain;
        const appUrl = `https://main.${defaultDomain}`;
        console.log(`App URL: ${appUrl}`);







        // Open in browser
        console.log("Opening app in default browser...");

        // Dynamic import of open
        (async () => {
            try {
            const { default: open, openApp, apps } = await import('open');

            // Example usage:
            await open(appUrl); // Opens the URL in the default browser

            } catch (error) {
            console.error('Error importing open:', error);
            }
        })();



        console.log("Your app is now deployed via AWS Amplify!");
        return appId;

    } catch (error) {
        console.error("Deployment failed:", error);
        throw error;
    }
}









// Run the deployment
if (process.argv.length < 3) {
    console.error("Please provide an app name as an argument");
    process.exit(1);
}

const appName = process.argv[2];
deployToAmplify(appName)
    .then(appId => console.log(`Deployment completed successfully. App ID: ${appId}`))
    .catch(error => {
        console.error("Deployment failed:", error);
        process.exit(1);
    });
