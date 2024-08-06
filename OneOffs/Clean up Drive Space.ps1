$ErrorActionPreference = "silentlycontinue"
#[System.Net.ServicePointManager]::SecurityProtocol = 3072 -bor 768 -bor 192 ; irm 'https://raw.githubusercontent.com/AmbitionsTechnologyGroup/ATG-PS-Functions/master/OneOffs/Clean%20up%20Drive%20Space.ps1' | iex
#Clean up Drive Space
#Enable SSL/TLS
Try {
	# Set TLS 1.2 (3072), then TLS 1.1 (768), then TLS 1.0 (192)
	# Use integers because the enumeration values for TLS 1.2 and TLS 1.1 won't
	# exist in .NET 4.0, even though they are addressable if .NET 4.5+ is
	# installed (.NET 4.5 is an in-place upgrade).
	[System.Net.ServicePointManager]::SecurityProtocol = 3072 -bor 768 -bor 192
} Catch {
	Write-Output 'Unable to set PowerShell to use TLS 1.2 and TLS 1.1 due to old .NET Framework installed. If you see underlying connection closed or trust errors, you may need to upgrade to .NET Framework 4.5+ and PowerShell v3+.'
}

#Load Functions without using disk space
irm "https://raw.githubusercontent.com/AmbitionsTechnologyGroup/ATG-PS-Functions/master/Functions/ATG-PS-Remove.txt" | iex


$VerbosePreference = "Continue"
$DaysToDelete = 7
$LogDate = get-date -format "MM-d-yy-HH"
$ErrorActionPreference = "silentlycontinue"

# Assign the pre-cleanup storage state to a variable.
$PreClean = Get-CimInstance -ClassName Win32_LogicalDisk | Where-Object -Property DriveType -EQ 3 | Where-Object -Property DeviceID -EQ $Env:SystemDrive | Select-Object -Property @{ Name = 'Drive'; Expression = { ($PSItem.DeviceID) } },
	@{ Name = 'Size (GB)'; Expression = { '{0:N1}' -f ($PSItem.Size / 1GB) } },
	@{ Name = 'FreeSpace (GB)'; Expression = { '{0:N1}' -f ($PSItem.Freespace / 1GB) } },
	@{ Name = 'PercentFree'; Expression = { '{0:P1}' -f ($PSItem.FreeSpace / $PSItem.Size) } }

# Assign the local and global paths to their own variables for easier path building.
	$GlobalAppData = $Env:APPDATA.Replace($($Env:USERPROFILE),$(($Env:Public).Replace('Public','*')))
	$LocalAppData = $Env:LOCALAPPDATA.Replace($($Env:USERPROFILE),$(($Env:Public).Replace('Public','*')))
	$RootAppData = "$(Split-Path -Path $LocalAppData)\*"

Function Invoke-WindowsCleanMgr {
	# Set registry keys to check all Disk Cleanup boxes
	$SageSet = "StateFlags0097"
	$StateFlags = "Stateflags0097"
	$Base = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\"
	$VolCaches = Get-ChildItem $Base
	$Locations = @($VolCaches.PSChildName)
	foreach ($VC in $VolCaches) {New-ItemProperty -Path "$($VC.PSPath)" -Name $StateFlags -Value 1 -Type DWORD -Force | Out-Null}
	ForEach ($Location in $Locations) {Set-ItemProperty -Path $($Base + $Location) -Name $SageSet -Type DWORD -Value 2 -ea SilentlyContinue | Out-Null}
	$Argss = "/sagerun:$([string]([int]$SageSet.Substring($SageSet.Length - 4)))"
	#Write-Host "Running Windows CleanMgr /verylowdisk"
	#Start-Process -Wait "$env:SystemRoot\System32\cleanmgr.exe" -ArgumentList "/verylowdisk /d c" -WindowStyle Hidden
	Write-Host "Running Windows CleanMgr /everything"
	Start-Process -Wait "$env:SystemRoot\System32\cleanmgr.exe" -ArgumentList $Argss -WindowStyle Hidden
	Write-Host "Done Windows CleanMgr"
}

