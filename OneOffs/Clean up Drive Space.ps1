$ErrorActionPreference = "silentlycontinue"
#[System.Net.ServicePointManager]::SecurityProtocol = 3072 -bor 768 -bor 192 ; Invoke-RestMethod 'https://raw.githubusercontent.com/AmbitionsTechnologyGroup/ATG-PS-Functions/master/OneOffs/Clean%20up%20Drive%20Space.ps1' | Invoke-Expression
#Clean up Drive Space
#Enable SSL/TLS
Try {
	[System.Net.ServicePointManager]::SecurityProtocol = 3072 -bor 768 -bor 192
} Catch {
	Write-Output 'Unable to set PowerShell to use TLS 1.2 and TLS 1.1 due to old .NET Framework installed. If you see underlying connection closed or trust errors, you may need to upgrade to .NET Framework 4.5+ and PowerShell v3+.'
}

#Load Functions without using disk space
Invoke-RestMethod "https://raw.githubusercontent.com/AmbitionsTechnologyGroup/ATG-PS-Functions/master/Functions/ATG-PS-Remove.txt" | Invoke-Expression

$VerbosePreference = "SilentlyContinue"
$DaysToDelete = 7
$ErrorActionPreference = "SilentlyContinue"

# Assign the pre-cleanup storage state to a variable.
$PreClean = Get-CimInstance -ClassName Win32_LogicalDisk | Where-Object -Property DriveType -EQ 3 | Where-Object -Property DeviceID -EQ $Env:SystemDrive | Select-Object -Property @{ Name = 'Drive'; Expression = { ($PSItem.DeviceID) } },
	@{ Name = 'Size (GB)'; Expression = { '{0:N1}' -f ($PSItem.Size / 1GB) } },
	@{ Name = 'FreeSpace (GB)'; Expression = { '{0:N1}' -f ($PSItem.Freespace / 1GB) } },
	@{ Name = 'PercentFree'; Expression = { '{0:P1}' -f ($PSItem.FreeSpace / $PSItem.Size) } }

#Show what we're working with
Write-Host "`nBefore Clean-up:`n$(($PreClean | Format-Table | Out-String).Trim())"
Write-Host $((Get-Date).DateTime)
Write-Host $($env:computername)
Start-Sleep -Seconds 10

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
	ForEach ($VC in $VolCaches) {New-ItemProperty -Path "$($VC.PSPath)" -Name $StateFlags -Value 1 -Type DWORD -Force | Out-Null}
	ForEach ($Location in $Locations) {Set-ItemProperty -Path $($Base + $Location) -Name $SageSet -Type DWORD -Value 2 -ea SilentlyContinue | Out-Null}
	$Argss = "/sagerun:$([string]([int]$SageSet.Substring($SageSet.Length - 4)))"
	function Watch-CleanMgr {
		$prevTicks = 0
		$sameTickCount = 0
		$WaitInterval = 30
		$SameTickMax = 8
		$process = Get-Process cleanmgr -ErrorAction SilentlyContinue

		if ($null -eq $process) {
			Write-Host "cleanmgr.exe is not running."
			return $false
		}

		for ($i = 0; $i -lt 3; $i++) {
			Start-Sleep -Seconds $WaitInterval
			
			$currentTicks = (Get-Process cleanmgr).TotalProcessorTime.Ticks
			Write-Host "Checking on cleanmgr CPU usage:$currentTicks"
			if ($currentTicks -eq $prevTicks) {
				$sameTickCount++
				Write-Host "Cleanmgr hasn't used the CPU in the last $WaitInterval seconds. If it does this $($SameTickMax - $sameTickCount) more times, we'll move on."
				if ($sameTickCount -eq $SameTickMax) { #CPU count hasn't changed for 2 minutes (30 seconds * 4)
					Write-Host "cleanmgr.exe appears to be inactive. Terminating process."
					Stop-Process -Name cleanmgr -Force
					return $true
				}
			} else {
				$sameTickCount = 0
			}

			$prevTicks = $currentTicks
		}

		return $false
	}
	Write-Host "Starting cleanmgr.exe /verylowdisk for a first attempt."
	Start-Process "$env:SystemRoot\System32\cleanmgr.exe" -ArgumentList "/verylowdisk /d c" -WindowStyle Hidden
	$terminated = Watch-CleanMgr

	# Second attempt if the first one was terminated
	if ($terminated) {
		Write-Host "Restarting cleanmgr.exe for a second attempt."
		Start-Process "$env:SystemRoot\System32\cleanmgr.exe" -ArgumentList "/verylowdisk /d c" -WindowStyle Hidden
		Watch-CleanMgr
	}
	
	Write-Host "Starting cleanmgr.exe $Argss for a first attempt."
	Start-Process "$env:SystemRoot\System32\cleanmgr.exe" -ArgumentList $Argss -WindowStyle Hidden
	$terminated = Watch-CleanMgr

	# Second attempt if the first one was terminated
	if ($terminated) {
		Write-Host "Restarting cleanmgr.exe $Argss for a second attempt."
		Start-Process "$env:SystemRoot\System32\cleanmgr.exe" -ArgumentList $Argss -WindowStyle Hidden
		Watch-CleanMgr
	}
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
			#Write-Verbose ('Performing the action "Delete Driver" on target {0}' -f $Driver) -Verbose
			Start-Process -FilePath PNPUTIL -ArgumentList ('/Delete-Driver {0} /Force' -f $Driver) -WindowStyle Hidden -Wait
		}
	}
}

