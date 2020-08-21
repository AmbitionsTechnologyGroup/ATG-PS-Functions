<#This script will use chocolatey to install Dell Command Update to the latest version, then use it to update drivers and BIOS.
To run this script directly from Powershell without copying and pasting, run:

Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('http://download.ambitionsgroup.com/Scripts/DCU_AUTO.ps1'))

#>

#Install and update Chocolatey if Needed
If (Get-Command choco -errorAction SilentlyContinue) {
	choco upgrade chocolatey
} else {
	Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://download.ambitionsgroup.com/Scripts/installchoco.ps1'))
	choco upgrade chocolatey
}

	#Remove any programs listed through "Add and remove programs"
	If (Get-WmiObject -Class Win32_Product | Where-Object {$_.Name -like "*Dell*Update*"}) {
		(Get-WmiObject -Class Win32_Product | Where-Object {$_.Name -like "*Dell*Update*"}).Uninstall()
	}

	#Remove any Windows 10 "Apps"
	Get-AppxPackage *Dell*Update* | Remove-AppxPackage

#Install the latest
	Choco install dellcommandupdate -y

#Configure and run Dell Command Update
if (Test-Path 'C:\Program Files (x86)\Dell\CommandUpdate\dcu-cli.exe') {
	& 'C:\Program Files (x86)\Dell\CommandUpdate\dcu-cli.exe' /configure -autoSuspendBitLocker=enable
	& 'C:\Program Files (x86)\Dell\CommandUpdate\dcu-cli.exe' /applyUpdates -reboot=disable
} elseif (Test-Path 'C:\Program Files\Dell\CommandUpdate\dcu-cli.exe') {
	& 'C:\Program FilesDell\CommandUpdate\dcu-cli.exe' /configure -autoSuspendBitLocker=enable
	& 'C:\Program Files\Dell\CommandUpdate\dcu-cli.exe' /applyUpdates -reboot=disable
} else {
	Write-Error "Dell Command Update CLI not found."
}