# MaxOffice.TasksByMe.Azure.psm1
# PowerShell Module for deploying Tasks by Me to Azure App Service

#Requires -Modules Az.Resources, Az.Websites, MaxOffice.TasksByMe.Entra

# Module Constants
$script:ArmTemplateUrl = "https://raw.githubusercontent.com/MaxOffice/planner-task-tracker/refs/heads/development/deploy/azure/arm-template.json"
$script:DefaultGitRepoUrl = "https://github.com/maxoffice/planner-task-tracker"

# Module Manifest would be in MaxOffice.TasksByMe.Azure.psd1:
<#
@{
    ModuleVersion = '1.0.0'
    GUID = 'b2c3d4e5-f6a7-8901-2345-678901bcdefg'
    Author = 'Your Name'
    Description = 'PowerShell module for deploying Tasks by Me to Azure App Service'
    PowerShellVersion = '5.1'
    RequiredModules = @('Az.Resources', 'Az.Websites', 'MaxOffice.TasksByMe.Entra')
    FunctionsToExport = @('Install-TasksByMeAzureWebApp', 'Get-TasksByMeAzureWebApp', 'Remove-TasksByMeAzureWebApp')
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
}
#>

# Helper function to ensure Azure connection
function EnsureAzureConnection {
    try {
        $context = Get-AzContext
        if (-not $context) {
            Write-Verbose "No active Azure connection found. Connecting to Azure..."
            Connect-AzAccount | Out-Null
            Write-Verbose "Successfully connected to Azure"
        }
        else {
            Write-Verbose "Using existing Azure connection for subscription: $($context.Subscription.Name)"
        }
        return $true
    }
    catch {
        Write-Error "Failed to connect to Azure: $_"
        return $false
    }
}

# Helper function to download ARM template
function DownloadArmTemplate {
    try {
        Write-Verbose "Downloading ARM template from: $script:ArmTemplateUrl"
        $tempFile = [System.IO.Path]::GetTempFileName() + ".json"

        Invoke-WebRequest -Uri $script:ArmTemplateUrl -OutFile $tempFile -TimeoutSec 30

        # Validate JSON content
        $content = Get-Content $tempFile -Raw | ConvertFrom-Json
        if (-not $content.'$schema') {
            throw "Downloaded file does not appear to be a valid ARM template"
        }

        Write-Verbose "ARM template downloaded and validated successfully"
        return $tempFile
    }
    catch {
        Write-Error "Failed to download ARM template: $_"
        if (Test-Path $tempFile) {
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        }
        return $null
    }
}

# Helper function to check if website exists
function TestWebsiteExists {
    param(
        [Parameter(Mandatory = $true)]
        [string]$WebAppName
    )

    try {
        $url = "https://$WebAppName.azurewebsites.net"
        Write-Verbose "Checking if website exists at: $url"

        $response = Invoke-WebRequest -Uri $url -Method Head -TimeoutSec 10 -ErrorAction Stop
        Write-Verbose "Website exists and responded with status: $($response.StatusCode)"
        return $true
    }
    catch {
        if ($_.Exception.Response.StatusCode -eq 404) {
            Write-Verbose "Website does not exist (404 response)"
            return $false
        }
        elseif ($_.Exception -is [System.Net.WebException] -or $_.Exception.InnerException -is [System.Net.WebException]) {
            Write-Verbose "Website does not exist (connection failed)"
            return $false
        }
        elseif ($_ -like "*Name or service not known*") {
            Write-Verbose "Website does not exist (Azure Web App service not found)"
            return $false
        }
        else {
            # Website exists but returned an error (500, etc.)
            Write-Verbose "Website exists but returned error: $_"
            Write-Verbose $_
            return $true
        }
    }
}

