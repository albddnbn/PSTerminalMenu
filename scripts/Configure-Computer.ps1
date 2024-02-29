##Function will configure different settings that are useful / nice on a computer, including:
# 1. install vs code, notepad++, windows terminal , Set Dracula at night theme
# 2. import enable expanded context menu reg file
# 3. import copy as path in context menu reg file
# 4. install chrome, set as default
Function Configure-Computer {
    ## Dracula themes: https://github.com/dracula
    $APPS_TO_INSTALL = [system.collections.arraylist]::new(
        {
            Name = "Google Chrome"
            Installer = "https://dl.google.com/chrome/install/GoogleChromeStandaloneEnterprise64.msi"
            ThemeFile = ""
            Arguments = "/quiet /norestart"
        },
        {
            Name = "Notepad++"
            Installer = ""
            ThemeFile = "dracula.xml"
            Arguments = ""
        },
        {
            Name = "Visual Studio Code"
            Installer = "https://go.microsoft.com/fwlink/?LinkID=852157"
            ThemeFile = "dracula.json"
            Arguments = "/silent"
        }
    )
    $APPX_PACKAGES_TO_INSTALL = @(
        "Microsoft.WindowsTerminal"
    )

    $REG_FILES_TO_IMPORT = @(
        "EnableExpandedContextMenu.reg",
        "CopyAsPath.reg"
    )
}