Function Remove-WindowsRestorePoints {
	# Windows Server uses its integrated scheduled backup feature as shadow copies removing them would actually delete the scheduled full disk backups that are created.
	If ((Get-CimInstance -ClassName Win32_OperatingSystem | Select-Object -ExpandProperty Caption) -notlike "Microsoft Windows Server*") {
		# Remove all system shadow copies if the -Include parameter with the 'RestorePoints' value is used and the running system is not a Windows Server.
		If (Get-CimInstance -ClassName Win32_ShadowCopy) {
			Get-CimInstance -ClassName Win32_ShadowCopy -Verbose:$false | ForEach-Object -Process {
				Write-Verbose ('Performing the operation "Delete ShadowCopy" on target "{0}"' -f $PSItem.ID) -Verbose
				$PSItem | Remove-CimInstance -Verbose:$false
			}
		}
	}
}

Function Remove-EventLogs {
	# Remove all event logs and event tracer log files if the -Include parameter with the 'EventLogs' value is used.
	Get-WinEvent -ListLog * | Where-Object { $PSItem.IsEnabled -eq $true -and $PSItem.RecordCount -gt 0 } | ForEach-Object -Process {
		Write-Verbose ('Performing the operation "ClearLog" on target "{0}"' -f $PSItem.LogName) -Verbose
		[Diagnostics.Eventing.Reader.EventLogSession]::GlobalSession.ClearLog($PSItem.LogName)
	} 2> $null
}

Function Remove-DuplicateDrivers {
	# Remove all outdated and duplicate drivers if the -Include parameter with the 'DuplicateDrivers' value is used.
	Write-Verbose "Compiling a list of any outdated and duplicate system drivers." -Verbose
	$AllDrivers = Get-WindowsDriver -Online -All | Where-Object -Property Driver -Like oem*inf | Select-Object -Property @{ Name = 'OriginalFileName'; Expression = { $PSItem.OriginalFileName | Split-Path -Leaf } } Driver ClassDescription ProviderName Date Version
	$DuplicateDrivers = $AllDrivers | Group-Object -Property OriginalFileName | Where-Object -Property Count -GT 1 | ForEach-Object -Process { $PSItem.Group | Sort-Object -Property Date -Descending | Select-Object -Skip 1 }
	If ($DuplicateDrivers) {
		$DuplicateDrivers | Out-GridView -Title 'Remove Duplicate Drivers' -PassThru | ForEach-Object -Process {
			$Driver = $PSItem.Driver.Trim()
			Write-Verbose ('Performing the action "Delete Driver" on target {0}' -f $Driver) -Verbose
			Start-Process -FilePath PNPUTIL -ArgumentList ('/Delete-Driver {0} /Force' -f $Driver) -WindowStyle Hidden -Wait
		}
	}
}

$PreReqCommandsToRun = @(
	Get-Service -Name wuauserv | Stop-Service -Force -Verbose -ErrorAction SilentlyContinue #Stops Windows Update so we can clean it out.
	powercfg -h off
	$EdgePackageName = Get-AppxPackage -Name Microsoft.MicrosoftEdge | Select-Object -ExpandProperty PackageFamilyName
)

