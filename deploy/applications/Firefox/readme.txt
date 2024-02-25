The script is set for x64 .msi files. 

parameters used in addition to ps app toolkit default silent install paramters are: "DESKTOP_SHORTCUT=false QUICKLAUNCH_SHORTCUT=true START_MENU_SHORTCUT=true INSTALL_MAINTENANCE_SERVICE=false"


If you want to use it for x64 .exe, or x86, you'll have to check the execution parameters to make sure they line up with the x64 msi (shortcuts, etc.)

The MDT installation didn't use the policies.json file, so I'm not sure if it's needed.


*10.1.2023 - this installer will grab the latest version msi file according to filename from the x64 directory