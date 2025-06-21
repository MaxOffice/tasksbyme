param(
    [Parameter(Mandatory = $true, HelpMessage = "Your Azure tenant ID")]
    [string]$TenantId,
    
    [Parameter()]
    [string]$AppName = "PlannerTaskTracker",
    
    [string]$ResourceGroupPrefix = "rg-plannertracker",
    
    [switch]$Force,
    
    [switch]$WhatIf
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

#endregion

#region 🔍 Discovery & Confirmation

Write-Host "🔍 Discovering resources to remove..." -ForegroundColor Cyan

# Connect to Azure
Write-Host "Connecting to Azure..."
try {
    Connect-AzAccount -TenantId $TenantId -ErrorAction Stop
    Write-Host "✅ Successfully connected to Azure tenant: $TenantId"
} catch {
    Write-Error "❌ Failed to connect to Azure tenant '$TenantId'. Please verify the tenant ID is correct."
    exit 1
}

# Find resource groups
Write-Host "🔍 Searching for resource groups with prefix '$ResourceGroupPrefix'..."
$resourceGroups = Get-AzResourceGroup | Where-Object { $_.ResourceGroupName -like "$ResourceGroupPrefix-*" }

if ($resourceGroups.Count -eq 0) {
    Write-Host "ℹ️ No resource groups found with prefix '$ResourceGroupPrefix'" -ForegroundColor Yellow
} else {
    Write-Host "📁 Found $($resourceGroups.Count) resource group(s):" -ForegroundColor Green
    foreach ($rg in $resourceGroups) {
        Write-Host "   • $($rg.ResourceGroupName) (Location: $($rg.Location))" -ForegroundColor White
    }
}

# Connect to Microsoft Graph
Write-Host "Connecting to Microsoft Graph..."
try {
    Import-Module Microsoft.Graph.Authentication
    Import-Module Microsoft.Graph.Applications
    Connect-MgGraph -Scopes "Application.ReadWrite.All", "Directory.ReadWrite.All" -NoWelcome -ErrorAction Stop
    Write-Host "✅ Successfully connected to Microsoft Graph"
} catch {
    Write-Error "❌ Failed to connect to Microsoft Graph. Please check your permissions."
    exit 1
}

# Find Entra ID app registration
Write-Host "🔍 Searching for Entra ID app registration '$AppName'..."
$app = Get-MgApplication -Filter "displayName eq '$AppName'" -ErrorAction SilentlyContinue

if ($null -eq $app) {
    Write-Host "ℹ️ No Entra ID app registration found with name '$AppName'" -ForegroundColor Yellow
} else {
    Write-Host "🔐 Found Entra ID app registration:" -ForegroundColor Green
    Write-Host "   • Name: $($app.DisplayName)" -ForegroundColor White
    Write-Host "   • App ID: $($app.AppId)" -ForegroundColor White
    Write-Host "   • Object ID: $($app.Id)" -ForegroundColor White
}

# Summary of what will be removed
Write-Host "`n📋 Summary of resources to be removed:" -ForegroundColor Cyan
Write-Host "========================================"
if ($resourceGroups.Count -gt 0) {
    Write-Host "🗑️ Resource Groups ($($resourceGroups.Count)):"
    foreach ($rg in $resourceGroups) {
        Write-Host "   • $($rg.ResourceGroupName)"
    }
}
if ($null -ne $app) {
    Write-Host "🗑️ Entra ID App Registration:"
    Write-Host "   • $($app.DisplayName) ($($app.AppId))"
}

if ($resourceGroups.Count -eq 0 -and $null -eq $app) {
    Write-Host "✅ No resources found to remove. Exiting." -ForegroundColor Green
    exit 0
}

#endregion

#region 🚨 Confirmation

if ($WhatIf) {
    Write-Host "`n🔍 WhatIf mode enabled - no actual changes will be made." -ForegroundColor Yellow
    Write-Host "The above resources would be removed if you run without -WhatIf parameter."
    exit 0
}

if (-not $Force) {
    Write-Host "`n⚠️ WARNING: This action is IRREVERSIBLE!" -ForegroundColor Red
    Write-Host "All data in the resource groups will be permanently deleted." -ForegroundColor Red
    Write-Host "The Entra ID app registration and its credentials will be removed." -ForegroundColor Red
    
    $confirmation = Read-Host "`nType 'DELETE' to confirm removal of all listed resources"
    if ($confirmation -ne "DELETE") {
        Write-Host "❌ Operation cancelled. No resources were removed." -ForegroundColor Yellow
        exit 0
    }
}

#endregion

#region 🗑️ Removal Process

$ErrorActionPreference = "Continue"  # Continue on errors to attempt all cleanups

Write-Host "`n🗑️ Starting removal process..." -ForegroundColor Red

# Remove Entra ID app registration first
if ($null -ne $app) {
    Write-Host "🔐 Removing Entra ID app registration '$($app.DisplayName)'..."
    try {
        # Remove service principal first
        $servicePrincipal = Get-MgServicePrincipal -Filter "appId eq '$($app.AppId)'" -ErrorAction SilentlyContinue
        if ($null -ne $servicePrincipal) {
            Remove-MgServicePrincipal -ServicePrincipalId $servicePrincipal.Id -ErrorAction Stop
            Write-Host "✅ Service principal removed"
        }
        
        # Remove application
        Remove-MgApplication -ApplicationId $app.Id -ErrorAction Stop
        Write-Host "✅ Entra ID app registration '$($app.DisplayName)' removed successfully"
    } catch {
        Write-Error "❌ Failed to remove Entra ID app registration: $($_.Exception.Message)"
    }
}

# Remove resource groups
foreach ($rg in $resourceGroups) {
    Write-Host "📁 Removing resource group '$($rg.ResourceGroupName)'..."
    try {
        Remove-AzResourceGroup -Name $rg.ResourceGroupName -Force -ErrorAction Stop
        Write-Host "✅ Resource group '$($rg.ResourceGroupName)' removed successfully"
    } catch {
        Write-Error "❌ Failed to remove resource group '$($rg.ResourceGroupName)': $($_.Exception.Message)"
    }
}

#endregion

#region ✅ Summary

Write-Host "`n✅ Uninstall Complete" -ForegroundColor Green
Write-Host "========================"
Write-Host "🗑️ Removal Summary:"

if ($null -ne $app) {
    Write-Host "   • Entra ID App Registration: $($app.DisplayName)"
}

if ($resourceGroups.Count -gt 0) {
    Write-Host "   • Resource Groups: $($resourceGroups.Count)"
    foreach ($rg in $resourceGroups) {
        Write-Host "     - $($rg.ResourceGroupName)"
    }
}

Write-Host "========================"
Write-Host "🔍 Note: Some resources may take a few minutes to be fully removed from Azure." -ForegroundColor Yellow

#endregion