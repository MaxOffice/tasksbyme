# MaxOffice.TasksByMe.Entra.psm1
# PowerShell Module for managing Tasks by Me Entra ID Application

#Requires -Modules Microsoft.Graph.Applications, Microsoft.Graph.Authentication

# Module Constants
$script:AppDisplayName = "Tasks by Me"
$script:LogoUrl = "https://raw.githubusercontent.com/MaxOffice/tasksbyme/refs/heads/main/assets/logo.png"
$script:NotSetMessage = "Not set. Please configure using Set-TasksByMeAppUrl."


# Helper function to show browser UI for login
function Show-LoginUI {
    Write-Host "No active Graph connection found. Connecting to Microsoft Graph..."
    Write-Host "In your browser, please sign in using a Microsoft 365 admin account." -ForegroundColor Yellow
    Connect-MgGraph -Scopes "Application.ReadWrite.All" -NoWelcome
    Write-Host "Successfully connected to Microsoft Graph"
}

# Helper function to ensure Graph connection
function EnsureGraphConnection {
    try {
        Write-Verbose "Trying to connect to Microsoft Graph..."
        $context = Get-MgContext
        if (-not $context) {
            Show-LoginUI
        }
        else {
            Write-Verbose "Using existing Graph connection for tenant: $($context.TenantId)"
        }
        return $true
    }
    catch {
        Write-Error "Failed to connect to Microsoft Graph: $_"
        return $false
    }
}

# Helper function to get app by display name
function GetTasksByMeApp {
    try {
        if (-not (EnsureGraphConnection)) {
            return $null
        }

        $apps = Get-MgApplication -Filter "displayName eq '$script:AppDisplayName'"
        return $apps | Select-Object -First 1
    }
    catch {
        Write-Error "Failed to retrieve application: $_"
        return $null
    }
}

# Helper function to download and validate logo
function TestLogoDownload {
    try {
        Write-Verbose "Testing logo download from: $script:LogoUrl"
        $tempFile = [System.IO.Path]::GetTempFileName() + ".png"

        # Test download
        Invoke-WebRequest -Uri $script:LogoUrl -OutFile $tempFile -TimeoutSec 30

        # Validate file was downloaded and has content
        if (-not (Test-Path $tempFile) -or (Get-Item $tempFile).Length -eq 0) {
            throw "Downloaded file is empty or does not exist"
        }

        Write-Verbose "Logo download test successful. File size: $((Get-Item $tempFile).Length) bytes"
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        return $true
    }
    catch {
        Write-Error "Failed to download logo from $script:LogoUrl : $_"
        if (Test-Path $tempFile) {
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        }
        return $false
    }
}

# Helper function to download and set app logo
function SetAppLogo {
    param(
        [Parameter(Mandatory = $true)]
        [string]$AppId
    )

    try {
        Write-Verbose "Downloading and setting application logo"
        $tempFile = [System.IO.Path]::GetTempFileName() + ".png"
        Invoke-WebRequest -Uri $script:LogoUrl -OutFile $tempFile -TimeoutSec 30

        # Set-MgApplicationLogo -ApplicationId $AppId -InFile $tempFile 
        # The line above is replaced by the line below, because of
        # content-type related errors. See:
        # https://github.com/microsoftgraph/msgraph-sdk-powershell/issues/935
        Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/applications/$AppId/logo" -Method PUT -InputFilePath $tempFile -ContentType "image/png"
        Write-Verbose "Application logo set successfully"

        Remove-Item $tempFile -Force
        return $true
    }
    catch {
        Write-Error "Failed to set application logo: $_"
        if (Test-Path $tempFile) {
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        }
        return $false
    }
}

<#
.SYNOPSIS
Installs the Tasks by Me Entra ID application.

.DESCRIPTION
Creates a new Entra ID application with the display name "Tasks by Me" if it doesn't exist.
Sets the application logo from a remote URL and creates a client secret.

