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
	Write-Host '--[Scanning MSIExec UninstallString Repository]'
	$Global:uninstallX86RegPath="HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" | Select-Object -Unique | Sort-Object
	$Global:uninstallX64RegPath="HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall" | Select-Object -Unique | Sort-Object
	$Global:MsiApps = (Get-ChildItem $uninstallX86RegPath | ForEach-Object { Get-ItemProperty $_.PSPath }).DisplayName
	$MsiApps += (Get-ChildItem $uninstallX64RegPath | ForEach-Object { Get-ItemProperty $_.PSPath }).DisplayName
	$Global:AllApps = $WmiApps + $PowershellApps + $MsiApps | Select-Object -Unique | Sort-Object
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

	Function Uninstall-MsiApp {
		Write-Host -NoNewLine "Attempting MSI UninstallString method. "
		$uninstallString=""
		$uninstall32 = (Get-ChildItem $uninstallX86RegPath | ForEach-Object { Get-ItemProperty $_.PSPath } | ? { $_ -Match $AppToUninstall }).UninstallString
		$uninstall64 = (Get-ChildItem $uninstallX64RegPath | ForEach-Object { Get-ItemProperty $_.PSPath } | ? { $_ -Match $AppToUninstall }).UninstallString
		If($uninstall64) {$uninstallString=$uninstall64}
		If($uninstall32) {$uninstallString=$uninstall32}
		If(!$uninstallString) {
			Write-Error "Application was is not found"
		}
		$uninstallString = $uninstallString -Replace "msiexec.exe","" -Replace "/I","" -Replace "/X",""
		$uninstallString = $uninstallString.Trim()
		Start-Process "msiexec.exe" -arg "/X $uninstallString /qn" -Wait
		$MsiApps = (Get-ChildItem $uninstallX86RegPath | ForEach-Object { Get-ItemProperty $_.PSPath }).DisplayName
		$MsiApps += (Get-ChildItem $uninstallX64RegPath | ForEach-Object { Get-ItemProperty $_.PSPath }).DisplayName
		If (-not ($MsiApps -Match $AppToUninstall)) {
			Write-Host -ForegroundColor Green "$AppToUninstall appears to have been successfully uninstalled via MSI UninstallString method.`n$MsiApps"
			$Global:Uninstalled = $True
		} Else {
			Write-Host -ForegroundColor Yellow "Uninstalling via Msi UninstallString method didn't work."
		}
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
			If ((-Not $Uninstalled) -and ($MsiApps -Match $AppToUninstall)) {Uninstall-MsiApp}
			If (-Not $Uninstalled) {Write-Host -ForegroundColor Red "Uninstall Failed. Please try uninstalling via Windows Settings Menus."}
		} Else {
			Write-Host -ForegroundColor Yellow "$AppToUninstall was not found."
		}
	} Else {
		Write-Host -ForegroundColor Red "No application specified."
	}
	#Cleanup!
	@("WmiApps", "PowershellApps", "uninstallX86RegPath", "uninstallX64RegPath", "MsiApps", "AllApps", "Uninstalled") | ForEach-Object {
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