# MaxOffice.TasksByMe.Azure.psd1
# PowerShell Module Manifest for Tasks by Me web Application Management on Azure App Service

@{
    RootModule = 'MaxOffice.TasksByMe.Azure.psm1'

    ModuleVersion = '1.1.0'

    CompatiblePSEditions = @('Desktop', 'Core')

    GUID = 'f6112817-650d-4460-bf40-87861385ad45'

    Author = 'MaxOffice'

    CompanyName = 'MaxOffice'

    Copyright = '(c) 2025 MaxOffice. All rights reserved.'

    Description = 'PowerShell module for deploying Tasks by Me to Azure App Service (Free Tier)'

    PowerShellVersion = '5.1'

    RequiredModules = @(
        'Az.Resources',
        'Az.Websites',
        'MaxOffice.TasksByMe.Entra'
    )

    FunctionsToExport = @(
        'Install-TasksByMeAzureWebApp',
        'Get-TasksByMeAzureWebApp',
        'Remove-TasksByMeAzureWebApp'
    )

    CmdletsToExport = @()

    VariablesToExport = @()

    AliasesToExport = @()

    PrivateData = @{
        PSData = @{
            Tags = @('Azure', 'PowerShell', 'Deployment', 'AppService', 'TasksByMe')
            LicenseUri = 'https://github.com/maxoffice/tasksbyme/blob/main/LICENSE'
            ProjectUri = 'https://github.com/maxoffice/tasksbyme'
            IconUri = 'https://raw.githubusercontent.com/maxoffice/tasksbyme/main/assets/logo.png'
                        ReleaseNotes = @'
1.1.0 - Install Tasks By Me Web app to any region, and choose the pricing tier
- Install-TasksByMeAzureWebApp : Deploy Tasks by Me web app as an Azure Web App from the GitHub repo
- Get-TasksByMeAzureWebApp     : Display comprehensive information for Tasks by Me Azure Web App
- Remove-TasksByMeAzureWebApp  : Delete Tasks by Me Azure Web App
'@
        }
    }
}