.EXAMPLE
Install-TasksByMeApp
#>
function Install-TasksByMeApp {
    [CmdletBinding()]
    param()

    try {
        # Ensure Graph connection
        if (-not (EnsureGraphConnection)) {
            return $null
        }

        # Test logo download before proceeding
        Write-Verbose "Validating logo download capability..."
        if (-not (TestLogoDownload)) {
            Write-Error "Logo download failed. Application installation aborted."
            return $null
        }

        # Check if app already exists
        $existingApp = GetTasksByMeApp
        if ($existingApp) {
            Write-Error "Application '$script:AppDisplayName' already exists with ID: $($existingApp.Id)"
            return $null
        }

        # Create new application
        Write-Verbose "Creating new application: $script:AppDisplayName"
        $appParams = @{
            DisplayName    = $script:AppDisplayName
            SignInAudience = "AzureADMyOrg"
        }

        $newApp = New-MgApplication @appParams
        Write-Verbose "Created application with ID: $($newApp.Id)"

        try {
            # Set application logo (this should succeed since we tested it earlier)
            $logoSet = SetAppLogo -AppId $newApp.Id
            if (-not $logoSet) {
                # If logo setting fails after app creation, clean up and fail
                Write-Error "Failed to set application logo after creation. Cleaning up application..."
                Remove-MgApplication -ApplicationId $newApp.Id
                return $null
            }

            # Create client secret
            Write-Verbose "Creating client secret..."
            $secretParams = @{
                ApplicationId      = $newApp.Id
                PasswordCredential = @{
                    DisplayName = "Setup-generated Secret"
                    EndDateTime = (Get-Date).AddYears(2)
                }
            }

            $secret = Add-MgApplicationPassword @secretParams
            Write-Verbose "Client secret created successfully"

            Write-Warning "Please make a note of the ClientSecret. You will not be able to retrieve it again."
            return [PSCustomObject]@{
                ObjectId     = $newApp.Id
                DisplayName  = $newApp.DisplayName
                TenantId     = (Get-MgContext).TenantId
                ClientId     = $newApp.AppId
                ClientSecret = $secret.SecretText
                HomePageUrl  = $script:NotSetMessage
                RedirectUrl  = $script:NotSetMessage
                Status       = "Created"
            }
        }
        catch {
            # Clean up the application if post-creation steps fail
            Write-Error "Post-creation configuration failed: $_"
            Write-Verbose "Attempting to clean up created application..."
            try {
                Remove-MgApplication -ApplicationId $newApp.Id
                Write-Verbose "Successfully cleaned up application"
            }
            catch {
                Write-Warning "Failed to clean up application $($newApp.Id): $_"
            }
            return $null
        }
    }
    catch {
        Write-Error "Failed to install application: $_"
        return $null
    }
}

<#
.SYNOPSIS
Modifies the home page, sign out and redirect URLs of the Tasks by Me application.

.DESCRIPTION
Updates the home page, sign out and redirect URL configurations for the Tasks by Me Entra ID application.

.PARAMETER BaseUri
The base URI where the Tasks by Me web application is located.

.EXAMPLE
Set-TasksByMeAppUrl -BaseUri "https://localhost:8080/"
#>
function Set-TasksByMeAppUrl {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BaseUri
    )


    try {
        $uri = $null
        if (-not [System.Uri]::TryCreate($BaseUri, [System.UriKind]::Absolute, [ref]$uri)) {
            throw "Invalid BaseUrl: '$BaseUri'. Please provide a valid absolute URL (e.g., 'https://example.com')."
        }

        # Ensure the base URL does not end with a slash to prevent double slashes in constructed URLs
        # We use the validated Uri object's AbsoluteUri property to ensure consistent formatting
        $cleanedBaseUrl = $uri.AbsoluteUri.TrimEnd('/')

        # Construct the authentication-related URLs
        $redirectUrl = "$cleanedBaseUrl/auth/callback"
        $signOutUrl = "$cleanedBaseUrl/auth/logout"

        # Ensure Graph connection
        if (-not (EnsureGraphConnection)) {
            return
        }

        $app = GetTasksByMeApp
        if (-not $app) {
            Write-Error "Application '$script:AppDisplayName' not found. Please install it first using Install-TasksByMeApp."
            return
        }

        $currentApp = Get-MgApplication -ApplicationId $app.Id
        $webConfig = $currentApp.Web

        if (-not $webConfig) {
            $webConfig = @{
                RedirectUris = @($RedirectUrl)
            }
        }
        else {
            $webConfig.RedirectUris = @($redirectUrl)
        }

        $webConfig.HomePageUrl = $cleanedBaseUrl
        $webConfig.LogoutUrl = $signOutUrl

        $updateParams = @{
            ApplicationId = $app.Id
            Web           = $webConfig
        }

        if ($PSCmdlet.ShouldProcess($script:AppDisplayName, "Set Entra ID App URLs")) {
            Update-MgApplication @updateParams
            Write-Output "Updated Application URLs."
        }
    }
    catch {
        Write-Error "Failed to update Application URLs: $_"
    }
}

