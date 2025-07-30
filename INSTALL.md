# Installing and Integrating Tasks by Me

## Overview

Tasks by Me requires:

1. An Entra ID app registration in your Microsoft 365 tenant.  
1. Deployment of the Tasks by Me web application, configured with parameters from the Entra ID app registration. This can be deployed on any infrastructure, as long as a public URL is available. 
1. The Entra ID app should be updated with the public URL.

The easiest way to do all this is to host the tasks by me web application on Microsoft Azure, in an Azure free tier web app. If you want to do that, [click here](#deploy-to-azure-app-services-recommended)

Alternatively, you can set up the Entra ID app yourself, and deploy the web app to any platform of your choice (that supports node.js version 22 or higher). After deployment, the application's URL will have to be updated in the Entra ID app registration. If you want to do that, [click here](#create-entra-id-application).

## Deploy to Azure App Services (Recommended)

The easiest way to deploy Tasks by Me is using a PowerShell module that handles both Entra ID app registration and Azure deployment. The module, `MaxOffice.TasksByMe.Azure`, installs the Tasks by Me app to a Azure Web App (Free Tier). It also registers an Entra ID app, and configures the Azure Web App to use that to access the Microsoft Graph API.

> [! NOTE]
> The Azure Web app is always hosted in the "East US" region. Since Tasks by Me does not store any data, and only shows data retrieved from the user's Micrsoft 365 tenant, this does not have any compliance or data residency implications.

You will need to provide a name for the web app that is globally unique. The module will automatically check if a dns name in the format `WEBAPPNAME.azurewebsites.net` is available, and will fail the installation if not. After the deployment is succesfully completed, Tasks by Me can be accessed by navigating to `https://WEBAPPNAME.azurewebsites.net`. In the examples shown below, the name "my-tasks-app" has been used. Replace that with your unique name.

### Install the PowerShell Module

```powershell
Install-Module -Name MaxOffice.TasksByMe.Azure -Scope CurrentUser
```

### Deploy Everything at Once

```powershell
Install-TasksByMeAzureWebApp -WebAppName "my-tasks-app" -Verbose
```

This command will:
1. Create an Entra ID application registration called "Tasks by Me"
2. Deploy the web app to Azure App Service, using the (unique) name provided
3. Configure all necessary environment variables
4. Set up proper redirect URLs

### Check Deployment Status

```powershell
Get-TasksByMeAzureWebApp -WebAppName "my-tasks-app" -Verbose
```

or browse to:

```
https://my-tasks-app.azurewebsites.net
```

The app should be up and running.

### Remove Deployment

```powershell
Remove-TasksByMeAzureWebApp -WebAppName "my-tasks-app" -RemoveResourceGroup -RemoveEntraApp -Verbose
```

### Authenticating to Azure and Microsoft 365

Using any of these cmdlets may require you to sign into Azure and Microsoft 365, with appropriate accounts that have required privileges. You can use `Connect-AzAccount` and `Connect-MgGraph` before using any of these to ensure that you are logged in with the correct credentials.

## Manual Entra ID setup

If you prefer to deploy the web application using your own infrastructure, you can use the Entra module to create just the Entra ID app registration.

### Install the Entra PowerShell Module

```powershell
Install-Module -Name MaxOffice.TasksByMe.Entra -Scope CurrentUser
```

### Create Entra ID Application

```powershell
$appDetails = Install-TasksByMeApp
```

This will output:
- `TenantId` - Your Microsoft 365 tenant ID
- `ClientId` - The application (client) ID
- `ClientSecret` - The client secret for authentication
- `ObjectId` - The Entra ID object ID

Note these down, and use them to configure the web app. In particular, **note down the client secret**, as
it cannot be retrieved again. If you forget to do this, you will have to delete and re-create the Entra ID App registration.

### Deploy the app
Then, deploy the web app to your preferred platform, while configuring it with the data that you noted. See [deploying the app](#deploying-the-app).

### Update Redirect URLs (After Deployment)

Once you've deployed your web app, update the URL in the Entra ID app:

```powershell
Set-TasksByMeAppUrl -BaseUri "https://your-domain.com"
```

At this point, Tasks by Me is ready for use.

### Check App Configuration

```powershell
Get-TasksByMeApp
```

### Remove Entra ID App

If you want to completely remove Tasks by Me from your Office 365 tenant, use the following:

```powershell
Remove-TasksByMeApp
```

## Deploying the App

### Manual Node.js Deployment

Tasks by Me can run in any environment that supports node.js (version 22 minimum). 

The following environment variables will have to be set for the app to run:

| Variable | Description |
|----------|-------------|
| `TENANT_ID` | Microsoft 365 tenant ID. Set it to the value returned by `Install-TasksByMeApp`. |
| `CLIENT_ID` | Entra ID app client ID. Set it to the value returned by `Install-TasksByMeApp`. |
| `CLIENT_SECRET` | Entra ID app client secret. Set it to the value returned by `Install-TasksByMeApp`. |
| `SESSION_SECRET` | Random string for session encryption. Set it to any random string. |
| `REDIRECT_URI` | Redirect URL of Entra ID app. Set it to `YOURAPPURL/auth/callback`.|
| `PORT` | Port number for the web server. The default is 8080. Change only if needed. |
| `NODE_ENV` | Environment mode. Set it to 'production', or 'development' if https is not available. Note that 'development' will only work if the URL begins with `http://localhost`, and 'production' will only work if https is available. |

Set them using your environment's native method. Alternatively, create an `.env` file in the application root directory, with all the variables and their values.

Once the app is deployed, remember to update its URL in the Entra ID app using `Set-TasksByMeAppUrl`. This should match the `YOURAPPURL` part of the `REDIRECT_URI` value mentioned above. For example, if your deployed node.js app is available at `https://mytasks.mycompany.com`, then the `REDIRECT_URI` variable should be set to `https://mytasks.mycompany.com/auth/callback`, and you should run `Set-TasksByMeAppUrl -BaseUri "https://mytasks.mycompany.com"`.

### Deploying via Docker

Tasks by me can also be run in a container. An image called `ghcr.io/maxoffice/tasksbyme` is available on the GitHub container registry. This repository also includes a Docker Compose manifest file for a quick start.

In either case, you should first create a file called `.env` in the application root directory, as described in the previous section, with appropriate values for at least the `TENANT_ID`, `CLIENT_ID` and `CLIENT_SECRET` fields.

#### Deploy with Docker Compose

Run the following in the application root directory:

```bash
docker compose up -d
```

The application will be available at `http://localhost:18080`

#### Deploy manually with the Docker CLI

Run the following in the application root directory:

```bash
docker run -d --name tbm1 --publish 18080:8080 --env-file .env ghcr.io/maxoffice/tasksbyme
```

The application will be available at `http://localhost:18080`

#### Update the EntraID App URL

Once the container is deployed, remember to update its URL (in this example, `http://localhost:18080`) in the Entra ID app using `Set-TasksByMeAppUrl`.
