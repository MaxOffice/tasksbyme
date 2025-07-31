# MaxOffice.TasksByMe.Entra.psd1
# PowerShell Module Manifest for Tasks by Me Entra ID Application Management

@{
    RootModule = 'MaxOffice.TasksByMe.Entra.psm1'

    ModuleVersion = '1.0.2'

    CompatiblePSEditions = @('Desktop', 'Core')

    GUID = '715dddb2-36b9-4ba0-b7a6-2d491cf44fb8'

    Author = 'MaxOffice'

    CompanyName = 'MaxOffice'

    Copyright = '(c) 2025 MaxOffice. All rights reserved.'

    Description = 'PowerShell module for managing the Tasks by Me Entra ID application. Provides cmdlets for installing, configuring, inspecting, and removing the application.'

    PowerShellVersion = '5.1'

    RequiredModules = @(
        @{
            ModuleName = 'Microsoft.Graph.Applications'
            ModuleVersion = '2.29.1'
        },
        @{
            ModuleName = 'Microsoft.Graph.Authentication'
            ModuleVersion = '2.29.1'
        }
    )

    FunctionsToExport = @(
        'Install-TasksByMeApp',
        'Set-TasksByMeAppUrl',
        'Get-TasksByMeApp',
        'Remove-TasksByMeApp'
    )

    CmdletsToExport = @()

    VariablesToExport = @()

    AliasesToExport = @()

    FileList = @(
        'MaxOffice.TasksByMe.Entra.psm1',
        'MaxOffice.TasksByMe.Entra.psd1'
    )

    PrivateData = @{
        PSData = @{
            Tags = @('Entra', 'AzureAD', 'Application', 'Graph', 'Identity', 'TasksByMe')
            LicenseUri = 'https://github.com/maxoffice/tasksbyme/blob/main/LICENSE'
            ProjectUri = 'https://github.com/maxoffice/tasksbyme'
            IconUri = 'https://raw.githubusercontent.com/maxoffice/tasksbyme/main/assets/logo.png'
            ReleaseNotes = @'
1.0.2 - Bug Fix
- Upgraded version requirements for dependencies
- Reverted to using Set-MgApplicationLogo for logo upload
1.0.1 - Bug Fix
- Re-implemented logo upload using Invoke-MgGraphRequest
1.0.0
- Install-TasksByMeApp : Create new Tasks by Me Entra ID app with logo and client secret
- Set-TasksByMeAppUrl  : Set location of Tasks by Me web app
- Get-TasksByMeApp     : Display comprehensive information for Tasks by Me Entra ID app
- Remove-TasksByMeApp  : Delete Tasks by Me Entra ID app
'@
        }
    }
}