# Helper function to generate session secret
function GenerateSessionSecret {
    $bytes = New-Object byte[] 32
    [System.Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($bytes)
    return [Convert]::ToBase64String($bytes)
}

<#
.SYNOPSIS
Installs the Tasks by Me application to Azure App Service.

.DESCRIPTION
Installs the Tasks by Me Node.js application to Azure App Service using an ARM template.
Can either use provided authentication parameters or create a new Entra ID application.

.PARAMETER WebAppName
The name for the Azure Web App. Must be globally unique.

.PARAMETER ResourceGroupName
The name of the Azure Resource Group where the app will be deployed. If not specified, defaults to "TasksByMe-{WebAppName}-rg". Will be created if it doesn't exist.

.PARAMETER TenantId
The Azure tenant ID. If not provided, will create new Entra ID application.

.PARAMETER ClientId
The Entra ID application client ID. If not provided, will create new Entra ID application.

.PARAMETER ClientSecret
The Entra ID application client secret. If not provided, will create new Entra ID application.

.PARAMETER GitRepoUrl
The Git repository URL for deployment. Defaults to the standard repository.

.EXAMPLE
Install-TasksByMeAzureWebApp -WebAppName "mytasks"

.EXAMPLE
Install-TasksByMeAzureWebApp -WebAppName "mytasks" -ResourceGroupName "myresources"

.EXAMPLE
Install-TasksByMeAzureWebApp -WebAppName "mytasks" -TenantId "xxx" -ClientId "yyy" -ClientSecret "zzz"
#>
function Install-TasksByMeAzureWebApp {
    [CmdletBinding(DefaultParameterSetName = 'CreateApp')]
    param(
        [Parameter(Mandatory = $true)]
        [string]$WebAppName,

        [Parameter()]
        [string]$ResourceGroupName,

        [Parameter(Mandatory = $true, ParameterSetName = 'UseExisting')]
        [string]$TenantId,

        [Parameter(Mandatory = $true, ParameterSetName = 'UseExisting')]
        [string]$ClientId,

        [Parameter(Mandatory = $true, ParameterSetName = 'UseExisting')]
        [string]$ClientSecret,

        [Parameter()]
        [string]$GitRepoUrl = $script:DefaultGitRepoUrl
    )

    try {
        # Set default resource group name if not provided
        if (-not $ResourceGroupName) {
            $ResourceGroupName = "TasksByMe-$WebAppName-rg"
            Write-Verbose "Using default resource group name: $ResourceGroupName"
        }

        # Check if website already exists
        if (TestWebsiteExists -WebAppName $WebAppName) {
            Write-Error "Website $WebAppName.azurewebsites.net already exists. Please choose a different name."
            return $null
        }

        # Download ARM template
        $templateFile = DownloadArmTemplate
        if (-not $templateFile) {
            Write-Error "Failed to download ARM template. Deployment aborted."
            return $null
        }

        try {
            # Get authentication parameters
            if ($PSCmdlet.ParameterSetName -eq 'CreateApp') {
                Write-Verbose "Creating new Entra ID application..."
                $appResult = Install-TasksByMeApp
                if (-not $appResult) {
                    Write-Error "Failed to create Entra ID application. Deployment aborted."
                    return $null
                }

                $TenantId = $appResult.TenantId
                $ClientId = $appResult.ClientId
                $ClientSecret = $appResult.ClientSecret

                Write-Verbose "Created Entra ID application with Client ID: $ClientId"
            }

            # Generate session secret
            $sessionSecret = GenerateSessionSecret
            Write-Verbose "Generated session secret"

            # Now ensure Azure connection is available for deployment
            if (-not (EnsureAzureConnection)) {
                return $null
            }

            # Create resource group if it doesn't exist
            $existingRg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
            if (-not $existingRg) {
                Write-Verbose "Creating resource group: $ResourceGroupName"
                $location = "East US"  # Default location
                New-AzResourceGroup -Name $ResourceGroupName -Location $location | Out-Null
                Write-Verbose "Created resource group in location: $location"
            }
            else {
                Write-Verbose "Using existing resource group: $ResourceGroupName"
            }

            # Prepare deployment parameters
            # $deploymentParams = @{
            #     webAppName = $WebAppName
            #     tenantId = $TenantId
            #     clientId = $ClientId
            #     clientSecret = ConvertTo-SecureString $ClientSecret -AsPlainText -Force
            #     sessionSecret = ConvertTo-SecureString $sessionSecret -AsPlainText -Force
            #     gitRepoUrl = $GitRepoUrl
            # }
            $deploymentParams = @{
                webAppName = $WebAppName
                tenantId = $TenantId
                clientId = $ClientId
                clientSecret = $ClientSecret
                sessionSecret = $sessionSecret
                gitRepoUrl = $GitRepoUrl
            }

            # Deploy ARM template
            Write-Verbose "Starting ARM template deployment..."
            $deployment = New-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName -TemplateFile $templateFile -TemplateParameterObject $deploymentParams -Name "TasksByMe-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

            if ($deployment.ProvisioningState -eq 'Succeeded') {
                $webAppUrl = $deployment.Outputs.webAppUrl.Value
                Write-Verbose "Deployment completed successfully"

                # Update Entra ID app with correct URLs if we created it
                if ($PSCmdlet.ParameterSetName -eq 'CreateApp') {
                    Write-Verbose "Updating Entra ID application URLs..."
                    Set-TasksByMeAppUrl -BaseUri $webAppUrl -Confirm:$false
                }

                return [PSCustomObject]@{
                    WebAppName = $WebAppName
                    WebAppUrl = $webAppUrl
                    ResourceGroupName = $ResourceGroupName
                    TenantId = $TenantId
                    ClientId = $ClientId
                    DeploymentStatus = 'Succeeded'
                }
            }
            else {
                Write-Error "Deployment failed with status: $($deployment.ProvisioningState)"
                return $null
            }
        }
        finally {
            # Clean up template file
            if (Test-Path $templateFile) {
                Remove-Item $templateFile -Force -ErrorAction SilentlyContinue
            }
        }
    }
    catch {
        Write-Error "Failed to deploy application: $_"
        return $null
    }
}

<#
.SYNOPSIS
Gets information about a deployed Tasks by Me Azure Web App.

.DESCRIPTION
Retrieves information about a Tasks by Me application deployed to Azure App Service.

.PARAMETER WebAppName
The name of the Azure Web App.

.PARAMETER ResourceGroupName
The name of the Azure Resource Group containing the app.

.EXAMPLE
Get-TasksByMeAzureWebApp -WebAppName "mytasks" -ResourceGroupName "myresources"
#>
function Get-TasksByMeAzureWebApp {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$WebAppName,

        [Parameter()]
        [string]$ResourceGroupName
    )

    try {
        # Ensure Azure connection
        if (-not (EnsureAzureConnection)) {
            return $null
        }

        # Set default resource group name if not provided
        if (-not $ResourceGroupName) {
            $ResourceGroupName = "TasksByMe-$WebAppName-rg"
            Write-Verbose "Using default resource group name: $ResourceGroupName"
        }

        # Get web app information
        $webApp = Get-AzWebApp -ResourceGroupName $ResourceGroupName -Name $WebAppName -ErrorAction Stop

        # Get app settings
        $appSettings = @{}
        foreach ($setting in $webApp.SiteConfig.AppSettings) {
            $appSettings[$setting.Name] = $setting.Value
        }

        return [PSCustomObject]@{
            WebAppName = $webApp.Name
            ResourceGroupName = $webApp.ResourceGroup
            WebAppUrl = "https://$($webApp.DefaultHostName)"
            Location = $webApp.Location
            State = $webApp.State
            TenantId = $appSettings['TENANT_ID']
            ClientId = $appSettings['CLIENT_ID']
            NodeVersion = $webApp.SiteConfig.LinuxFxVersion
            LastModifiedTime = $webApp.LastModifiedTimeUtc
        }
    }
    catch {
        if ($_.Exception.Message -like "*ResourceNotFound*") {
            Write-Warning "Web app '$WebAppName' not found in resource group '$ResourceGroupName'."
            return $null
        }
        else {
            Write-Error "Failed to retrieve web app information: $_"
            return $null
        }
    }
}

