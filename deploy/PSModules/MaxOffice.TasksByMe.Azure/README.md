# MaxOffice.TasksByMe.Azure

PowerShell module for deploying the **Tasks by Me** web application to Azure App Service(Free Tier).

## Installation

```powershell
Install-Module -Name MaxOffice.TasksByMe.Azure -Scope CurrentUser
```

## Features

- Deploy the web application to Azure App Service (Free Tier)
- View deployment details
- Remove the Azure-hosted application and related resources

## Requirements

- PowerShell 5.1 or later
- Required modules:
  - Az.Resources
  - Az.Websites
  - MaxOffice.TasksByMe.Entra

## Project Info

Project: https://github.com/maxoffice/tasksbyme  
License: https://github.com/maxoffice/tasksbyme/blob/main/LICENSE  

## Release Notes

**1.0.0** – Initial release with cmdlets to deploy, inspect, and remove the **Tasks by Me** web application.
