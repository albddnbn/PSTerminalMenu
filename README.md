# PS Terminal Menu

![PowerShell](https://img.shields.io/badge/PowerShell-%235391FE.svg?style=for-the-badge&logo=powershell&logoColor=white)

## Description

Working as an IT Support Specialist in 2022, I quickly became captivated with Powershell and it's ability to increase my efficiency.

I was amazed at the variety of Powershell modules that make it possible to interact with nearly every aspect of a Windows computer/network environment.

I already had a bit of a background in Java, Python, and object-oriented programming. While performing my duties, I began to take note of tasks or issues that had programmatic resolutions. I started to create scripts to perform tasks and implement resolutions, and I eventually reached a point where I realized that I needed to have all of these useful scripts in a single location, able to be executed on-demand at any given moment throughout my work day.

It was from this realization that the PSTerminalMenu tool was born - it's evolved into a collection of useful functions centered around the menu.ps1 script, which allows for their interactive selection and execution.

<b>This is an ongoing project, I appreciate any feedback or contributions!</b>

## Table of Contents

- [Startup](#startup)
- [Usage](#usage)
- [Search](#search)
- [Configuration](#configuration)
- [SupportFiles](#supportfiles)
- [Functions](#functions)
- [Resources](#resources)
- [License](#license)

## Startup

Download the repository .zip folder or download latest release and execute the menu.ps1 script.

```powershell
## Execute the PSTerminalMenu main script
Powershell.exe -ExecutionPolicy Bypass ./Menu.ps1
```

## Usage

1. Get basic computer details from single computer: t-client-01, and output report to file containing 'client-01-details' as part of filename.

```
./menu.ps1 > Scans > Get-ComputerDetails
```

Parameter input:
| TargetComputer | OutputFile |
| --- | --- |
| t-client-01 | client-01-details |

2. Search for any functions offered in the menu containing the word 'Intune'. Select the **Get-IntuneHardwareIDs** function and enter parameter values to collect Intune hardware IDs from all devices with hostnames starting with 's-pc-'.<br><br>Add GroupTag 'EmployeePCs' to all device hwids. Output to file containing 's-pc-hwids'.

```
./menu.ps1 > Search > 'Intune' > Get-IntuneHardwareIDs
```

Parameter input:
| TargetComputer | DeviceGroupTag | OutputFile |
| --- | ---| --- |
| s-pc- | EmployeePCs | s-pc-hwids |

## Search

**Search**: if you're not sure which category holds a function, you can use 'Search', located in the first menu.
Search will return any functions containing the keyword submitted and present them as a menu.

**Return to Previous Menu**: After searching or choosing a category, you can return to the category selection menu by choosing this option.

## Configuration

<b>Menu.ps1 is the central script of PSTerminalMenu.</b>

The menu layout can be configured through the <b>SupportFiles/config.json</b> file.



## To add a category

1. Write the name of the category into `config.json`, similar to what's shown in the image below.

<img src="docs\img\config-002-new-category.png" alt="Adding category to config" width="450" height="450">

## To add an option to the menu

1. Write the name of the file (without extension) into `config.json`, similar to the picture below.
2. If you add the filename into the "scans" section of the config file, it will appear after choosing the 'scans' category in the terminal menu.

<img src="docs\img\config-004-adding-function-name-to-config.png" alt="Adding function name to config" width="500" height="450">

## To add a function to the menu

1. Create a new .ps1 file in the functions directory. The function name should match the file name.

2. The function should have a multi-line comment at the top, containing the function description and parameter descriptions so that they'll display in the terminal when the function is chosen, **typical format for the comment is shown in the image below**.

```powershell
Function Function-Name {
    <#
    .SYNOPSIS
    Checks for a user logged in to a remote computer using the get-process cmdlet to check explorer.exe.

    .DESCRIPTION
    If the process doesn't exist, it returns false, because any user currently logged in to the PC will have explorer.exe running.

    .PARAMETER ComputerName
    DNS Hostname of remote computer. Ex: 's-a227-26'

    .EXAMPLE
    Get-User

    .EXAMPLE
    Get-User -ComputerName "s-a227-28"

    .NOTES
    Additional notes about the function.
    #>
    Write-Host "This is the function code"
}
```

## SupportFiles

This is a listing of the files in the SupportFiles directory with a brief description of their purpose.


  <tr>
    <td><strong>config.json</strong></td>
    <td>Contains the menu categories and functions.</td>
  </tr>
  <tr>
    <td><strong>drivemap.ico</strong></td>
    <td>Used in the New-DriveMappingExe function to create generic icon for shortcut.</td>
  </tr>
  <tr>
    <td><strong>function_template.ps1</strong></td>
    <td>Template for creating new functions. Contains the begin and end blocks - most important part to add to the function is the scriptblock that is executed on each target computer.</td>
  </tr>
  <tr>
    <td><strong>Get-WindowsAutoPilotInfo.ps1</strong></td>
    <td>Used in Get-IntuneHardwareIDs function as an alternative to Importing the Get-WindowsAutoPilotInfo script from the Internet.</td>
  </tr>
  <tr>
    <td><strong>IntuneWinAppUtil.exe</strong></td>
    <td>Used in the New-IntuneWinApp function to create .intunewin package from a PSADT deployment folder.</td>
  </tr>
  <tr>
    <td><strong>inventory_database_api_response.json</strong></td>
    <td>A sample of a response from upcitemdb.com's UPC code lookup API, gives information about specified product.</td>
  </tr>
  <tr>
    <td><strong>it-logo.png</strong></td>
    <td>Used in New-BrandedHTMLReport function (currently in testing dir) to add generic IT Dept. logo.</td>
  </tr>
  <tr>
    <td><strong>negativebeep.wav</strong></td>
    <td>Used in the Scan-Inventory function to play audible negative sounding beep when something bad happens.</td>
  </tr>
  <tr>
    <td><strong>positivebeep.wav</strong></td>
    <td>Used in the Scan-Inventory function to play audible positive sounding beep when something good happens.</td>
  </tr>
  <tr>
    <td><strong>ps1avatar.ico</strong></td>
    <td>Generic/cool-looking Powershell avatar icon that can be used with compiled executables/etc. if nothing more appropriate available.</td>
  </tr>
  <tr>
    <td><strong>teamsbootstrapper.exe</strong></td>
    <td>Used in the New-TeamsInstaller function to install Teams on a remote computer.</td>
  </tr>
  <tr>
    <td><strong>w3.css</strong></td>
    <td>Used in the New-BrandedHTMLReport function to add styling to the HTML report.</td>
  </tr>
</table>

## Functions

Each function in the functions directory of PSTerminalMenu should also work as a 'standalone' function. This means that you should be able to copy/paste the function into a terminal, and execute it with appropriate parameters.

For example:

<b>Get-ComputerDetails.ps1</b>

```powershell
## Gather computer details from computers w/hostnames starting with s-a231- or s-a230-, output to GridView
Get-ComputerDetails -TargetComputer 's-a231-,s-a230-' -OutputFile n

## Gather two computers' details, output to computer-info.csv/xlsx file:
's-a231-01,s-a231-02' | Get-ComputerDetails -OutputFile computer-info
```

## Resources

<table>
  <tr>
    <td><strong>Get-WindowsAutoPilotInfo.ps1</strong></td>
    <td><a href="https://github.com/Dattics/GetWindowsAutopilot">https://github.com/Dattics/GetWindowsAutopilot</a></td>
  </tr>
  <tr>
    <td><strong>IntuneWinAppUtil.exe</strong></td>
    <td><a href="https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool">https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool</a></td>
  </tr>
  <tr>
    <td><strong>PS-MENU</strong></td>
    <td><a href="https://github.com/chrisseroka/ps-menu">https://github.com/chrisseroka/ps-menu</a></td>
  </tr>
  <tr>
    <td><strong>IMPORTEXCEL</strong></td>
    <td><a href="https://github.com/dfinke/ImportExcel">https://github.com/dfinke/ImportExcel</a></td>
  </tr>
  <tr>
    <td><strong>PSADT</strong></td>
    <td><a href="https://psappdeploytoolkit.com/">https://psappdeploytoolkit.com/</a></td>
  </tr>
</table>