Function Remove-StaleProfiles {
	$thresholdDays = 365 #Days
	Write-Host "Checking for stale profiles to clean up"
	# Get a list of user profiles
	$profiles = Get-CimInstance -ClassName Win32_UserProfile | Where-Object{$_.CreationTime -lt (get-date).adddays(-$thresholdDays)} | Where-Object{$_.Loaded -eq $False} | Where-Object { $_.LocalPath -notmatch 'atg|Remote Support|admin' }
	If ($profiles) {
		foreach ($profile in $profiles) {
			
			$localPath = $profile.LocalPath
			Write-Host "Assessing $localpath"
			$localPath.FullName
			$directories = Get-ChildItem -Path $localPath -Directory
			if ($directories.Count -gt 0) {
			# Find the most recently modified directory
				$mostRecentDir = $directories | Sort-Object LastWriteTime -Descending | Select-Object -First 1
				# Calculate the age in days
				$ageInDays = (Get-Date) - $mostRecentDir.LastWriteTime
				Write-Host "$($mostRecentDir.FullName) was most recently updated $([int]$ageInDays.TotalDays) days ago."
				If ($ageInDays.TotalDays -gt 360) {
					Write-Host "Deleting $localPath (Last modified: $($mostRecentDir.LastWriteTime))"
					Write-Host "Deleting inactive profile: $($profile.LocalPath)"
					Write-Host "$profile"
					Write-Host $lastWriteTime
					Remove-CimInstance $profile -Verbose -ConfInvoke-RestMethod:$false 
					# Replace 'S-1-5-21-2552263123-1652881823-690255818-2139' with the actual SID you want to delete
					$targetSID = $profile.SID

					# Construct the registry path for the user profile
					$registryPath = "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\ProfileList\$targetSID"

					# Delete the registry key
					Remove-Item -Path $registryPath -Force
					Write-Host "User profile with SID $targetSID has been deleted from the registry."
					# Delete the Users Path
					Remove-PathForcefully -Path $Profile.LocalPath
				}
			}
		}
	} Else {
		Write-Host "No profiles older then $thresholdDays found."
	}
}

#$PreReqCommandsToRun = @(
	Write-Host "Reclaim space from .NET Native Images" ; Get-Item "$Env:windir\Microsoft.NET\Framework\*\ngen.exe" -Force | ForEach-Object { & $($_.FullName) update} | Out-Null## Reclaim space from .NET Native Images	
	Get-Service -Name wuauserv | Stop-Service -Force -Verbose -ErrorAction SilentlyContinue #Stops Windows Update so we can clean it out.
	powercfg -h off
	$EdgePackageName = Get-AppxPackage -Name Microsoft.MicrosoftEdge | Select-Object -ExpandProperty PackageFamilyName
	If ((Get-CimInstance -ClassName Win32_OperatingSystem | Select-Object -ExpandProperty Caption) -notlike "Microsoft Windows Server*") { #Let's not remove profiles on a server by default.
		Remove-StaleProfiles
	}
