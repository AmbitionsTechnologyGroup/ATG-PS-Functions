# ATG-PS-Functions
Frequently used Powershell functions for Ambitions Techs

We are using a **function-based system**. There are 2 ways to load the functions for a session:

### 1) Powershell method ###

**Run _either_:**
```powershell
$progressPreference = 'silentlyContinue' #If running from a LogMeIn terminal
iwr tinyurl.com/get-atgps -usebasicparsing | iex
```

**--OR--**

```powershell
IEX(new-object net.webclient).downloadstring('https://git.io/atgPS')

# note that this may not work if SSL is not enabled in PowerShell; use the above tinyurl method for http
```

### 2) Browser method: ###
Open a browser to [https://git.io/ATGPS](https://git.io/ATGPS)
Select all the contents (CTRL+A), copy them (CTRL+C), and paste into a powershell window (Admin)


List of functions (can be entered as powershell commands):
```powershell
Add-IEShortcut
Add-WebShortcut
Connect-NetExtender
Connect-O365
Disable-ATGLocalExpiration
Disable-FastStartup
Disconnect-AllUsers
Enable-O365AuditLog
Enable-SSL
Expand-Terminal
Get-ADUserPassExpirations
Install-AppDefaults
Install-Choco
Install-ITS247Agent
Install-NetExtender
Install-NiniteApps
Install-NinitePro
Install-O2016STD
Install-O365
Install-O365ProofPointConnectors
Invoke-Win10Decrap
Join-Domain
Remove-ITS247InstallFolder
Rename-ClientComputer
Repair-Windows
Set-AutoLogon
Set-DailyReboot
Set-MountainTime
Set-NumLock
Set-RunOnceScript
Start-PPKGLog
Update-DattoAgent
Update-DellPackages
Update-Edge
Update-ITS247Agent
Update-NiniteApps
Update-PWSH
Update-Windows
Update-WindowsApps
Update-WindowTitle

#This list can be updated with "Get-Command -Module ATGPS | Select Name"
```
### For more information on a function, type:
```powershell 
Help <function-name> -Detailed
```
