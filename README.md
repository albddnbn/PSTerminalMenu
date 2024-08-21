# PS Terminal Menu

![PowerShell](https://img.shields.io/badge/PowerShell-%235391FE.svg?style=for-the-badge&logo=powershell&logoColor=white)

## Description

After I started working as an IT Specialist I in October of 2022, I quickly became captivated by PowerShell and its ability to increase my efficiency as an IT professional. I had a bit of a background with object-oriented programming in Python 3 and Java including what I’d learned during a Programming I course, a large number of codecademy courses, and what I’d managed to teach myself while tutoring for Programming II and III courses.
By the start of 2023, I had managed to learn a lot of the absolute ‘bare basics’ of PowerShell scripting. I had begun to realize the power behind the scripting language, and I started to take note of different tasks and issues that I would come across that had programmatic resolutions.

This powershell menu was created to aid in the efficient access and execution of scripts that can resolve a variety of issues, gather information, and more.

**Repository with PSADT installation scripts**: [https://github.com/albddnbn/powershellnexusone/tree/main/installs](https://github.com/albddnbn/powershellnexusone/tree/main/installs)

## Table of Contents

- [Startup](#startup)
- [Usage](#usage)
- [Search](#search)
- [Config](#config)
- [Credits](#credits)
- [License](#license)

## Startup

After cloning or downloading the repository to your computer, open an Admin powershell window and change directory to where the menu.ps1 file is located. Then run the following:

    ```
    ## Testing best way to deal with execution policy prompts
    ## Set-ExecutionPolicy Unrestricted
    ./menu.ps1
    ```

At this point in time, if you're computer doesn't have access to the Internet to download the modules - you may have to install the ps-menu module in supportfiles using the install-module.ps1 script.

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

## Config

## To add a category:

1. Write the name of the category into `config.json`, similar to what's shown in the image below.

<img src="docs\img\config-002-new-category.png" alt="Adding category to config" width="450" height="450">

## To add an option to the menu:

1. Write the name of the file (without extension) into `config.json`, similar to the picture below.
2. If you add the filename into the "scans" section of the config file, it will appear after choosing the 'scans' category in the terminal menu.

<img src="docs\img\config-004-adding-function-name-to-config.png" alt="Adding function name to config" width="500" height="450">

## To add a function to the menu:

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

## Credits

This project was created by Alex B. in 2023.

### Powershell modules used:

**PS-MENU**: https://github.com/chrisseroka/ps-menu

**IMPORTEXCEL**: https://github.com/dfinke/ImportExcel

**PSADT**: https://psappdeploytoolkit.com/

### Scripts:

**Get-WindowsAutoPilotInfo.ps1**: https://github.com/Dattics/GetWindowsAutopilot

## License

---

## A few of the features

1. Gather details from groups of computers and generate reports.
2. Run scripts to perform software installations and maintenance tasks.
3. Search for specific details across groups of computers.
4. Easily incorporate new functions into the menu.