#)

## State which files or folders to clean up old files
$FoldersToClean = @(
	#Cleans up windows update service.
	"$Env:TEMP" ## Deletes the contents of the C:\Windows\Temp\ folder.
	(Join-Path -Path $Env:SystemRoot -ChildPath "SoftwareDistribution\Download")
	(Join-Path -Path $Env:SystemRoot -ChildPath "SoftwareDistribution\DataStore\Logs")
	(Join-Path -Path $Env:SystemRoot -ChildPath "Logs\WindowsUpdate")
	(Join-Path -Path $Env:ProgramData -ChildPath "USOShared\Logs")
	(Join-Path -Path $LocalAppData -ChildPath "Temp") ## Deletes all files and folders in user's Temp folder.
	(Join-Path -Path $Env:SystemDrive -ChildPath "Temp")
	(Join-Path -Path $LocalAppData -ChildPath "Microsoft\Windows\Temporary Internet Files") ## Remove all files and folders in user's Temporary Internet Files.
	(Join-Path -Path $GlobalAppData -ChildPath "Microsoft\Windows\Cookies")
	(Join-Path -Path $Env:HOMEDRIVE -ChildPath "inetpub\logs\LogFiles") ## Cleans IIS Logs
	(Join-Path -Path $(($Env:Public).Replace('Public','*')) -ChildPath "AppData\Locallow\sun\java\deployment\cache") ## Remove all files and folders in user's Java Cache.
	(Join-Path -Path $LocalAppData -ChildPath "Mozilla\Firefox\Profiles\*.default\Cache") ## Remove all files and folders in user's Firefox Cache.
	(Join-Path -Path $LocalAppData -ChildPath "Google\Chrome\User Data\Default\Cache") ## Remove all files and folders in user's Chrome Cache.
	(Join-Path -Path $LocalAppData -ChildPath "Microsoft\Edge\User Data\Default\Cache") ## Remove all files and folders in user's Edge Cache.
	(Join-Path -Path $LocalAppData -ChildPath "Microsoft\Windows\Temporary Internet Files\Content.IE5") ## Internet Explorer temp files
	(Join-Path -Path $GlobalAppData -ChildPath "Macromedia\Flash Player\macromedia.com\support\flashplayer\sys") ## Flash temp files
	(Join-Path -Path ${env:ProgramFiles(x86)} -ChildPath "ITSPlatform\agentcore\download") ##Continuum downloader
	(Join-Path -Path ${env:ProgramFiles(x86)} -ChildPath "Common Files\Adobe\Reader\Temp") ##Adobe Installer
	(Join-Path -Path $env:ProgramData -ChildPath "Adobe\ARM") ## https://community.adobe.com/t5/acrobat-reader-discussions/can-arm-folders-be-deleted/td-p/5141447
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
	(Join-Path -Path $Env:SystemRoot -ChildPath "SysWOW64\config\systemprofile\AppData\Local\Microsoft\Windows\INetCache\IE")
)

