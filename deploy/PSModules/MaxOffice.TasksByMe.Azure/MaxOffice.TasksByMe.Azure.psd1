@{
    # Script module or binary module file associated with this manifest
    RootModule = 'MaxOffice.TasksByMe.Azure.psm1'

    # Version number of this module
    ModuleVersion = '1.0.0'

    # ID used to uniquely identify this module
    GUID = 'f6112817-650d-4460-bf40-87861385ad45'

    # Author of this module
    Author = 'Your Name'

    # Company or vendor of this module
    CompanyName = 'MaxOffice'

    # Description of the functionality provided by this module
    Description = 'PowerShell module for deploying Tasks by Me to Azure App Service'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '5.1'

    # Modules required by this module
    RequiredModules = @(
        'Az.Resources',
        'Az.Websites',
        'MaxOffice.TasksByMe.Entra'
    )

    # Assemblies used by this module
    RequiredAssemblies = @()

    # Functions exported from this module
    FunctionsToExport = @(
        'Install-TasksByMeAzureWebApp',
        'Get-TasksByMeAzureWebApp',
        'Remove-TasksByMeAzureWebApp'
    )

    # Cmdlets exported from this module
    CmdletsToExport = @()

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module
    AliasesToExport = @()

    # Private data to pass to the module specified in RootModule
    PrivateData = @{
        PSData = @{
            Tags = @('Azure', 'PowerShell', 'Deployment', 'AppService', 'TasksByMe')
            LicenseUri = 'https://opensource.org/licenses/MIT'
            ProjectUri = 'https://github.com/maxoffice/planner-task-tracker'
            IconUri = 'https://raw.githubusercontent.com/maxoffice/planner-task-tracker/main/assets/icon.png'
        }
    }

    # HelpInfo URI for online help
    HelpInfoURI = ''
}
