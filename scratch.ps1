Set-ExecutionPolicy Bypass -Scope Process -Force

# Create Log and start Transcript
$SaveFolder = 'C:\Ambitions'
New-Item -ItemType Directory -Force -Path $SaveFolder
Start-Transcript -IncludeInvocationHeader -Path "$SaveFolder\ITS247-Install.log"

# Download the custom ITS Installer Script
Write-Host Downloading the Installer
$client = New-Object System.Net.WebClient
$client.DownloadFile('https://raw.githubusercontent.com/AmbitionsTechnologyGroup/ATG-PS-Functions/master/Scripts/ITS247Agent/Install_ITS247_Agent.txt', "$SaveFolder\InstallAgent.ps1")

# Run the Installer
& $SaveFolder\InstallAgent.ps1 -Code PE -Silent

# Stop transcript output
Stop-Transcript


# Remove drivers for Ricoh Aficio MP 6054
Write-Host Starting transcript
Start-Transcript -Path "C:\Ambitions\remove_ricoh_6054.log"

#Write-Host Checking for existing printer
#If (Test-Path -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Print\Environments\Windows x64\Drivers\Version-3\RICOH MP 6054 PCL 6')

# Define driver files & paths
$driverFilePath = "C:\Windows\System32\spool\drivers\x64\3"
$ricohDriverFiles = @("rica6P*", "ricdb64.dll", "mfricr64.dll", "RD06Pd64.dll")

Write-Host Stopping spooler service...
Stop-Service -Name Spooler -Force -Verbose

Write-Host Waiting for Spooler to stop...
Start-Sleep -Seconds 5

Write-Host Removing all driver files...
ForEach ($file in $ricohDriverFiles) {
    Remove-Item -Path "$driverFilePath\$file" -Force -Verbose
}
Remove-Item -Path "C:\WINDOWS\System32\DriverStore\FileRepository\oemsetup.inf_amd64_826a4637b5826640" -Force -Recurse -Verbose

Write-Host Deleting registry entries for the driver...
Remove-Item -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Print\Environments\Windows x64\Drivers\Version-3\RICOH MP 6054 PCL 6' -Force -Verbose
Remove-Item -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Print\Monitors\rica6Plm' -Force -Verbose

Write-Host Starting the Spooler Service...
Start-Service -Name Spooler -Verbose

Stop-Transcript