## State which files or folders to just delete
$PathsToDelete = @(
	(Join-Path -Path $Env:SystemRoot -ChildPath "MEMORY.dmp") ## Delete Windows memory dumps
	(Join-Path -Path $Env:SystemDrive -ChildPath "hiberfil.sys") #Removes Hibernate file
	## Remove folders related to windows update process
		(Join-Path -Path $Env:SystemDrive -ChildPath '$GetCurrent')
		(Join-Path -Path $Env:SystemDrive -ChildPath '$WINDOWS.~BT')
		(Join-Path -Path $Env:SystemDrive -ChildPath '$WINDOWS.~WS')
		(Join-Path -Path $Env:SystemDrive -ChildPath '$WinREAgent')
	@($(Get-Item -Path (Join-Path -Path $LocalAppData -ChildPath "Microsoft\Outlook\*.ost")-Force) | Where-Object -Property "LastWriteTime" -lt $((Get-Date).AddDays(-30))) ## OST files that haven't been used in more then 30 days
	(Join-Path -Path $Env:SystemDrive -ChildPath "Windows.old") ##Old windows install
	(Join-Path -Path $Env:SystemDrive -ChildPath "Ambitions\NiniteDownloads")
	(Join-Path -Path $Env:SystemDrive -ChildPath "adobeTemp")
	(Join-Path -Path $Env:SystemRoot -ChildPath "debug\WIA\*.log")
	(Join-Path -Path $Env:SystemRoot -ChildPath "INF\*.log*")
	(Join-Path -Path $Env:SystemRoot -ChildPath "Logs\CBS\*Persist*")
	(Join-Path -Path $Env:SystemRoot -ChildPath "Logs\dosvc\*.*")
	(Join-Path -Path $Env:SystemRoot -ChildPath "Logs\MeasuredBoot\*.log")
	(Join-Path -Path $Env:SystemRoot -ChildPath "Logs\NetSetup\*.*")
	(Join-Path -Path $Env:SystemRoot -ChildPath "Logs\SIH\*.*")
	(Join-Path -Path $Env:SystemRoot -ChildPath "Logs\WindowsBackup\*.etl")
	(Join-Path -Path $Env:SystemRoot -ChildPath "Panther\UnattendGC\*.log")
	(Join-Path -Path $Env:SystemDrive -ChildPath "TMP")
	(Join-Path -Path $Env:SystemDrive -ChildPath "TempPath")
	(Join-Path -Path $Env:SystemDrive -ChildPath "OneDriveTemp")
	(Join-Path -Path $Env:SystemDrive -ChildPath "MSOCache")
	(Join-Path -Path $Env:SystemDrive -ChildPath "Windows10Upgrade")
	(Join-Path -Path $Env:SystemRoot -ChildPath "WinSxS\ManifestCache\*")
	#(Join-Path -Path $Env:SystemRoot -ChildPath "*.log")
	(Join-Path -Path $Env:SystemRoot -ChildPath "*.dmp")
	(Join-Path -Path $Env:SystemDrive -ChildPath "*.dmp")
	(Join-Path -Path $Env:SystemDrive -ChildPath "File*.chk")
	(Join-Path -Path $Env:SystemDrive -ChildPath "Found.*\*.chk")
	(Join-Path -Path $Env:SystemDrive -ChildPath "LiveKernelReports\*.dmp")
	(Join-Path -Path $Env:HOMEDRIVE -ChildPath "Intel")
	(Join-Path -Path $Env:HOMEDRIVE -ChildPath "PerfLogs")
	#Chrome
	(Join-Path -Path $LocalAppData -ChildPath "Google\Chrome\User Data\*.pma")
	(Join-Path -Path $LocalAppData -ChildPath "Google\Chrome\User Data\BrowserMetrics\*.pma")
	(Join-Path -Path $LocalAppData -ChildPath "Google\Chrome\User Data\CrashPad\metadata")
	(Join-Path -Path $LocalAppData -ChildPath "Google\Chrome\User Data\Default\BudgetDatabase")
	(Join-Path -Path $LocalAppData -ChildPath "Google\Chrome\User Data\Default\Cache\*")
	(Join-Path -Path $LocalAppData -ChildPath "Google\Chrome\User Data\Default\Code Cache\js\*")
	(Join-Path -Path $LocalAppData -ChildPath "Google\Chrome\User Data\Default\Code Cache\wasm\*")
	(Join-Path -Path $LocalAppData -ChildPath "Google\Chrome\User Data\Default\Cookies")
	(Join-Path -Path $LocalAppData -ChildPath "Google\Chrome\User Data\Default\data_reduction_proxy_leveldb\*")
	(Join-Path -Path $LocalAppData -ChildPath "Google\Chrome\User Data\Default\Extension State\*")
	(Join-Path -Path $LocalAppData -ChildPath "Google\Chrome\User Data\Default\Favicons\*")
	(Join-Path -Path $LocalAppData -ChildPath "Google\Chrome\User Data\Default\Feature Engagement Package\AvailabilityDB\*")
	(Join-Path -Path $LocalAppData -ChildPath "Google\Chrome\User Data\Default\Feature Engagement Package\EventDB\*")
	(Join-Path -Path $LocalAppData -ChildPath "Google\Chrome\User Data\Default\File System\000\*")
	(Join-Path -Path $LocalAppData -ChildPath "Google\Chrome\User Data\Default\File System\Origins\*")
	(Join-Path -Path $LocalAppData -ChildPath "Google\Chrome\User Data\Default\IndexedDB\*")
	(Join-Path -Path $LocalAppData -ChildPath "Google\Chrome\User Data\Default\Service Worker\CacheStorage\*")
	(Join-Path -Path $LocalAppData -ChildPath "Google\Chrome\User Data\Default\Service Worker\Database\*")
	(Join-Path -Path $LocalAppData -ChildPath "Google\Chrome\User Data\Default\Service Worker\ScriptCache\*")
	(Join-Path -Path $LocalAppData -ChildPath "Google\Chrome\User Data\Default\Current Tabs")
	(Join-Path -Path $LocalAppData -ChildPath "Google\Chrome\User Data\Default\Last Tabs")
	(Join-Path -Path $LocalAppData -ChildPath "Google\Chrome\User Data\Default\History")
	(Join-Path -Path $LocalAppData -ChildPath "Google\Chrome\User Data\Default\History Provider Cache")
	(Join-Path -Path $LocalAppData -ChildPath "Google\Chrome\User Data\Default\History-journal")
	(Join-Path -Path $LocalAppData -ChildPath "Google\Chrome\User Data\Default\Network Action Predictor")
	(Join-Path -Path $LocalAppData -ChildPath "Google\Chrome\User Data\Default\Top Sites")
	(Join-Path -Path $LocalAppData -ChildPath "Google\Chrome\User Data\Default\Visited Links")
	(Join-Path -Path $LocalAppData -ChildPath "Google\Chrome\User Data\Default\Login Data")
	(Join-Path -Path $LocalAppData -ChildPath "Google\Chrome\User Data\Default\CURRENT")
	(Join-Path -Path $LocalAppData -ChildPath "Google\Chrome\User Data\Default\LOCK")
	(Join-Path -Path $LocalAppData -ChildPath "Google\Chrome\User Data\Default\MANIFEST-*")
	(Join-Path -Path $LocalAppData -ChildPath "Google\Chrome\User Data\Default\*.log")
	(Join-Path -Path $LocalAppData -ChildPath "Google\Chrome\User Data\Default\*.log")
	(Join-Path -Path $LocalAppData -ChildPath "Google\Chrome\User Data\Default\*\*.log")
	(Join-Path -Path $LocalAppData -ChildPath "Google\Chrome\User Data\Default\*\*log*")
	(Join-Path -Path $LocalAppData -ChildPath "Google\Chrome\User Data\Default\*\MANIFEST-*")
	(Join-Path -Path $LocalAppData -ChildPath "Google\Chrome\User Data\Default\Shortcuts")
	(Join-Path -Path $LocalAppData -ChildPath "Google\Chrome\User Data\Default\QuotaManager")
	(Join-Path -Path $LocalAppData -ChildPath "Google\Chrome\User Data\Default\Web Data")
	(Join-Path -Path $LocalAppData -ChildPath "Google\Chrome\User Data\Default\Current Session")
	(Join-Path -Path $LocalAppData -ChildPath "Google\Chrome\User Data\Default\Last Session")
	(Join-Path -Path $LocalAppData -ChildPath "Google\Chrome\User Data\Default\Session Storage\*")
	(Join-Path -Path $LocalAppData -ChildPath "Google\Chrome\User Data\Default\Site Characteristics Database\*")
	(Join-Path -Path $LocalAppData -ChildPath "Google\Chrome\User Data\Default\Sync Data\LevelDB\*")
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
	(Join-Path -Path $Env:SystemRoot -ChildPath "SysWOW64\config\systemprofile\AppData\Local\Microsoft\Windows\INetCache\IE\*")
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
	#Quickbooks
	(Join-Path -Path $Env:ProgramData "Intuit\QuickBooks*\Components\DownloadQB*")
	(Join-Path -Path $Env:ProgramData "Intuit\QuickBooks*\Components\QBUpdateCache")
)

