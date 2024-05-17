Function Join-Domain {
	param
(
	[Parameter(Mandatory=$true)]
	[string]$Domain,
	[Parameter(Mandatory=$true)]
	[string]$Username,
	[Parameter(Mandatory=$true)]
	$Password
)
Write-Host "Join Domain"
$Password = $Password | ConvertTo-SecureString -asPlainText -Force
$Username = $Domain + "\" + $Username
$credential = New-Object System.Management.Automation.PSCredential($Username,$Password)
If (-not (Test-Connection $Domain -Quiet -Count 1)) {
	Write-Host "$Domain is not accessible. Waiting up to 30 seconds for it to become available."
	$Var = 30
	Do {
	Write-Host "Trying to reach $Domain for another $var seconds."
	Start-Sleep -Seconds 1
	$Var--
	} until (($Var -eq 0) -or (Test-Connection $Domain -Quiet -Count 1))
}
If (Test-Connection $Domain -Count 1) {
	Write-Host "$Domain is accessible."
} Else {
	Write-Host "ERROR: $Domain does not appear to be accessible. Trying anyway Just in case."
}
Start-Sleep -Seconds 5
Add-Computer -DomainName $Domain -Credential $credential
}

# SIG # Begin signature block
# MIIF0AYJKoZIhvcNAQcCoIIFwTCCBb0CAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUnWvhDTyeWXch6rry4JWAYYYl
# NOKgggNKMIIDRjCCAi6gAwIBAgIQFhG2sMJplopOBSMb0j7zpDANBgkqhkiG9w0B
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
# BgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUJ2TA
# ANLD8F9nH+ozoVrim4Jel7IwDQYJKoZIhvcNAQEBBQAEggEAjITnAidc3lqD1UjA
# Ji1/n9ERQOHniolsp62cipHrNZkB2ZttXaXo9BMgqluaPlOLcrHYDrT1VYksenhv
# PmSYPh87G7bcUuN9Vp8zMoX/LLsWQ0CrmsqByLzg6Q7Pa7P3lhT+Vtk+snWsXMYD
# 7YQ2fl/UIo9QiiJI16QYtqPcobSGsdBROcrXewMtlwngLYEqPtq3LjDHiw2Jz2Gg
# qKN7/D+xE3xLl+qD9JBmrRUr8jTZ+lOrldtbQwGjYpS1rQu/wvs6qLB56J/bqkpI
# 0fzqYj67niVt+tQnrlYg2tOWksaV99lscP0Nwd1HsEO7aNxvRvvGlRzDm4h+FmVP
# cF+IoA==
# SIG # End signature block