<#
.SYNOPSIS
Shows information about the Tasks by Me application.

.DESCRIPTION
Displays App ID, Display Name, Object ID, redirect URLs, and client secret information
for the Tasks by Me Entra ID application.

.EXAMPLE
Get-TasksByMeApp
#>
function Get-TasksByMeApp {
    [CmdletBinding()]
    param()

    try {
        # Ensure Graph connection
        if (-not (EnsureGraphConnection)) {
            return $null
        }

        $app = GetTasksByMeApp
        if (-not $app) {
            Write-Warning "Application '$script:AppDisplayName' not found."
            return $null
        }

        $status = "Ready"

        # Get detailed application information
        $detailedApp = Get-MgApplication -ApplicationId $app.Id

        # Extract redirect URIs from different platforms
        $redirectUris = @()
        if ($detailedApp.Web -and $detailedApp.Web.RedirectUris) {
            $redirectUris += $detailedApp.Web.RedirectUris | ForEach-Object { "$_ (Web)" }
            $homePageUrl = $detailedApp.Web.HomePageUrl
        }
        else {
            $homePageUrl = $script:NotSetMessage
            $status = "NotReady"
        }

        # Get client secret information (values cannot be retrieved)
        $secrets = $detailedApp.PasswordCredentials
        if ($secrets -and $secrets.Count -gt 0) {
            $secretInfo = "$($secrets.Count) secret(s) configured (values cannot be displayed)"
        }
        else {
            $secretInfo = "No client secrets configured. Please delete and re-create the application."
            $status = "NotReady"
        }

        return [PSCustomObject]@{
            ObjectId     = $detailedApp.Id
            DisplayName  = $detailedApp.DisplayName
            TenantId     = (Get-MgContext).TenantId
            ClientId     = $detailedApp.AppId
            ClientSecret = $secretInfo
            HomePageUrl  = $homePageUrl
            RedirectUrl  = if ($redirectUris) { $redirectUris -join "; " } else { $script:NotSetMessage }
            Status       = $status
        }
    }
    catch {
        Write-Error "Failed to retrieve application information: $_"
        return $null
    }
}

<#
.SYNOPSIS
Removes the Tasks by Me application.

.DESCRIPTION
Deletes the Tasks by Me Entra ID application and all its associated configurations.

.PARAMETER Confirm
Prompts for confirmation before deleting the application.

.EXAMPLE
Remove-TasksByMeApp

.EXAMPLE
Remove-TasksByMeApp -Confirm:$false
#>
function Remove-TasksByMeApp {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param()

    try {
        # Ensure Graph connection
        if (-not (EnsureGraphConnection)) {
            return
        }

        $app = GetTasksByMeApp
        if (-not $app) {
            Write-Warning "Application '$script:AppDisplayName' not found."
            return
        }

        if ($PSCmdlet.ShouldProcess($script:AppDisplayName, "Delete Entra ID Application")) {
            Remove-MgApplication -ApplicationId $app.Id
            Write-Output "Successfully deleted application '$script:AppDisplayName' (ID: $($app.AppId))"
        }
    }
    catch {
        Write-Error "Failed to delete application: $_"
    }
}

# Export module members
Export-ModuleMember -Function @(
    'Install-TasksByMeApp',
    'Set-TasksByMeAppUrl',
    'Get-TasksByMeApp',
    'Remove-TasksByMeApp'
)