$FoldersToDeDuplicate = @(
	(Join-Path -Path $($(($Env:Public).Replace('Public','*'))) -ChildPath "Downloads")
)

#Clean up folders
$FoldersToClean | ForEach-Object {
	If (@(Get-Item $_ -Force)){
		ForEach ($SubItem in @($_)) {
			If (Get-Item $SubItem -Force -ErrorAction SilentlyContinue) {
				Try {
					Get-Item $SubItem -Force -ErrorAction SilentlyContinue | ForEach-Object {
						Remove-StaleObjects -targetDirectory $($_.FullName) -DaysOld $DaysToDelete
				}
				} Catch {
					Write-Host "Not worth it for $SubItem"
				}
			}
		}
	}
}

#Delete the folders / files
$PathsToDelete | ForEach-Object {
	If (@(Get-Item $_ -Force)){
		ForEach ($SubItem in @($_)) {
			If (Get-Item $SubItem -Force -ErrorAction SilentlyContinue) {
				Try {
					Get-Item $SubItem -Force -ErrorAction SilentlyContinue | ForEach-Object {
						Remove-PathForcefully -Path $($_.FullName)
				}
				} Catch {
					Write-Host "Not worth it for $SubItem"
				}
			}
		}
	}
}

#DeDuplicate files in these folders
$FoldersToDeDuplicate | ForEach-Object {
	If (@(Get-Item $_ -Force)){
		ForEach ($SubItem in @($_)) {
			If (Get-Item $SubItem -Force -ErrorAction SilentlyContinue) {
				Write-Host $SubItem
				Try {
					Get-Item $SubItem -Force -ErrorAction SilentlyContinue | ForEach-Object {
						Write-Host "Searching $($_.FullName) for duplicate files"
						Remove-DuplicateFiles -Path $($_.FullName)
						Write-Host
				}
				} Catch {
					Write-Host "Not worth it for $SubItem"
				}
			}
		}
	}
}

