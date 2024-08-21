# ATG-PS-Functions
Frequently used Powershell functions for Ambitions Techs

We are using a **function-based system**. There are 2 ways to load the functions for a session:

### 1) Powershell method ###

**Run _either_:**
```powershell
irm ps.acgs.io|iex
```

**--OR--**

```powershell
IEX(new-object net.webclient).downloadstring('https://git.io/atgPS')

# note that this may not work if SSL is not enabled in PowerShell.
```

### List of functions (can be entered as powershell commands): ###
```powershell

Name
----
Add-ChromeShortcut
Add-FileFolderShortcut
Add-IEShortcut
Add-WebShortcut
Backup-LastUser
Connect-NetExtender
Connect-O365AzureAD
Connect-O365Exchange
Connect-O365Sharepoint
Connect-O365SharepointPNP
Connect-Wifi
Convert-ToSharedMailbox
Debug-ServerRebootScript
Debug-SharedMailboxRestoreRequest
Debug-UmbrellaDNS
Debug-UmbrellaProxiedDnsServer
Disable-ATGLocalExpiration
Disable-DailyReboot
Disable-FastStartup
Disable-Sleep
Disconnect-AllUsers
Disconnect-NetExtender
Disconnect-O365Exchange
Enable-DellSecureBoot
Enable-DellWakeUpInMorning
Enable-O365AuditLog
Enable-Onedrive
Enable-Sleep
Enable-SSL
Enable-WakeOnLAN
Expand-Terminal
Export-365AllDistributionGroups
Export-365DistributionGroup
Export-LDAPSCertificate
Export-UsersOneDrive
Get-ADStaleComputers
Get-ADStaleUsers
Get-ADUserPassExpirations
Get-ATGPS
Get-BitLockerKey
Get-DellWarranty
Get-DiskUsage
Get-DomainInfo
Get-FileDownload
Get-InstalledApplication
Get-InternetHealth
Get-IPConfig
Get-ListeningPorts
Get-LoginHistory
Get-NetExtenderStatus
Get-PSWinGetUpdatablePackages
Get-SharedMailboxRestoreRequest
Get-SonicwallInterfaceIP
Get-ThunderBolt
Get-UserMailboxAccess
Get-UserProfileSpace
Get-VSSWriter
Import-PPESenderLists
Import-PPESingleUserSenderLists
Import-WindowsInstallerDrivers
Install-AppDefaults
Install-Choco
Install-ITS247Agent
Install-NetExtender
Install-NiniteApps
Install-NinitePro
Install-O2016STD
Install-O365
Install-O365ProofPointConnectors
Install-UmbrellaDns
Install-UmbrellaDNSasJob
Install-UmbrellaDnsCert
Install-WinGet
Install-WinGetApps
Install-WinRepairToolbox
Invoke-IPv4NetworkScan
Invoke-NDDCScan
Invoke-Win10Decrap
Join-Domain
Optimize-Powershell
Remove-ADStaleComputers
Remove-DuplicateFiles
Remove-ITS247InstallFolder
Remove-PathForcefully
Remove-StaleObjects
Rename-ClientComputer
Repair-O365AppIssues
Repair-Volumes
Repair-Windows
Restart-VSSWriter
Restore-LastUser
Send-WakeOnLan
Set-AutoLogon
Set-ComputerLanguage
Set-DailyReboot
Set-DailyRebootDelay
Set-DnsMadeEasyDDNS
Set-MountainTime
Set-NumLock
Set-PsSpeak
Set-RunOnceScript
Set-ServerRebootScriptPassword
Set-WeeklyReboot
Start-BackstageBrowser
Start-CleanupOfSystemDrive
Start-ImperialMarch
Start-PPKGLog
Start-PSWinGet
Start-ServerMaintenance
Uninstall-Application
Uninstall-UmbrellaDNS
Update-DattoAgent
Update-DellPackages
Update-DellServer
Update-DnsServerRootHints
Update-Edge
Update-Everything
Update-ITS247Agent
Update-NiniteApps
Update-NTPDateTime
Update-O365Apps
Update-PowershellModules
Update-PSWinGetPackages
Update-PWSH
Update-Windows
Update-WindowsApps
Update-WindowTitle


#This list can be updated with "Get-Command -Module ATG-PS-* | Select Name"
```
### For more information on a function, type:
```powershell 
Help <function-name> -Detailed
```
