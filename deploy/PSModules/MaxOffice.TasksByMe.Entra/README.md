# MaxOffice.TasksByMe.Entra

PowerShell module for managing the **Tasks by Me** Entra ID application.

## Installation

```powershell
Install-Module -Name MaxOffice.TasksByMe.Entra -Scope CurrentUser
```

## Features

- Create an Entra ID application with logo and client secret
- Configure the web application URL
- View application details
- Remove the application from your tenant

## Requirements

- PowerShell 5.1 or later
- Required modules:
  - Microsoft.Graph.Applications v2.0.0
  - Microsoft.Graph.Authentication v2.0.0

## Project Info

Project: https://github.com/maxoffice/tasksbyme  
License: https://github.com/maxoffice/tasksbyme/blob/main/LICENSE  

## Release Notes

**1.0.0** – Initial release with core cmdlets for app creation, configuration, inspection, and removal.
