# MaxOffice.TasksByMe.Entra.psd1
# PowerShell Module Manifest for Tasks by ME Entra ID Management

@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'MaxOffice.TasksByMe.Entra.psm1'

    # Version number of this module.
    ModuleVersion = '1.0.0'

    # Supported PSEditions
    CompatiblePSEditions = @('Desktop', 'Core')

    # ID used to uniquely identify this module
    GUID = 'a1b2c3d4-e5f6-7890-1234-567890abcdef'

    # Author of this module
    Author = 'Your Organization'

    # Company or vendor of this module
    CompanyName = 'Your Company'

    # Copyright statement for this module
    Copyright = '(c) 2025 Your Organization. All rights reserved.'

    # Description of the functionality provided by this module
    Description = 'PowerShell module for managing the Tasks by ME Entra ID application. Provides cmdlets for installing, configuring, inspecting, and removing the application.'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '5.1'

    # Name of the PowerShell host required by this module
    # PowerShellHostName = ''

    # Minimum version of the PowerShell host required by this module
    # PowerShellHostVersion = ''

    # Minimum version of Microsoft .NET Framework required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
    # DotNetFrameworkVersion = ''

    # Minimum version of the common language runtime (CLR) required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
    # ClrVersion = ''

    # Processor architecture (None, X86, Amd64) required by this module
    # ProcessorArchitecture = ''

    # Modules that must be imported into the global environment prior to importing this module
    RequiredModules = @(
        @{
            ModuleName = 'Microsoft.Graph.Applications'
            ModuleVersion = '2.0.0'
        },
        @{
            ModuleName = 'Microsoft.Graph.Authentication'
            ModuleVersion = '2.0.0'
        }
    )

    # Assemblies that must be loaded prior to importing this module
    # RequiredAssemblies = @()

    # Script files (.ps1) that are run in the caller's environment prior to importing this module.
    # ScriptsToProcess = @()

    # Type files (.ps1xml) to be loaded when importing this module
    # TypesToProcess = @()

    # Format files (.ps1xml) to be loaded when importing this module
    # FormatsToProcess = @()

    # Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
    # NestedModules = @()

    # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
    FunctionsToExport = @(
        'Install-TasksByMeApp',
        'Set-TasksByMeAppUrl',
        'Get-TasksByMeApp',
        'Remove-TasksByMeApp'
    )

    # Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
    CmdletsToExport = @()

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
    AliasesToExport = @()

    # DSC resources to export from this module
    # DscResourcesToExport = @()

    # List of all modules packaged with this module
    # ModuleList = @()

    # List of all files packaged with this module
    FileList = @(
        'MaxOffice.TasksByMe.Entra.psm1',
        'MaxOffice.TasksByMe.Entra.psd1'
    )

    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData = @{
        PSData = @{
            # Tags applied to this module. These help with module discovery in online galleries.
            Tags = @('Entra', 'AzureAD', 'Application', 'Graph', 'Identity', 'Tasks')

            # A URL to the license for this module.
            # LicenseUri = 'https://github.com/yourorg/tasksbyme-entra/blob/main/LICENSE'

            # A URL to the main website for this project.
            # ProjectUri = 'https://github.com/yourorg/tasksbyme-entra'

            # A URL to an icon representing this module.
            # IconUri = 'https://github.com/yourorg/tasksbyme-entra/blob/main/icon.png'

            # ReleaseNotes of this module
            ReleaseNotes = @'
1.0.0 - Initial release
- Install-TasksByMeApp: Create new Tasks by Me Entra ID app with logo and client secret
- Set-TasksByMeUrl: Set location of Tasks by Me web app
- Get-TasksByMeApp: Display comprehensive information for Tasks by Me Entra ID app
- Remove-TasksByMeApp: Delete Tasks by Me Entra ID app
'@

            # Prerelease string of this module
            # Prerelease = ''

            # Flag to indicate whether the module requires explicit user acceptance for install/update/save
            # RequireLicenseAcceptance = $false

            # External dependent modules of this module
            # ExternalModuleDependencies = @()
        }
    }

    # HelpInfo URI of this module
    # HelpInfoURI = 'https://github.com/yourorg/tasksbyme-entra/help'

    # Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
    # DefaultCommandPrefix = ''
}