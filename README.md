# ATG-PS-Functions
Frequently used functions for Ambitions Techs

## **!!!Notice!!!** ##

We are moving to a **function-based system**. There are 2 ways to load the functions for a session:

1) Powershell method- Run this:
```powershell
Invoke-WebRequest psfunc.ambitionsgroup.com -UseBasicParsing | Invoke-Expression
```
2) Browser method:
Open a browser to [psfunc.ambitionsgroup.com](http://psfunc.ambitionsgroup.com)
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
- Remove-ITS247Installer
- Run-Win10Decrap
- Set-AutoLogon
- Set-DailyReboot
- Set-MountainTime
- Set-NumLock
- Set-RunOnceScript
- Start-PPKGLog
- Update-Edge
- Update-PWSH
- Update-WindowsApps
- Update-WindowTitle

For more information on a function, type 
```powershell 
Help <function-name> -Detailed
```




**--Archive--** - Remote execution of scripts:

```powershell
Write-Host "Dell Command Update"
$progressPreference = 'silentlyContinue'
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
Invoke-WebRequest https://download.ambitionsgroup.com/Scripts/DCU_AUTO.txt -UseBasicParsing | Invoke-Expression
```

```powershell
Write-Host "Chocolatey Install"
$progressPreference = 'silentlyContinue'
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
Invoke-WebRequest https://download.ambitionsgroup.com/Scripts/installchoco.txt -UseBasicParsing | Invoke-Expression
```
```powershell
Write-Host "Update Windows"
$progressPreference = 'silentlyContinue'
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
Invoke-WebRequest https://download.ambitionsgroup.com/Scripts/UpdateWindows.txt -UseBasicParsing | Invoke-Expression
```
```powershell
Write-Host "Update Datto Agent"
$progressPreference = 'silentlyContinue'
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
Invoke-WebRequest https://download.ambitionsgroup.com/Scripts/DattoAgentUpdate.txt -UseBasicParsing | Invoke-Expression
```
```powershell
Write-Host "Windows 10 Decrapifier"
$progressPreference = 'silentlyContinue'
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
Invoke-WebRequest https://download.ambitionsgroup.com/Scripts/Windows10Decrapifier.txt -UseBasicParsing | Invoke-Expression
```
```powershell
Write-Host "Install ITS247 Agent"
$progressPreference = 'silentlyContinue'
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
Invoke-WebRequest https://download.ambitionsgroup.com/Sites/Install_ITS247_Agent.txt -UseBasicParsing | Invoke-Expression
```