<#
.SYNOPSIS
Removes a deployed Tasks by Me Azure Web App.

.DESCRIPTION
Removes a Tasks by Me application and its associated resources from Azure App Service.

.PARAMETER WebAppName
The name of the Azure Web App to remove.

.PARAMETER ResourceGroupName
The name of the Azure Resource Group containing the app.

.PARAMETER RemoveResourceGroup
Switch to also remove the resource group. Defaults to $true if the resource group follows the auto-generated naming pattern.

.PARAMETER RemoveEntraApp
Switch to also remove the associated Entra ID application.

.EXAMPLE
Remove-TasksByMeAzureWebApp -WebAppName "mytasks"

.EXAMPLE
Remove-TasksByMeAzureWebApp -WebAppName "mytasks" -ResourceGroupName "myresources" -RemoveResourceGroup:$false

.EXAMPLE
Remove-TasksByMeAzureWebApp -WebAppName "mytasks" -RemoveEntraApp -RemoveResourceGroup
#>
function Remove-TasksByMeAzureWebApp {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory = $true)]
        [string]$WebAppName,

        [Parameter()]
        [string]$ResourceGroupName,

        [Parameter()]
        [switch]$RemoveResourceGroup,

        [Parameter()]
        [switch]$RemoveEntraApp
    )

    try {
        # Ensure Azure connection
        if (-not (EnsureAzureConnection)) {
            return
        }

        # Set default resource group name if not provided
        if (-not $ResourceGroupName) {
            $ResourceGroupName = "TasksByMe-$WebAppName-rg"
            Write-Verbose "Using default resource group name: $ResourceGroupName"
        }

        # Determine if we should remove the resource group
        $shouldRemoveRg = $RemoveResourceGroup.IsPresent
        if (-not $RemoveResourceGroup.IsPresent) {
            # Default to true if resource group follows our naming convention
            if ($ResourceGroupName -eq "TasksByMe-$WebAppName-rg") {
                $shouldRemoveRg = $true
                Write-Verbose "Resource group follows auto-generated pattern, will remove by default"
            }
        }

        # Check if resource group exists
        $resourceGroup = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
        if (-not $resourceGroup) {
            Write-Warning "Resource group '$ResourceGroupName' not found."
            return
        }

        # Check if web app exists
        $webApp = Get-AzWebApp -ResourceGroupName $ResourceGroupName -Name $WebAppName -ErrorAction SilentlyContinue
        if (-not $webApp) {
            Write-Warning "Web app '$WebAppName' not found in resource group '$ResourceGroupName'."

            # If we should remove RG and it's empty or only contains our resources, proceed
            if ($shouldRemoveRg) {
                $rgResources = Get-AzResource -ResourceGroupName $ResourceGroupName
                if (-not $rgResources -or $rgResources.Count -eq 0) {
                    if ($PSCmdlet.ShouldProcess($ResourceGroupName, "Remove empty resource group")) {
                        Write-Verbose "Removing empty resource group: $ResourceGroupName"
                        Remove-AzResourceGroup -Name $ResourceGroupName -Force
                        Write-Output "Removed empty resource group '$ResourceGroupName'."
                    }
                }
            }
            return
        }

        if ($PSCmdlet.ShouldProcess("$WebAppName (and associated resources)", "Remove Azure Web App")) {
            # Remove web app
            Write-Verbose "Removing web app: $WebAppName"
            Remove-AzWebApp -ResourceGroupName $ResourceGroupName -Name $WebAppName -Force

            # Remove associated App Service Plan
            $planName = "$WebAppName-plan"
            $plan = Get-AzAppServicePlan -ResourceGroupName $ResourceGroupName -Name $planName -ErrorAction SilentlyContinue
            if ($plan) {
                Write-Verbose "Removing App Service Plan: $planName"
                Remove-AzAppServicePlan -ResourceGroupName $ResourceGroupName -Name $planName -Force
            }

            Write-Output "Successfully removed web app '$WebAppName' and associated resources."

            # Remove resource group if requested and it only contains our resources
            if ($shouldRemoveRg) {
                Write-Verbose "Checking if resource group should be removed..."
                $remainingResources = Get-AzResource -ResourceGroupName $ResourceGroupName

                if (-not $remainingResources -or $remainingResources.Count -eq 0) {
                    Write-Verbose "Resource group is empty, removing: $ResourceGroupName"
                    Remove-AzResourceGroup -Name $ResourceGroupName -Force
                    Write-Output "Removed resource group '$ResourceGroupName'."
                }
                else {
                    Write-Warning "Resource group '$ResourceGroupName' contains other resources and will not be removed. Remaining resources: $($remainingResources.Count)"
                }
            }

            # Remove Entra ID app if requested
            if ($RemoveEntraApp) {
                Write-Verbose "Removing associated Entra ID application..."
                Remove-TasksByMeApp -Confirm:$false
            }
        }
    }
    catch {
        Write-Error "Failed to remove web app: $_"
    }
}

# Export module members
Export-ModuleMember -Function @(
    'Install-TasksByMeAzureWebApp',
    'Get-TasksByMeAzureWebApp',
    'Remove-TasksByMeAzureWebApp'
)