## State which files or folders to clean up old files
$FoldersToClean = @(
	#Cleans up windows update service.
	"$Env:TEMP" ## Deletes the contents of the C:\Windows\Temp\ folder.
	(Join-Path -Path $Env:SystemRoot -ChildPath "SoftwareDistribution\Download")
	(Join-Path -Path $Env:SystemRoot -ChildPath "SoftwareDistribution\DataStore\Logs")
	(Join-Path -Path $Env:SystemRoot -ChildPath "Logs\WindowsUpdate")
	(Join-Path -Path $Env:ProgramData -ChildPath "USOShared\Logs")
	(Join-Path -Path $LocalAppData -ChildPath "Temp") ## Deletes all files and folders in user's Temp folder.
	(Join-Path -Path $LocalAppData -ChildPath "Microsoft\Windows\Temporary Internet Files") ## Remove all files and folders in user's Temporary Internet Files.
	(Join-Path -Path $GlobalAppData -ChildPath "Microsoft\Windows\Cookies")
	(Join-Path -Path $Env:HOMEDRIVE -ChildPath "inetpub\logs\LogFiles") ## Cleans IIS Logs
	(Join-Path -Path $($Env:USERPROFILE)$(($Env:Public).Replace('Public','*')) -ChildPath "AppData\Locallow\sun\java\deployment\cache") ## Remove all files and folders in user's Java Cache.
	(Join-Path -Path $LocalAppData -ChildPath "Mozilla\Firefox\Profiles\*.default\Cache") ## Remove all files and folders in user's Firefox Cache.
	(Join-Path -Path $LocalAppData -ChildPath "Google\Chrome\User Data\Default\Cache") ## Remove all files and folders in user's Chrome Cache.
	(Join-Path -Path $LocalAppData -ChildPath "Microsoft\Edge\User Data\Default\Cache") ## Remove all files and folders in user's Edge Cache.
	(Join-Path -Path $LocalAppData -ChildPath "Microsoft\Windows\Temporary Internet Files\Content.IE5") ## Internet Explorer temp files
	(Join-Path -Path $GlobalAppData -ChildPath "Macromedia\Flash Player\macromedia.com\support\flashplayer\sys") ## Flash temp files
	(Join-Path -Path ${env:ProgramFiles(x86)} -ChildPath "ITSPlatform\agentcore\download") ##Continuum downloader
	(Join-Path -Path ${env:ProgramFiles(x86)} -ChildPath "Common Files\Adobe\Reader\Temp") ##Adobe Installer
	(Join-Path -Path $RootAppData -ChildPath "Microsoft\Windows\WER")
	(Join-Path -Path $LocalAppData -ChildPath "Microsoft\Terminal Server Client\Cache")
	(Join-Path -Path $LocalAppData -ChildPath "Microsoft\Terminal Server Client\Cache")
	(Join-Path -Path $RootAppData -ChildPath "Microsoft\Terminal Server Client\Cache")
	(Join-Path -Path $Env:ProgramData -ChildPath "Microsoft\Windows\RetailDemo")
	(Join-Path -Path $LocalAppData -ChildPath "IsolatedStorage\")
	(Join-Path -Path $Env:SystemRoot -ChildPath "Logs\DISM")
	(Join-Path -Path $Env:SystemRoot -ChildPath "minidump")
	(Join-Path -Path $Env:SystemRoot -ChildPath Prefetch)
	(Join-Path -Path $Env:SystemRoot -ChildPath "security\logs")
	(Join-Path -Path $Env:SystemDrive -ChildPath swsetup)
	(Join-Path -Path $Env:SystemDrive -ChildPath swtools)
	(Join-Path -Path ${env:ProgramFiles(x86)} -ChildPath "Dropbox\Temp")
)

## State which files or folders to just delete
$PathsToDelete = @(
	(Join-Path -Path $Env:SystemRoot -ChildPath "MEMORY.dmp") ## Delete Windows memory dumps
	(Join-Path -Path $Env:SystemDrive -ChildPath "hiberfil.sys") #Removes Hibernate file
	## Remove folders related to windows update process
		(Join-Path -Path $Env:SystemDrive -ChildPath 'C:\$GetCurrent')
		(Join-Path -Path $Env:SystemDrive -ChildPath 'C:\$WINDOWS.~BT')
		(Join-Path -Path $Env:SystemDrive -ChildPath 'C:\$WINDOWS.~WS')
	@($(Get-Item -Path (Join-Path -Path $LocalAppData -ChildPath "Microsoft\Outlook\*.ost" | Where-Object -Property "LastWriteTime" -lt $(Get-Date).AddDays(-30)))) ## OST files that haven't been used in more then 30 days
	(Join-Path -Path $Env:SystemDrive -ChildPath "Windows.old") ##Old windows install
	(Join-Path -Path $Env:SystemRoot -ChildPath "debug\WIA\*.log")
	(Join-Path -Path $Env:SystemRoot -ChildPath "INF\*.log*")
	(Join-Path -Path $Env:SystemRoot -ChildPath "Logs\CBS\*Persist*")
	(Join-Path -Path $Env:SystemRoot -ChildPath "Logs\dosvc\*.*")
	(Join-Path -Path $Env:SystemRoot -ChildPath "Logs\MeasuredBoot\*.log")
	(Join-Path -Path $Env:SystemRoot -ChildPath "Logs\NetSetup\*.*")
	(Join-Path -Path $Env:SystemRoot -ChildPath "Logs\SIH\*.*")
	(Join-Path -Path $Env:SystemRoot -ChildPath "Logs\WindowsBackup\*.etl")
	(Join-Path -Path $Env:SystemRoot -ChildPath "Panther\UnattendGC\*.log")
	(Join-Path -Path $Env:SystemRoot -ChildPath Temp)
	(Join-Path -Path $Env:SystemRoot -ChildPath "WinSxS\ManifestCache\*")
	#(Join-Path -Path $Env:SystemRoot -ChildPath "*.log")
	(Join-Path -Path $Env:SystemRoot -ChildPath "*.dmp")
	(Join-Path -Path $Env:SystemDrive -ChildPath "*.dmp")
	(Join-Path -Path $Env:SystemDrive -ChildPath "File*.chk")
	(Join-Path -Path $Env:SystemDrive -ChildPath "Found.*\*.chk")
	(Join-Path -Path $Env:SystemDrive -ChildPath "LiveKernelReports\*.dmp")
	(Join-Path -Path $Env:HOMEDRIVE -ChildPath Intel)
	(Join-Path -Path $Env:HOMEDRIVE -ChildPath PerfLogs)
	#Chrome
	(Join-Path -Path $RootAppData -ChildPath "Google\Chrome\User Data\Default\Cache*\*")
	(Join-Path -Path $LocalAppData -ChildPath "Google\Chrome\User Data\Default\Cache*\*")
	(Join-Path -Path $RootAppData -ChildPath "Google\Chrome\User Data\Default\Cookies\*")
	(Join-Path -Path $LocalAppData -ChildPath "Google\Chrome\User Data\Default\Cookies\*")
	(Join-Path -Path $RootAppData -ChildPath "Google\Chrome\User Data\Default\Media Cache\*")
	(Join-Path -Path $LocalAppData -ChildPath "Google\Chrome\User Data\Default\Media Cache\*")
	(Join-Path -Path $RootAppData -ChildPath "Google\Chrome\User Data\Default\Cookies-Journal\*")
	(Join-Path -Path $LocalAppData -ChildPath "Google\Chrome\User Data\Default\Cookies-Journal\*")
	#FireFox
	(Join-Path -Path $RootAppData -ChildPath "Mozilla\Firefox\Profiles\*.default\Cache*\*")
	(Join-Path -Path $LocalAppData -ChildPath "Mozilla\Firefox\Profiles\*.default\Cache*\*")
	(Join-Path -Path $GlobalAppData -ChildPath "Mozilla\Firefox\Profiles\*.default\Cache*\*")
	(Join-Path -Path $RootAppData -ChildPath "Mozilla\Firefox\Profiles\*.default\jumpListCache\*")
	(Join-Path -Path $LocalAppData -ChildPath "Mozilla\Firefox\Profiles\*.default\jumpListCache\*")
	(Join-Path -Path $GlobalAppData -ChildPath "Mozilla\Firefox\Profiles\*.default\jumpListCache\*")
	(Join-Path -Path $RootAppData -ChildPath "Mozilla\Firefox\Profiles\*.default\thumbnails\*")
	(Join-Path -Path $LocalAppData -ChildPath "Mozilla\Firefox\Profiles\*.default\thumbnails\*")
	(Join-Path -Path $GlobalAppData -ChildPath "Mozilla\Firefox\Profiles\*.default\*sqlite*")
	(Join-Path -Path $RootAppData -ChildPath "Mozilla\Firefox\Profiles\*.default\*.log")
	(Join-Path -Path $LocalAppData -ChildPath "Mozilla\Firefox\Profiles\*.default\*.log")
	(Join-Path -Path $GlobalAppData -ChildPath "Mozilla\Firefox\Profiles\*.default\*.log")
	(Join-Path -Path $RootAppData -ChildPath "Mozilla\Firefox\Profiles\*.default\storage\*")
	(Join-Path -Path $LocalAppData -ChildPath "Mozilla\Firefox\Profiles\*.default\storage\*")
	(Join-Path -Path $GlobalAppData -ChildPath "Mozilla\Firefox\Profiles\*.default\storage\*")
	(Join-Path -Path $RootAppData -ChildPath "Mozilla\Firefox\Crash Reports\*")
	(Join-Path -Path $LocalAppData -ChildPath "Mozilla\Firefox\Crash Reports\*")
	(Join-Path -Path $GlobalAppData -ChildPath "Mozilla\Firefox\Crash Reports\*")
	(Join-Path -Path $RootAppData -ChildPath "Mozilla\Firefox\Profiles\*.default\startupCache\*")
	(Join-Path -Path $LocalAppData -ChildPath "Mozilla\Firefox\Profiles\*.default\startupCache\*")
	(Join-Path -Path $GlobalAppData -ChildPath "Mozilla\Firefox\Profiles\*.default\datareporting\*")
	#Internet Explorer
	(Join-Path -Path $LocalAppData -ChildPath "Microsoft\Internet Explorer\*.log")
	(Join-Path -Path $RootAppData -ChildPath "Microsoft\Internet Explorer\*.log")
	(Join-Path -Path $LocalAppData -ChildPath "Microsoft\Internet Explorer\*.txt")
	(Join-Path -Path $RootAppData -ChildPath "Microsoft\Internet Explorer\*.txt")
	(Join-Path -Path $LocalAppData -ChildPath "Microsoft\Internet Explorer\CacheStorage\*.*")
	(Join-Path -Path $RootAppData -ChildPath "Microsoft\Internet Explorer\CacheStorage\*.*")
	(Join-Path -Path $LocalAppData -ChildPath "Microsoft\Windows\INetCache\*")
	(Join-Path -Path $RootAppData -ChildPath "Microsoft\Windows\INetCache\*")
	(Join-Path -Path $LocalAppData -ChildPath "Microsoft\Windows\Temporary Internet Files\*")
	(Join-Path -Path $RootAppData -ChildPath "Microsoft\Windows\Temporary Internet Files\*")
	(Join-Path -Path $LocalAppData -ChildPath "Microsoft\Windows\IECompatCache\*")
	(Join-Path -Path $RootAppData -ChildPath "Microsoft\Windows\IECompatCache\*")
	(Join-Path -Path $LocalAppData -ChildPath "Microsoft\Windows\IECompatUaCache\*")
	(Join-Path -Path $RootAppData -ChildPath "Microsoft\Windows\IECompatUaCache\*")
	(Join-Path -Path $LocalAppData -ChildPath "Microsoft\Windows\IEDownloadHistory\*")
	(Join-Path -Path $RootAppData -ChildPath "Microsoft\Windows\IEDownloadHistory\*")
	(Join-Path -Path $LocalAppData -ChildPath "Microsoft\Windows\INetCookies\*")
	(Join-Path -Path $RootAppData -ChildPath "Microsoft\Windows\INetCookies\*")
	#Edge
	(Join-Path -Path $RootAppData -ChildPath "Packages\$EdgePackageName\AC\#!00*")
	(Join-Path -Path $LocalAppData -ChildPath "Packages\$EdgePackageName\AC\#!00*")
	(Join-Path -Path $RootAppData -ChildPath "Packages\$EdgePackageName\AC\Temp\*")
	(Join-Path -Path $LocalAppData -ChildPath "Packages\$EdgePackageName\AC\Temp\*")
	(Join-Path -Path $RootAppData -ChildPath "Packages\$EdgePackageName\AC\Microsoft\Cryptnet*Cache\*")
	(Join-Path -Path $LocalAppData -ChildPath "Packages\$EdgePackageName\AC\Microsoft\Cryptnet*Cache\*")
	(Join-Path -Path $RootAppData -ChildPath "Packages\$EdgePackageName\AC\MicrosoftEdge\Cookies\*")
	(Join-Path -Path $LocalAppData -ChildPath "Packages\$EdgePackageName\AC\MicrosoftEdge\Cookies\*")
	(Join-Path -Path $RootAppData -ChildPath "Packages\$EdgePackageName\AC\MicrosoftEdge\UrlBlock\*.tmp")
	(Join-Path -Path $LocalAppData -ChildPath "Packages\$EdgePackageName\AC\MicrosoftEdge\UrlBlock\*.tmp")
	(Join-Path -Path $RootAppData -ChildPath "Packages\$EdgePackageName\AC\MicrosoftEdge\User\Default\ImageStore\*")
	(Join-Path -Path $LocalAppData -ChildPath "Packages\$EdgePackageName\AC\MicrosoftEdge\User\Default\ImageStore\*")
	(Join-Path -Path $RootAppData -ChildPath "Packages\$EdgePackageName\AC\MicrosoftEdge\User\Default\Recovery\Active\*.dat")
	(Join-Path -Path $LocalAppData -ChildPath "Packages\$EdgePackageName\AC\MicrosoftEdge\User\Default\Recovery\Active\*.dat")
	(Join-Path -Path $RootAppData -ChildPath "Packages\$EdgePackageName\AC\MicrosoftEdge\User\Default\DataStore\Data\nouser1\*\DBStore\LogFiles\*")
	(Join-Path -Path $LocalAppData -ChildPath "Packages\$EdgePackageName\AC\MicrosoftEdge\User\Default\DataStore\Data\nouser1\*\DBStore\LogFiles\*")
	(Join-Path -Path $RootAppData -ChildPath "Packages\$EdgePackageName\AC\MicrosoftEdge\User\Default\DataStore\Data\nouser1\*\Favorites\*.ico")
	(Join-Path -Path $LocalAppData -ChildPath "Packages\$EdgePackageName\AC\MicrosoftEdge\User\Default\DataStore\Data\nouser1\*\Favorites\*.ico")
	(Join-Path -Path $RootAppData -ChildPath "Packages\$EdgePackageName\AppData\User\Default\Indexed DB\*")
	(Join-Path -Path $LocalAppData -ChildPath "Packages\$EdgePackageName\AppData\User\Default\Indexed DB\*")
	(Join-Path -Path $RootAppData -ChildPath "Packages\$EdgePackageName\TempState\*")
	(Join-Path -Path $LocalAppData -ChildPath "Packages\$EdgePackageName\TempState\*")
	(Join-Path -Path $RootAppData -ChildPath "Packages\$EdgePackageName\LocalState\Favicons\PushNotificationGrouping\*")
	(Join-Path -Path $LocalAppData -ChildPath "Packages\$EdgePackageName\LocalState\Favicons\PushNotificationGrouping\*")
	(Join-Path -Path $LocalAppData -ChildPath "Microsoft\Edge\User Data\*.pma")
	(Join-Path -Path $LocalAppData -ChildPath "Microsoft\Edge\User Data\BrowserMetrics\*.pma")
	(Join-Path -Path $LocalAppData -ChildPath "Microsoft\Edge\User Data\CrashPad\metadata")
	(Join-Path -Path $LocalAppData -ChildPath "Microsoft\Edge\User Data\Profile *\BudgetDatabase")
	(Join-Path -Path $LocalAppData -ChildPath "Microsoft\Edge\User Data\Profile *\Cache\*")
	(Join-Path -Path $LocalAppData -ChildPath "Microsoft\Edge\User Data\Profile *\Code Cache\js\*")
	(Join-Path -Path $LocalAppData -ChildPath "Microsoft\Edge\User Data\Profile *\Code Cache\wasm\*")
	(Join-Path -Path $LocalAppData -ChildPath "Microsoft\Edge\User Data\Profile *\Cookies")
	(Join-Path -Path $LocalAppData -ChildPath "Microsoft\Edge\User Data\Profile *\data_reduction_proxy_leveldb\*")
	(Join-Path -Path $LocalAppData -ChildPath "Microsoft\Edge\User Data\Profile *\Extension State\*")
	(Join-Path -Path $LocalAppData -ChildPath "Microsoft\Edge\User Data\Profile *\Favicons\*")
	(Join-Path -Path $LocalAppData -ChildPath "Microsoft\Edge\User Data\Profile *\Feature Engagement Package\AvailabilityDB\*")
	(Join-Path -Path $LocalAppData -ChildPath "Microsoft\Edge\User Data\Profile *\Feature Engagement Package\EventDB\*")
	(Join-Path -Path $LocalAppData -ChildPath "Microsoft\Edge\User Data\Profile *\File System\000\*")
	(Join-Path -Path $LocalAppData -ChildPath "Microsoft\Edge\User Data\Profile *\File System\Origins\*")
	(Join-Path -Path $LocalAppData -ChildPath "Microsoft\Edge\User Data\Profile *\IndexedDB\*")
	(Join-Path -Path $LocalAppData -ChildPath "Microsoft\Edge\User Data\Profile *\Service Worker\CacheStorage\*")
	(Join-Path -Path $LocalAppData -ChildPath "Microsoft\Edge\User Data\Profile *\Service Worker\Database\*")
	(Join-Path -Path $LocalAppData -ChildPath "Microsoft\Edge\User Data\Profile *\Service Worker\ScriptCache\*")
	(Join-Path -Path $LocalAppData -ChildPath "Microsoft\Edge\User Data\Profile *\Current Tabs")
	(Join-Path -Path $LocalAppData -ChildPath "Microsoft\Edge\User Data\Profile *\Last Tabs")
	(Join-Path -Path $LocalAppData -ChildPath "Microsoft\Edge\User Data\Profile *\History")
	(Join-Path -Path $LocalAppData -ChildPath "Microsoft\Edge\User Data\Profile *\History Provider Cache")
	(Join-Path -Path $LocalAppData -ChildPath "Microsoft\Edge\User Data\Profile *\History-journal")
	(Join-Path -Path $LocalAppData -ChildPath "Microsoft\Edge\User Data\Profile *\Network Action Predictor")
	(Join-Path -Path $LocalAppData -ChildPath "Microsoft\Edge\User Data\Profile *\Top Sites")
	(Join-Path -Path $LocalAppData -ChildPath "Microsoft\Edge\User Data\Profile *\Visited Links")
	(Join-Path -Path $LocalAppData -ChildPath "Microsoft\Edge\User Data\Profile *\Login Data")
	(Join-Path -Path $LocalAppData -ChildPath "Microsoft\Edge\User Data\Profile *\CURRENT")
	(Join-Path -Path $LocalAppData -ChildPath "Microsoft\Edge\User Data\Profile *\LOCK")
	(Join-Path -Path $LocalAppData -ChildPath "Microsoft\Edge\User Data\Profile *\MANIFEST-*")
	(Join-Path -Path $LocalAppData -ChildPath "Microsoft\Edge\User Data\Profile *\*.log")
	(Join-Path -Path $LocalAppData -ChildPath "Microsoft\Edge\User Data\Profile *\*.log")
	(Join-Path -Path $LocalAppData -ChildPath "Microsoft\Edge\User Data\Profile *\*\*.log")
	(Join-Path -Path $LocalAppData -ChildPath "Microsoft\Edge\User Data\Profile *\*\*log*")
	(Join-Path -Path $LocalAppData -ChildPath "Microsoft\Edge\User Data\Profile *\*\MANIFEST-*")
	(Join-Path -Path $LocalAppData -ChildPath "Microsoft\Edge\User Data\Profile *\Shortcuts")
	(Join-Path -Path $LocalAppData -ChildPath "Microsoft\Edge\User Data\Profile *\QuotaManager")
	(Join-Path -Path $LocalAppData -ChildPath "Microsoft\Edge\User Data\Profile *\Web Data")
	(Join-Path -Path $LocalAppData -ChildPath "Microsoft\Edge\User Data\Profile *\Current Session")
	(Join-Path -Path $LocalAppData -ChildPath "Microsoft\Edge\User Data\Profile *\Last Session")
	(Join-Path -Path $LocalAppData -ChildPath "Microsoft\Edge\User Data\Profile *\Session Storage\*")
	(Join-Path -Path $LocalAppData -ChildPath "Microsoft\Edge\User Data\Profile *\Site Characteristics Database\*")
	(Join-Path -Path $LocalAppData -ChildPath "Microsoft\Edge\User Data\Profile *\Sync Data\LevelDB\*")
	(Join-Path -Path $Env:ProgramData -ChildPath "Microsoft\EdgeUpdate\Log\*")
	(Join-Path -Path ${Env:ProgramFiles(x86)} -ChildPath "Microsoft\Edge\Application\SetupMetrics\*.pma")
	(Join-Path -Path ${Env:ProgramFiles(x86)} -ChildPath "Microsoft\EdgeUpdate\Download\*")
)

#Show what we're working with
Write-Host "`nBefore Clean-up:";($PreClean | Format-Table | Out-String).Trim()
Start-Sleep -Seconds 10

#Clean up folders
$FoldersToClean | %{
	#Write-Host "$_ :"
	#@(Get-Item $_).Count
	If (@(Get-Item $_)){
		ForEach ($SubItem in $_) {
			Get-Item $_ | ForEach-Object {
				#$_.FullName
				Remove-StaleObjects -targetDirectory $($_.FullName) -DaysOld $DaysToDelete
			}
		}
	}
}

#Delete the folders / files
$PathsToDelete | %{
	If (@(Get-Item $_)){
		ForEach ($SubItem in $_) {
			Get-Item $_ | ForEach-Object {
				#$_.FullName
				Remove-PathForcefully -Path $($_.FullName)
			}
		}
	}
}

$CommandsToRun = @(
	Start-ScheduledTask -TaskPath "\Microsoft\Windows\Servicing" -TaskName "StartComponentCleanup" -Verbose:$false ## Run the StartComponentCleanup task
	Write-Host "Reclaim space from .NET Native Images" ; Get-Item "$Env:windir\Microsoft.NET\Framework\*\ngen.exe" | % { & $($_.FullName) update} ## Reclaim space from .NET Native Images
	Write-Host "Emptying Recycle Bin" ;Clear-RecycleBin -Force ## Empties Recycle Bin
	## Reduce the size of the WinSxS folder
	Write-Host "Reducing the size of the WinSxS folder" 
		Dism.exe /online /Cleanup-Image /StartComponentCleanup
		Dism.exe /online /Cleanup-Image /StartComponentCleanup /ResetBase
		Dism.exe /online /Cleanup-Image /SPSuperseded
		DISM.exe /Online /Set-ReservedStorageState /State:Disabled
	Write-Host "Cleaning up the WMI Repository" ; Winmgmt /salvagerepository ## Cleans up WMI Repository
	Write-Host "Erasing IE Temp Data" ;Start-Process -FilePath rundll32.exe -ArgumentList 'inetcpl.cpl,ClearMyTracksByProcess 4351' -Wait -NoNewWindow ## erase Internet Explorer temp data
	Write-Host "Removing Restore Points" ;Remove-WindowsRestorePoints
	Write-Host "Clearing Event Logs" ;Remove-EventLogs
	Write-Host "Removing Duplicate Drivers" ;Remove-DuplicateDrivers
	Invoke-WindowsCleanMgr
)

$PostReqCommandsToRun = @(
	Get-Service -Name wuauserv | Start-Service -Verbose #Starts Windows Update.
)


$PostClean = Get-CimInstance -ClassName Win32_LogicalDisk | Where-Object -Property DriveType -EQ 3 | Where-Object -Property DeviceID -EQ $Env:SystemDrive | Select-Object -Property @{ Name = 'Drive'; Expression = { ($PSItem.DeviceID) } },
	@{ Name = 'Size (GB)'; Expression = { '{0:N1}' -f ($PSItem.Size / 1GB) } },
	@{ Name = 'FreeSpace (GB)'; Expression = { '{0:N1}' -f ($PSItem.Freespace / 1GB) } },
	@{ Name = 'PercentFree'; Expression = { '{0:P1}' -f ($PSItem.FreeSpace / $PSItem.Size) } }

## Sends some before and after info for ticketing purposes

Hostname ; Get-Date | Select-Object DateTime
Write-Host "`nBefore Clean-up:";($PreClean | Format-Table | Out-String).Trim()
Write-Host "`nAfter Clean-up:";($PostClean | Format-Table | Out-String).Trim()
Write-Host "Freed up $($PostClean.'FreeSpace (GB)' - $PreClean.'FreeSpace (GB)') GB. $((($PostClean.PercentFree).Replace('%','')) - (($PreClean.PercentFree).Replace('%',''))) %"
## Completed Successfully!