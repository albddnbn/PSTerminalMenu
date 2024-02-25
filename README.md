# PS Terminal Menu

![PowerShell](https://img.shields.io/badge/PowerShell-%235391FE.svg?style=for-the-badge&logo=powershell&logoColor=white)

## Description

This powershell menu was created to be able to execute functions quickly and efficiently on groups of target machine(s). The project was started in mid 2023, and is still in development.

When a new issue is encountered that allows for a scripted solution - resolution of the issue can be automated by adding the script/function to this menu.

**I'm working on another repository with PSADT installation and other Powershell scripts that aren't included in this menu.**

## Table of Contents (Optional)

- [Startup](#startup)
- [Usage](#usage)
- [Credits](#credits)
- [License](#license)

## Startup

After cloning or downloading the repository to your computer, open an Admin powershell window and change directory to where the menu.ps1 file is located. Then run the following:

    ```
    Set-ExecutionPolicy Bypass
    ./menu.ps1
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
<br><br> 2. Search for any functions offered in the menu containing the word 'Intune'. Select the **Get-IntuneHardwareIDs** function and enter parameter values to collect Intune hardware IDs from all devices with hostnames starting with 's-pc-'.<br><br>Add GroupTag 'EmployeePCs' to all device hwids. Output to file containing 's-pc-hwids'.

```
./menu.ps1 > Search > 'Intune' > Get-IntuneHardwareIDs
```

Parameter input:
| TargetComputer | DeviceGroupTag | OutputFile |
| --- | ---| --- |
| s-pc- | EmployeePCs | s-pc-hwids |

## Credits

This project was created by Alex B. in 2023.

### Powershell modules used:

**PS-MENU**: https://github.com/chrisseroka/ps-menu
**IMPORTEXCEL**: https://github.com/dfinke/ImportExcel
**PSADT**: https://psappdeploytoolkit.com/

### Scripts:

**Get-WindowsAutoPilotInfo.ps1**: https://github.com/Dattics/GetWindowsAutopilot

## License

The last section of a high-quality README file is the license. This lets other developers know what they can and cannot do with your project. If you need help choosing a license, refer to [https://choosealicense.com/](https://choosealicense.com/).

---

## Features

1. Gather details from groups of computers and generate reports.
2. Run scripts to perform software installations and maintenance tasks.
3. Search for specific details across groups of computers.
4. Easily incorporate new functions into the menu.

---

## Tests

---

### Created by Alex B.
