param(
    [Parameter(Mandatory = $true)]
    [string]$TenantId,
    
    [Parameter(Mandatory = $true)]
    [string]$WebAppName,
    
    # Specifies the display name of the Entra ID
    # App Registration
    [string]$AppName = "Tasks by ME",
    
    [string]$Location = "eastus",
    
    [string]$ResourceGroupPrefix = "rg-tasksbyme",
    
    [string]$DeploymentName = "TasksByMeDeploy",
    
    [string]$SecretDisplayName = "DefaultSecret",
    
    [string]$SessionSecret = (New-Guid).ToString(),
    
    [string]$ArmTemplatePath = ".\arm-template.json",
    
    [string]$LogoPath = ".\logo.png"
)

#region ⚙️ Prerequisites

function RequirePowerShell7 {
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        Write-Error "❌ PowerShell 7 or higher is required. Install from https://aka.ms/pwsh"
        exit 1
    }
}

function RequireModule {
    param (
        [Parameter(Mandatory)][string]$Name,
        [string]$MinimumVersion = "0.0.0"
    )
    if (-not (Get-Module -ListAvailable -Name $Name)) {
        Write-Host "📦 Missing module $Name. Install using:"
        Write-Host "     Install-Module $Name -Scope CurrentUser -Force -MinimumVersion $MinimumVersion"
        exit 1
    }
}

RequirePowerShell7
RequireModule -Name Microsoft.Graph -MinimumVersion 2.0.0
RequireModule -Name Az.Resources -MinimumVersion 5.0.0
# RequireModule -Name Az.Websites -MinimumVersion 3.0.0

#endregion

#region 🔍 File Validation

Write-Host "Checking for required files..."

$templatePath = Join-Path $PSScriptRoot $ArmTemplatePath
if (-not (Test-Path $templatePath)) {
    Write-Error "❌ ARM template not found at $templatePath"
    exit 1
}
Write-Host "✅ ARM template found at $templatePath"

$logoFullPath = Join-Path $PSScriptRoot $LogoPath
if (-not (Test-Path $logoFullPath)) {
    Write-Error "❌ Logo file not found at $logoFullPath"
    exit 1
}
Write-Host "✅ Logo file found at $logoFullPath"

#endregion

#region Web app name validation

Write-Host "Checking web app name availability..."
try {
    # Check if the URL responds (taken names will have existing sites)
    $testUrl = "https://$WebAppName.azurewebsites.net"
    Invoke-WebRequest -Uri $testUrl -Method Head -TimeoutSec 10 -ErrorAction Stop
    # If we get here, the site exists
    Write-Error "❌ Web app name '$WebAppName' is already taken. Try a different name."
    exit 1
} catch {
    # Expected behavior - name should be available if we get an error
    if ($_.Exception.Response.StatusCode -eq "NotFound" -or $_.Exception.Message -like "*could not be resolved*" -or $_.Exception.Message -like "*No such host is known*") {
        Write-Host "✅ Web app name '$WebAppName' appears to be available."
    } else {
        Write-Warning "⚠️ Could not verify web app name availability: $($_.Exception.Message)"
        exit 1
        # Write-Host "Proceeding with deployment. If the name is taken, deployment will fail later."
    }
}

#endregion

#region 🔐 Azure Connection & Validation

Write-Host "Initializing Azure Resource API. This may take a while..."
Import-Module Az.Resources
# Import-Module Az.Websites
Write-Host "Connecting to Azure..."
try {
    Connect-AzAccount -TenantId $TenantId -ErrorAction Stop
    Write-Host "✅ Successfully connected to Azure tenant: $TenantId"
} catch {
    Write-Error "❌ Failed to connect to Azure tenant '$TenantId'. Please verify the tenant ID is correct."
    exit 1
}

#endregion

#region 🔐 Microsoft Graph Connection & App Validation

Write-Host "Initializing Microsoft Graph API. This may take a while..."
Import-Module Microsoft.Graph.Authentication
Import-Module Microsoft.Graph.Applications

Write-Host "Connecting to Microsoft Graph API..."
try {
    Connect-MgGraph -Scopes "Application.ReadWrite.All", "Directory.ReadWrite.All" -NoWelcome -ErrorAction Stop
    Write-Host "✅ Successfully connected to Microsoft Graph"
} catch {
    Write-Error "❌ Failed to connect to Microsoft Graph. Please check your permissions."
    exit 1
}

Write-Host "Checking for existing app registration..."
$oldApp = Get-MgApplication -Filter "displayName eq '$AppName'"
if (-not ($null -eq $oldApp)) {
    Write-Error "❌ An Entra ID app named '$AppName' already exists. Cannot continue."
    exit 1
}
Write-Host "✅ App name '$AppName' is available for registration."

#endregion

#region 🔐 Register Entra App

$ErrorActionPreference = "Stop"

$placeholderRedirectUri = "https://placeholder.localhost/auth/callback"

Write-Host "🔧 Creating Entra ID app registration..."
$app = New-MgApplication -DisplayName $AppName -Web @{ redirectUris = @($placeholderRedirectUri) }

# Add logo to the app registration
Write-Host "🎨 Adding logo to app registration..."
try {
    Set-MgApplicationLogo -ApplicationId $app.Id -InFile $logoFullPath
    Write-Host "✅ Logo successfully added to app registration"
} catch {
    Write-Warning "⚠️ Failed to add logo to app registration: $($_.Exception.Message)"
}

$secret = Add-MgApplicationPassword -ApplicationId $app.Id -PasswordCredential @{ displayName = $SecretDisplayName }
New-MgServicePrincipal -AppId $app.AppId | Out-Null

Write-Host "✅ Entra ID App '$AppName' registered."

#endregion

#region 🧱 Azure Deployment

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$resourceGroupName = "$ResourceGroupPrefix-$timestamp"

Write-Host "📁 Creating resource group: $resourceGroupName..."
New-AzResourceGroup -Name $resourceGroupName -Location $Location -ErrorAction Stop

Write-Host "🚀 Deploying web app..."
$deployment = New-AzResourceGroupDeployment -Name $DeploymentName `
    -ResourceGroupName $resourceGroupName `
    -TemplateFile $templatePath `
    -TemplateParameterObject @{
        webAppName   = $WebAppName
        tenantId     = $app.PublisherDomain
        clientId     = $app.AppId
        clientSecret = $secret.SecretText
        sessionSecret= $SessionSecret
        gitRepoUrl   = "https://github.com/maxoffice/planner-task-tracker"
    }

$webAppUrl = $deployment.Outputs.webAppUrl.Value

#endregion

#region 🔁 Update Redirect URI

Write-Host "🔗 Updating app registration redirect URI..."
$finalRedirectUri = "$webAppUrl/auth/callback"
$currentUris = $finalRedirectUri

Update-MgApplication -ApplicationId $app.Id -Web @{ redirectUris = $currentUris }

#endregion

#region ✅ Summary

Write-Host "`n✅ Installation Complete" -ForegroundColor Green
Write-Host "==============================="
Write-Host "📌 App Name:         $($app.DisplayName)"
Write-Host "🏢 Tenant ID:        $($app.PublisherDomain)"
Write-Host "🌐 Web App URL:      $webAppUrl"
Write-Host "📁 Resource Group:   $resourceGroupName"
Write-Host "==============================="
Write-Host "🔐 App credentials have been configured automatically." -ForegroundColor Yellow
Write-Host "🎨 App logo has been set from logo.png" -ForegroundColor Yellow

#endregion