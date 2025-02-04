Function Disconnect-AllUsers {
	<#
		.SYNOPSIS
			Logs off all users from a machine.
	#>
		(quser) -replace ">"," " -replace "\s+","," -replace "IDLE,TIME","IDLE TIME" -replace "LOGON,TIME","LOGON TIME" | ConvertFrom-Csv -Delimiter "," | foreach {
			logoff ($_.ID)
		}
	}
	
Function Disconnect-NetExtender {

    # Define the possible paths where NetExtender can exist.
    $possiblePaths = @(
        "${env:ProgramFiles(x86)}\SonicWALL\SSL-VPN\NetExtender\NEClI.exe"
        "${env:ProgramFiles(x86)}\SonicWall\SSL-VPN\NetExtender\nxcli.exe"
        "${env:ProgramFiles}\SonicWall\SSL-VPN\NetExtender\nxcli.exe"
    )
	
    $NEPath = $possiblePaths | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -Last 1

    If (!(Test-Path -LiteralPath $NEPath)) {
        Write-Host "This command only works if you have Sonicwall NetExtender installed."
    }
    Write-host "Initiating VPN disconnection"
    & $NEPath disconnect
    & $NEPath disconnect
    Write-Host ""
    Get-NetExtenderStatus

<#
.SYNOPSIS
    Disconnects an existing SSLVPN connection to a site using Sonicwall NetExtender
.EXAMPLE
    Disconnect-NetExtender
    This example disconnects from the VPN session.
#>
}
	
	Function Disconnect-O365Exchange {
		Disconnect-ExchangeOnline -Confirm:$false
	}
	
	
	# SIG # Begin signature block
	# MIIF0AYJKoZIhvcNAQcCoIIFwTCCBb0CAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
	# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
	# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUsA5KFUU2PLjPyypbBh8u1O+O
	# wVGgggNKMIIDRjCCAi6gAwIBAgIQFhG2sMJplopOBSMb0j7zpDANBgkqhkiG9w0B
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
	# BgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQU76Vk
	# vwK7iwwpwa3oeqTxyLbUdHkwDQYJKoZIhvcNAQEBBQAEggEAV73168J4Uy+hjZfs
	# 83haSCKd59/HTawfyC1rZ4WUvxjhene5R4zCOfbdoV7epgQR+jshm/9kO7HPO7JB
	# xCq47ORrLggtoO2cZDdZeZj31TIA+hyOmBxkL3qaJVBd1wtaAc8//KHfvQnMVOOZ
	# em8i/qqYRvpBQfvan7xMH4r6fx2zoOVbUGOxs6QE2pk5xtaFfnr1HpQwoioatGqp
	# 9t4hgKfHn1mIJJq5ri3O3wEbE0r9sjYipsd3Smja3r8U5iur4H5xSci7PJVvn03Z
	# uhe111oMuNFGGPPcpacQbI13dd1fY00TZUOGzKnAqRqEZ4YyXQnQCrRr6AUU7el2
	# iFyTnQ==
	# SIG # End signature block