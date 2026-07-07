Function Uninstall-Application {
	<#
	.SYNOPSIS
		Uninstall Application
	.DESCRIPTION
		Allows to Uninstall Application from system
	.EXAMPLE
		Uninstall-Application -AppToUninstall "Microsoft Office 2010 Primary Interop Assemblies"
	.PARAMETER AppToUninstall
		Application name (Or application name format)
	#>

	param(

	  [Parameter(Mandatory=$False, ValueFromPipeline=$True,
	  ValueFromPipelineByPropertyName=$True, HelpMessage='Enter the Application to uninstall.')]
	  [Alias('Application')]
	  [string] $AppToUninstall

	)

	Write-Host '[Scanning All App sources]'
	Write-Host '--[Scanning Wmi Repository]'
	$Global:WmiApps = (Get-WmiObject -Class Win32_Product).Name | Select-Object -Unique | Sort-Object
	Write-Host '--[Scanning Native Powershell Repository]'
	$Global:PowershellApps = (Get-Package -Provider Programs -IncludeWindowsInstaller).Name | Select-Object -Unique | Sort-Object
	Write-Host '--[Scanning Registry UninstallString Repository]'
	$Global:uninstallX86RegPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
	$Global:uninstallX64RegPath = "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
	$Global:RegistryApps = (Get-ChildItem $uninstallX86RegPath | ForEach-Object { Get-ItemProperty $_.PSPath }).DisplayName
	$RegistryApps += (Get-ChildItem $uninstallX64RegPath | ForEach-Object { Get-ItemProperty $_.PSPath }).DisplayName
	$Global:AllApps = $WmiApps + $PowershellApps + $RegistryApps | Select-Object -Unique | Sort-Object
	$Global:Uninstalled = $False


	Function Uninstall-WmiApp {
		Write-Host -NoNewLine "Attempting Wmi method. "
		$AppWmi = Get-WmiObject -Class Win32_Product -ErrorAction SilentlyContinue | Where-Object {$_.Name -match $AppToUninstall}
		$AppWmiName = $AppWmi.Name
		If ($AppWmi) {
			If ($AppWmi) {
				$AppWmi.Uninstall()
				$AppWmi = Get-WmiObject -Class Win32_Product -ErrorAction SilentlyContinue | Where-Object {$_.Name -match $AppToUninstall}
			}
			If (-not $AppWmi) {
				Write-Host -ForegroundColor Green "$AppToUninstall appears to have been successfully uninstalled via Wmi method.`n$AppWmiName"
				$Global:Uninstalled = $True
			} Else {
				Write-Host -ForegroundColor Yellow "Uninstalling via `(Get-WmiObject`).Uninstall`(`) method didn`'t work."
			}
		}
	}

	Function Uninstall-PowershellApp {
		Write-Host -NoNewLine "Attempting Uninstall-Package method. "
		$Package = Get-Package -Provider Programs -IncludeWindowsInstaller | Where-Object -Property 'Name' -Match $AppToUninstall
		Get-Package -Provider Programs -IncludeWindowsInstaller | Where-Object -Property 'Name' -Match $AppToUninstall | Uninstall-Package -Force -AllVersions
		If (-not (Get-Package -Provider Programs -IncludeWindowsInstaller | Where-Object -Property 'Name' -Match $AppToUninstall)){
			Write-Host -ForegroundColor Green "$AppToUninstall appears to have been successfully uninstalled via Uninstall-Package method.`n$Package"
			$Global:Uninstalled = $True
		} Else {
			Write-Host -ForegroundColor Yellow "Uninstalling via Uninstall-Package method didn't work."

		}
	}

	Function Uninstall-RegistryApp {
		Write-Host -NoNewLine "Attempting Registry UninstallString method. "

		# Get registry entries for the application (Select-Object -First 1 ensures single entry)
		$regEntry32 = Get-ChildItem $uninstallX86RegPath -ErrorAction SilentlyContinue | ForEach-Object { Get-ItemProperty $_.PSPath } | Where-Object { $_.DisplayName -Match $AppToUninstall } | Select-Object -First 1
		$regEntry64 = Get-ChildItem $uninstallX64RegPath -ErrorAction SilentlyContinue | ForEach-Object { Get-ItemProperty $_.PSPath } | Where-Object { $_.DisplayName -Match $AppToUninstall } | Select-Object -First 1

		# Prefer 64-bit entry over 32-bit if available
		$regEntry = If ($regEntry64) { $regEntry64 } ElseIf ($regEntry32) { $regEntry32 } Else { $null }

		If (-not $regEntry) {
			Write-Host -ForegroundColor Yellow "Application not found in registry."
			return
		}

		# Prefer QuietUninstallString if available
		$uninstallString = $null
		$IsQuietString = $False

		If ($regEntry.QuietUninstallString) {
			$uninstallString = $regEntry.QuietUninstallString
			$IsQuietString = $True
			Write-Host -NoNewLine "(Using QuietUninstallString) "
		} ElseIf ($regEntry.UninstallString) {
			$uninstallString = $regEntry.UninstallString
		}

		If (-not $uninstallString) {
			Write-Host -ForegroundColor Yellow "No uninstall string found."
			return
		}

		# Determine if this is an MSI or EXE uninstaller (case-insensitive, match GUID anywhere in string)
		$IsMsi = $uninstallString -match '(?i)msiexec|\.msi|\{[A-Fa-f0-9]{8}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{12}\}'

		If ($IsMsi) {
			# Handle MSI uninstaller
			Write-Host -NoNewLine "(MSI detected) "
			$guid = $uninstallString -Replace "(?i)msiexec\.exe","" -Replace "/I","" -Replace "/X","" -Replace '"',''
			$guid = $guid.Trim()

			# Extract GUID if present (case-insensitive)
			If ($guid -match '(?i)(\{[A-Fa-f0-9]{8}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{12}\})') {
				$guid = $Matches[1]
			}

			$process = Start-Process "msiexec.exe" -ArgumentList "/X $guid /qn /norestart" -Wait -NoNewWindow -PassThru
			If ($process.ExitCode -eq 0 -or $process.ExitCode -eq 3010) {
				Write-Host -NoNewLine "(Exit code: $($process.ExitCode)) "
			} Else {
				Write-Host -ForegroundColor Yellow "(Exit code: $($process.ExitCode)) "
			}
		} Else {
			# Handle EXE uninstaller
			Write-Host -NoNewLine "(EXE detected) "

			# If we already have a quiet string, use it directly
			If ($IsQuietString) {
				$exitCode = Invoke-UninstallString -UninstallString $uninstallString
				If ($exitCode -eq 0 -or $exitCode -eq 3010 -or $exitCode -eq 1605) {
					Write-Host -NoNewLine "(Exit code: $exitCode) "
				} Else {
					Write-Host -ForegroundColor Yellow "(Exit code: $exitCode - may indicate failure) "
				}
			} Else {
				# Try to add silent switches for common installer types
				Invoke-SilentExeUninstall -UninstallString $uninstallString
			}
		}

		# Verify uninstall success (wait for registry to update)
		Start-Sleep -Seconds 5
		$RegistryApps = (Get-ChildItem $uninstallX86RegPath -ErrorAction SilentlyContinue | ForEach-Object { Get-ItemProperty $_.PSPath }).DisplayName
		$RegistryApps += (Get-ChildItem $uninstallX64RegPath -ErrorAction SilentlyContinue | ForEach-Object { Get-ItemProperty $_.PSPath }).DisplayName
		If (-not ($RegistryApps -Match $AppToUninstall)) {
			Write-Host -ForegroundColor Green "$AppToUninstall appears to have been successfully uninstalled via Registry method."
			$Global:Uninstalled = $True
		} Else {
			Write-Host -ForegroundColor Yellow "Uninstalling via Registry UninstallString method didn't work."
		}
	}

	Function Invoke-UninstallString {
		param([string]$UninstallString)

		# Parse the uninstall string to separate executable from arguments
		$process = $null
		If ($UninstallString -match '^"([^"]+)"\s*(.*)$') {
			$exe = $Matches[1]
			$argList = $Matches[2]
		} ElseIf ($UninstallString -match '^(\S+\.exe)\s*(.*)$') {
			$exe = $Matches[1]
			$argList = $Matches[2]
		} Else {
			# Fallback: run as-is via cmd
			$process = Start-Process "cmd.exe" -ArgumentList "/c `"$UninstallString`"" -Wait -NoNewWindow -PassThru
			return $process.ExitCode
		}

		If ($argList) {
			$process = Start-Process $exe -ArgumentList $argList -Wait -NoNewWindow -PassThru
		} Else {
			$process = Start-Process $exe -Wait -NoNewWindow -PassThru
		}
		return $process.ExitCode
	}

	Function Invoke-SilentExeUninstall {
		param([string]$UninstallString)

		# Parse executable path from uninstall string
		$exe = $null
		$existingArgs = ""

		If ($UninstallString -match '^"([^"]+)"\s*(.*)$') {
			$exe = $Matches[1]
			$existingArgs = $Matches[2]
		} ElseIf ($UninstallString -match '^(\S+\.exe)\s*(.*)$') {
			$exe = $Matches[1]
			$existingArgs = $Matches[2]
		}

		# Validate executable exists and has .exe extension
		If (-not $exe -or -not ($exe -match '\.exe$') -or -not (Test-Path $exe -ErrorAction SilentlyContinue)) {
			# Fallback to running the string as-is
			$exitCode = Invoke-UninstallString -UninstallString $UninstallString
			return $exitCode
		}

		# Try to detect installer type by reading first 10MB of the executable (memory-safe)
		$preferredSwitch = $null
		$detectedType = $null
		$maxBytesToRead = 10MB
		Try {
			$fileStream = [System.IO.File]::OpenRead($exe)
			Try {
				$fileSize = $fileStream.Length
				$bytesToRead = [Math]::Min($fileSize, $maxBytesToRead)
				$buffer = New-Object byte[] $bytesToRead
				$null = $fileStream.Read($buffer, 0, $bytesToRead)
				$exeContent = [System.Text.Encoding]::ASCII.GetString($buffer)

				# Detect installer type from signatures in the binary
				If ($exeContent -match 'Nullsoft|NSIS') {
					$preferredSwitch = '/S'
					$detectedType = 'NSIS'
				} ElseIf ($exeContent -match 'Inno Setup') {
					$preferredSwitch = '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART'
					$detectedType = 'Inno Setup'
				} ElseIf ($exeContent -match 'InstallShield') {
					$preferredSwitch = '/s'
					$detectedType = 'InstallShield'
				} ElseIf ($exeContent -match 'WiX') {
					$preferredSwitch = '/quiet /uninstall'
					$detectedType = 'WiX'
				}
			} Finally {
				$fileStream.Close()
				$fileStream.Dispose()
			}
		} Catch {
			# If we can't read the file, continue without detection
		}

		# Build the argument list
		$argsToUse = $existingArgs

		If ($preferredSwitch) {
			# Check if key silent flags already exist (case-insensitive, check individual flags)
			$flagsToAdd = @()
			ForEach ($flag in ($preferredSwitch -split '\s+')) {
				If (-not $argsToUse -or $argsToUse -notmatch "(?i)$([regex]::Escape($flag))") {
					$flagsToAdd += $flag
				}
			}
			If ($flagsToAdd.Count -gt 0) {
				$argsToUse = ("$argsToUse " + ($flagsToAdd -join ' ')).Trim()
			}
			Write-Host -NoNewLine "(Detected: $detectedType, using: $preferredSwitch) "
		} Else {
			# Unknown installer type - use /S as most common silent switch (single attempt only)
			Write-Host -NoNewLine "(Unknown installer type, trying /S) "
			If (-not $argsToUse -or $argsToUse -notmatch '(?i)/S\b') {
				$argsToUse = ("$argsToUse /S").Trim()
			}
		}

		# Execute the uninstaller once and capture exit code
		$process = Start-Process $exe -ArgumentList $argsToUse -Wait -NoNewWindow -PassThru
		$exitCode = $process.ExitCode

		# Report exit code (0 = success, 3010 = reboot required, 1605 = not installed)
		If ($exitCode -eq 0 -or $exitCode -eq 3010 -or $exitCode -eq 1605) {
			Write-Host -NoNewLine "(Exit code: $exitCode) "
		} Else {
			Write-Host -ForegroundColor Yellow "(Exit code: $exitCode - may indicate failure) "
		}

		return $exitCode
	}

	If (-Not $AppToUninstall) {
		Write-Host "Review the applications available to uninstall, then enter it verbatim."
		Write-Host -ForegroundColor Yellow "Note: You can use the '-AppToUninstall' options to specify the app without interaction or pipe in the name."
		Pause
		$AllApps | More
		$AppToUninstall = Read-Host "App to Uninstall: "
	}

	If ($AppToUninstall){
		If ($AllApps -Match $AppToUninstall) {
			Write-Host "$AppToUninstall found. Attempting uninstall. "
			If ($WmiApps -Match $AppToUninstall) {Uninstall-WmiApp}
			If ((-Not $Uninstalled) -and ($PowershellApps -Match $AppToUninstall)) {Uninstall-PowershellApp}
			If ((-Not $Uninstalled) -and ($RegistryApps -Match $AppToUninstall)) {Uninstall-RegistryApp}
			If (-Not $Uninstalled) {Write-Host -ForegroundColor Red "Uninstall Failed. Please try uninstalling via Windows Settings Menus."}
		} Else {
			Write-Host -ForegroundColor Yellow "$AppToUninstall was not found."
		}
	} Else {
		Write-Host -ForegroundColor Red "No application specified."
	}
	#Cleanup!
	@("WmiApps", "PowershellApps", "uninstallX86RegPath", "uninstallX64RegPath", "RegistryApps", "AllApps", "Uninstalled") | ForEach-Object {
		Clear-Variable $_ -Force -ErrorAction SilentlyContinue
	}
}

Function Uninstall-UmbrellaDNS {
	Uninstall-Application -AppToUninstall "Cisco Secure Client"
}

# SIG # Begin signature block
# MIIF0AYJKoZIhvcNAQcCoIIFwTCCBb0CAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUeI2PpPNa9TPUp3/mq99ZAApU
# dW+gggNKMIIDRjCCAi6gAwIBAgIQFhG2sMJplopOBSMb0j7zpDANBgkqhkiG9w0B
# AQsFADA7MQswCQYDVQQGEwJVUzEYMBYGA1UECgwPVGVjaG5vbG9neUdyb3VwMRIw
# EAYDVQQDDAlBbWJpdGlvbnMwHhcNMjQwNTE3MjEzNjE0WhcNMjUwNTE3MjE0NjE0
# WjA7MQswCQYDVQQGEwJVUzEYMBYGA1UECgwPVGVjaG5vbG9neUdyb3VwMRIwEAYD
# VQQDDAlBbWJpdGlvbnMwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCc
# sesiq3h/qYB2H80J5kTzMdmjIWe/BHmnUDv2JHBGdxp+ZOT+J9RpPtHNQDXB3Lca
# aL4YjAWC4H+UqJDJJpFj8OXBns9zfpR5coV5+eR6YjRvos9TILNwdErlLrp5CcxN
# vtNR99GyXGsfzrvxc4uWwRc4/fjCPgYHs1BmFyxzSneTlr4CZ56wPJZ1yGRHKn0y
# H5O26/af7stiGZ2GLmXF8VMpEqGE/xWs31aM8xzYBN5FAQjAwoJTGZvm13kukR1t
# 6Uq3huPX5lUpTasPJ3qLXnePKYtIr+390aNzj2+sDt3lcH51vP46nFMQrpzD/Xaz
# K/7UP+9I4J8goswNTrZRAgMBAAGjRjBEMA4GA1UdDwEB/wQEAwIFoDATBgNVHSUE
# DDAKBggrBgEFBQcDAzAdBgNVHQ4EFgQUuS0+jvyX95p7+tTFuzZ+ulXo7jQwDQYJ
# KoZIhvcNAQELBQADggEBAF4DPkvlELNjrIUYtWMsFjn+VU6vXENJ3lktFShfL8IS
# 1GDlNZFu+vuJJ2nzLuSNERzdfWa6Pd5qIP05eeinJJtN/sqCPVoLjmA1Td4K6Rau
# Cg8WlxgemTDr3IwqejUlGq8h5AYIw1ike7Q70m9UWyIWT8XNILcXXK0UKUylHRl/
# f+fPinhW56qDDmL+7ctECrTBtm8d1aZOtLEijEbZTg72N2SwaKF7mUVmycT5MuN7
# 46w+V1w/i46wPcf0hkTazvISgUevjXj7dM04U+htX+mDwpvjP/QvQjo37ozOYdQR
# pIjjnNPZIFXprVXI2PRvM/YqP6KTiyKPqOuI+TA9RmkxggHwMIIB7AIBATBPMDsx
# CzAJBgNVBAYTAlVTMRgwFgYDVQQKDA9UZWNobm9sb2d5R3JvdXAxEjAQBgNVBAMM
# CUFtYml0aW9ucwIQFhG2sMJplopOBSMb0j7zpDAJBgUrDgMCGgUAoHgwGAYKKwYB
# BAGCNwIBDDEKMAigAoAAoQKAADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAc
# BgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUGdm0
# T/PVEis2w5n7mhfrVTY9TrIwDQYJKoZIhvcNAQEBBQAEggEAGfE9X/mZXKFcwAed
# mUz+Ozy/waEI/eZP8RIV6f29a2zPAEpedItUyGo83mDy/O9IJwJVSXjr2OheuA4A
# wvf6XCzHDsQsKs+KcI2jwpku2SVswSA3gg8+EuSMzlYMC2HA0BhF1SX1Qs3W1R0k
# 8FY6OWkBx9+4spJic98cP5wQCxtoPsOA9ibs55vDsvcOOTlN2zv9i7BExyctBEeX
# QjrpdPDWZdgPGb/L63ucFOY7Fg9jA6nlt+OOIq4Te9soWlP1bxEeEykV3v8VTEzp
# Ue8rdEsZgQGeQ7EgKOeuM+kGzZuBdhsQpWbs8wzaf65rkIpgLTPOqTvVJpkkeBvY
# JzOneA==
# SIG # End signature block