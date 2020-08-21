# ATG-PS-Functions
Frequently used functions for Ambitions Techs

## **!!!Notice!!!** ##

We are moving to a **function-based system**. There are 2 ways to load the functions for a session:

1) ### Powershell method ###  Run this:
```powershell
(New-Object Net.WebClient).downloadString('https://git.io/ATGPS') | Invoke-Expression
```
2) ### Browser method: ###
Open a browser to [https://git.io/ATGPS](https://git.io/ATGPS)
Select all the contents (CTRL+A), copy them (CTRL+C), and paste into a powershell window (Admin)


List of functions (can be entered as powershell commands):

- Add-IEShortcut
- Add-WebShortcut
- Connect-NetExtender
- Connect-O365
- Deploy-AppDefaults
- Disable-ATGLocalExpiration
- Disable-FastStartup
- Enable-SSL
- Get-ATGPS
- Install-Choco
- Install-DellUpdates
- Install-ITS247Agent
- Install-NetExtender
- Install-NiniteApps
- Install-NinitePro
- Install-O2016STD
- Install-O365
- Install-WindowsUpdates
- Join-Domain
- Remove-ITS247InstallFolder
- Rename-ClientComputer
- Run-Win10Decrap
- Set-AutoLogon
- Set-DailyReboot
- Set-MountainTime
- Set-NumLock
- Set-RunOnceScript
- Start-PPKGLog
- Update-Edge
- Update-ITS247Agent
- Update-PWSH
- Update-WindowsApps
- Update-WindowTitle

For more information on a function, type 
```powershell 
Help <function-name> -Detailed
```

**--Archive--** - Remote execution of scripts:

```powershell
Write-Host "Update Datto Agent"
$progressPreference = 'silentlyContinue'
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
Invoke-WebRequest https://download.ambitionsgroup.com/Scripts/DattoAgentUpdate.txt -UseBasicParsing | Invoke-Expression
```