#$CommandsToRun = @(
	Start-ScheduledTask -TaskPath "\Microsoft\Windows\Servicing" -TaskName "StartComponentCleanup" -Verbose:$false ## Run the StartComponentCleanup task
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
#)

#$PostReqCommandsToRun = @(
	Get-Service -Name wuauserv | Start-Service -Verbose #Starts Windows Update.
	If ((Get-Service -Name Umbrella_RC -ErrorAction SilentlyContinue) -or (Get-Service -Name csc_umbrellaagent -ErrorAction SilentlyContinue)) {
		Install-UmbrellaDns
	}
#)


$PostClean = Get-CimInstance -ClassName Win32_LogicalDisk | Where-Object -Property DriveType -EQ 3 | Where-Object -Property DeviceID -EQ $Env:SystemDrive | Select-Object -Property @{ Name = 'Drive'; Expression = { ($PSItem.DeviceID) } },
	@{ Name = 'Size (GB)'; Expression = { '{0:N1}' -f ($PSItem.Size / 1GB) } },
	@{ Name = 'FreeSpace (GB)'; Expression = { '{0:N1}' -f ($PSItem.Freespace / 1GB) } },
	@{ Name = 'PercentFree'; Expression = { '{0:P1}' -f ($PSItem.FreeSpace / $PSItem.Size) } }

## Sends some before and after info for ticketing purposes
#$Wrapup = @(
	Write-Host "`nBefore Clean-up:`n$(($PreClean | Format-Table | Out-String).Trim())"
	Write-Host "`nAfter Clean-up:`n$(($PostClean | Format-Table | Out-String).Trim())"
	Write-Host -ForegroundColor Green "`nFreed up :$($PostClean.'FreeSpace (GB)' - $PreClean.'FreeSpace (GB)') GB  ($((($PostClean.PercentFree).Replace('%','')) - (($PreClean.PercentFree).Replace('%',''))) %)"
	## Completed Successfully!
	Write-Host $((Get-Date).DateTime)
	Write-Host $($env:computername)
#)