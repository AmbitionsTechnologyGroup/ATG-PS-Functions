Function Expand-Terminal {
	mode con: cols=120 lines=60
	$host.UI.RawUI.BufferSize = New-Object System.Management.Automation.Host.Size(120,10240)
}

Function Expand-SystemPartition {
<#
	.SYNOPSIS
		Expands a system partition by relocating the Windows recovery partition to the end of the disk.

	.DESCRIPTION
		This function detects and relocates a Windows recovery partition that exists after the system
		partition, then expands the system partition to fill the available space. It is designed for
		Hyper-V VMs where the VHDX has been expanded but the guest partition cannot grow due to the
		recovery partition placement.

		The function performs the following steps:
		1. Verifies Administrator privileges
		2. Detects the disk number from the specified drive letter
		3. Finds the recovery partition that blocks expansion
		4. Disables Windows RE using reagentc /disable
		5. Deletes the recovery partition using diskpart
		6. Expands the system partition, leaving room for the new recovery partition
		7. Creates a new recovery partition at the end with proper GUID and GPT attributes
		8. Re-enables Windows RE using reagentc /enable or /setreimage

	.PARAMETER DriveLetter
		The drive letter of the system partition to expand. Defaults to "C".

	.PARAMETER RecoveryPartitionSizeMB
		The size in MB for the recreated recovery partition. Defaults to 1000 MB.

	.PARAMETER Force
		Skips confirmation prompts. Use with caution.

	.EXAMPLE
		Expand-SystemPartition
		Expands the C: drive using default settings with confirmation prompts.

	.EXAMPLE
		Expand-SystemPartition -DriveLetter "D" -RecoveryPartitionSizeMB 2000 -Force
		Expands the D: drive with a 2000 MB recovery partition without confirmation prompts.

	.EXAMPLE
		Expand-SystemPartition -WhatIf
		Shows what would happen without making any changes.

	.NOTES
		IMPORTANT: This operation carries risk and should be tested before production use.

		This function is designed for Hyper-V VMs where the VHDX has already been expanded
		but the guest partition cannot grow due to the recovery partition placement.

		Requires Administrator privileges to run.
		Uses diskpart for partition deletion as PowerShell cmdlets do not reliably delete recovery partitions.
#>
	[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
	param (
		[Parameter(Mandatory=$false)]
		[ValidatePattern('^[A-Za-z]$')]
		[string]$DriveLetter = "C",

		[Parameter(Mandatory=$false)]
		[ValidateRange(500, 10000)]
		[int]$RecoveryPartitionSizeMB = 1000,

		[Parameter(Mandatory=$false)]
		[switch]$Force
	)

	# Check for Administrator privileges
	$IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
	If (-not $IsAdmin) {
		Write-Error "This function requires Administrator privileges. Please run as Administrator."
		return
	}

	# Normalize drive letter
	$DriveLetter = $DriveLetter.ToUpper().TrimEnd(':')
	Write-Verbose "Checking drive letter: ${DriveLetter}:"

	# Verify the drive letter exists
	$SystemPartition = Get-Partition -DriveLetter $DriveLetter -ErrorAction SilentlyContinue
	If (-not $SystemPartition) {
		Write-Error "Drive letter ${DriveLetter}: does not exist."
		return
	}

	# Get disk number and partition information
	$DiskNumber = $SystemPartition.DiskNumber
	$OriginalSizeGB = [math]::Round($SystemPartition.Size / 1GB, 2)
	Write-Verbose "System partition ${DriveLetter}: is on Disk $DiskNumber and is currently $OriginalSizeGB GB"

	# Get all partitions on this disk
	$AllPartitions = Get-Partition -DiskNumber $DiskNumber | Sort-Object Offset
	Write-Verbose "Found $($AllPartitions.Count) partitions on Disk $DiskNumber"

	# Find the recovery partition that comes after the system partition
	$SystemPartitionOffset = $SystemPartition.Offset
	$RecoveryPartition = $AllPartitions | Where-Object {
		$_.Offset -gt $SystemPartitionOffset -and $_.Type -eq 'Recovery'
	} | Select-Object -First 1

	If (-not $RecoveryPartition) {
		Write-Warning "No recovery partition found after the system partition. The system partition may already be expanded or there may be no unallocated space."

		# Check for unallocated space
		$Disk = Get-Disk -Number $DiskNumber
		$TotalSize = $Disk.Size
		$UsedSize = ($AllPartitions | Measure-Object -Property Size -Sum).Sum
		$UnallocatedSpace = $TotalSize - $UsedSize
		$UnallocatedSpaceGB = [math]::Round($UnallocatedSpace / 1GB, 2)

		If ($UnallocatedSpaceGB -gt 0.1) {
			Write-Host "There is $UnallocatedSpaceGB GB of unallocated space available. You can expand the partition directly using Disk Management or the Resize-Partition cmdlet."
		} else {
			Write-Host "There is no significant unallocated space on the disk."
		}
		return
	}

	$RecoveryPartitionNumber = $RecoveryPartition.PartitionNumber
	$RecoveryPartitionSizeGB = [math]::Round($RecoveryPartition.Size / 1GB, 2)
	Write-Verbose "Found recovery partition: Partition $RecoveryPartitionNumber (Size: $RecoveryPartitionSizeGB GB)"

	# Calculate available space after removing recovery partition
	$Disk = Get-Disk -Number $DiskNumber
	$TotalDiskSize = $Disk.Size
	$UsedSpaceWithoutRecovery = ($AllPartitions | Where-Object { $_.PartitionNumber -ne $RecoveryPartitionNumber } | Measure-Object -Property Size -Sum).Sum
	$AvailableSpaceGB = [math]::Round(($TotalDiskSize - $UsedSpaceWithoutRecovery) / 1GB, 2)
	$ExpectedNewSizeGB = [math]::Round($OriginalSizeGB + $AvailableSpaceGB - ($RecoveryPartitionSizeMB / 1024), 2)

	Write-Host "`nCurrent Configuration:"
	Write-Host "  System Partition (${DriveLetter}:): $OriginalSizeGB GB"
	Write-Host "  Recovery Partition: $RecoveryPartitionSizeGB GB"
	Write-Host "  Available Space: $AvailableSpaceGB GB"
	Write-Host "  Expected New Size: $ExpectedNewSizeGB GB"
	Write-Host ""

	If ($AvailableSpaceGB -lt 1) {
		Write-Warning "Expanding the partition will not gain significant space (less than 1 GB). Aborting."
		return
	}

	# Confirmation prompt (unless -Force is specified)
	If (-not $Force -and -not $PSCmdlet.ShouldProcess("Drive ${DriveLetter}: on Disk $DiskNumber", "Relocate recovery partition and expand system partition")) {
		Write-Host "Operation cancelled by user."
		return
	}

	# Initialize result tracking
	$RecoveryPartitionRecreated = $false
	$WindowsREEnabled = $false
	$ErrorOccurred = $false

	Try {
		# Step 1: Disable Windows RE
		Write-Verbose "Disabling Windows RE..."
		$ReagentOutput = reagentc /disable 2>&1
		Write-Verbose "Reagentc output: $ReagentOutput"

		If ($LASTEXITCODE -ne 0) {
			Write-Warning "Failed to disable Windows RE. This may not be critical. Continuing..."
		} else {
			Write-Verbose "Windows RE disabled successfully."
		}

		# Step 2: Delete the recovery partition using diskpart
		Write-Verbose "Deleting recovery partition using diskpart..."
		$DiskpartScript = @"
select disk $DiskNumber
select partition $RecoveryPartitionNumber
delete partition override
"@

		$DiskpartScriptPath = "$env:TEMP\diskpart_script_$(Get-Random).txt"
		$DiskpartScript | Out-File -FilePath $DiskpartScriptPath -Encoding ASCII -Force

		$DiskpartOutput = diskpart /s $DiskpartScriptPath 2>&1 | Out-String
		Remove-Item -Path $DiskpartScriptPath -Force -ErrorAction SilentlyContinue

		Write-Verbose "Diskpart output: $DiskpartOutput"

		If ($DiskpartOutput -match "error|failed") {
			Throw "Diskpart failed to delete the recovery partition. Output: $DiskpartOutput"
		}

		Write-Verbose "Recovery partition deleted successfully."

		# Step 3: Expand the system partition
		Write-Verbose "Expanding system partition ${DriveLetter}:..."

		# Calculate the maximum size we can expand to (leaving room for recovery partition)
		$RecoveryPartitionSizeBytes = $RecoveryPartitionSizeMB * 1MB
		$MaxSize = $SystemPartition.Size + ($RecoveryPartition.Size) + ($TotalDiskSize - ($AllPartitions | Measure-Object -Property Size -Sum).Sum) - $RecoveryPartitionSizeBytes - (100MB)

		# Resize the partition
		Resize-Partition -DriveLetter $DriveLetter -Size $MaxSize -ErrorAction Stop
		Write-Verbose "System partition expanded successfully."

		# Step 4: Create new recovery partition at the end
		Write-Verbose "Creating new recovery partition..."

		# Create diskpart script for recovery partition
		$RecoveryDiskpartScript = @"
select disk $DiskNumber
create partition primary
format quick fs=ntfs label="Recovery"
set id="de94bba4-06d1-4d40-a16a-bfd50179d6ac"
gpt attributes=0x8000000000000001
"@

		$RecoveryScriptPath = "$env:TEMP\diskpart_recovery_$(Get-Random).txt"
		$RecoveryDiskpartScript | Out-File -FilePath $RecoveryScriptPath -Encoding ASCII -Force

		$RecoveryDiskpartOutput = diskpart /s $RecoveryScriptPath 2>&1 | Out-String
		Remove-Item -Path $RecoveryScriptPath -Force -ErrorAction SilentlyContinue

		Write-Verbose "Recovery partition diskpart output: $RecoveryDiskpartOutput"

		If ($RecoveryDiskpartOutput -match "error|failed") {
			Write-Warning "Failed to create recovery partition. Output: $RecoveryDiskpartOutput"
		} else {
			Write-Verbose "Recovery partition created successfully."
			$RecoveryPartitionRecreated = $true
		}

		# Step 5: Re-enable Windows RE
		Write-Verbose "Re-enabling Windows RE..."
		$ReenableOutput = reagentc /enable 2>&1 | Out-String
		Write-Verbose "Reagentc enable output: $ReenableOutput"

		If ($LASTEXITCODE -ne 0) {
			Write-Warning "Failed to enable Windows RE with /enable. Trying /setreimage..."
			$SetreimageOutput = reagentc /setreimage /path C:\Windows\System32\Recovery 2>&1 | Out-String
			Write-Verbose "Reagentc setreimage output: $SetreimageOutput"

			If ($LASTEXITCODE -eq 0) {
				$WindowsREEnabled = $true
				Write-Verbose "Windows RE enabled using /setreimage."
			} else {
				Write-Warning "Failed to enable Windows RE. Manual intervention may be required."
				Write-Warning "You can try manually running: reagentc /setreimage /path C:\Windows\System32\Recovery"
			}
		} else {
			$WindowsREEnabled = $true
			Write-Verbose "Windows RE enabled successfully."
		}

	} Catch {
		$ErrorOccurred = $true
		Write-Error "An error occurred during partition expansion: $_"

		# Attempt to recreate recovery partition if we deleted it but failed to expand
		If (-not $RecoveryPartitionRecreated) {
			Write-Warning "Attempting to recreate recovery partition to restore system state..."
			Try {
				$EmergencyRecoveryScript = @"
select disk $DiskNumber
create partition primary
format quick fs=ntfs label="Recovery"
set id="de94bba4-06d1-4d40-a16a-bfd50179d6ac"
gpt attributes=0x8000000000000001
"@
				$EmergencyScriptPath = "$env:TEMP\diskpart_emergency_$(Get-Random).txt"
				$EmergencyRecoveryScript | Out-File -FilePath $EmergencyScriptPath -Encoding ASCII -Force

				$EmergencyOutput = diskpart /s $EmergencyScriptPath 2>&1 | Out-String
				Remove-Item -Path $EmergencyScriptPath -Force -ErrorAction SilentlyContinue

				If ($EmergencyOutput -notmatch "error|failed") {
					$RecoveryPartitionRecreated = $true
					Write-Host "Emergency recovery partition creation succeeded."
				} else {
					Write-Warning "Emergency recovery partition creation failed. Manual recovery required."
				}
			} Catch {
				Write-Warning "Emergency recovery partition creation encountered an error: $_"
			}
		}
	}

	# Get final size
	$FinalPartition = Get-Partition -DriveLetter $DriveLetter -ErrorAction SilentlyContinue
	$NewSizeGB = If ($FinalPartition) { [math]::Round($FinalPartition.Size / 1GB, 2) } else { $OriginalSizeGB }

	# Output summary
	Write-Host "`n========================================" -ForegroundColor Cyan
	Write-Host "Partition Expansion Complete" -ForegroundColor Green
	Write-Host "========================================" -ForegroundColor Cyan
	Write-Host "Original Size: $OriginalSizeGB GB"
	Write-Host "New Size: $NewSizeGB GB"
	Write-Host "Space Gained: $([math]::Round($NewSizeGB - $OriginalSizeGB, 2)) GB"
	Write-Host "Recovery Partition Recreated: $RecoveryPartitionRecreated"
	Write-Host "Windows RE Enabled: $WindowsREEnabled"
	Write-Host "========================================`n" -ForegroundColor Cyan

	If ($ErrorOccurred) {
		Write-Warning "The operation completed with errors. Please review the output above."
	}

	# Return result object
	return [PSCustomObject]@{
		DriveLetter = "${DriveLetter}:"
		OriginalSizeGB = $OriginalSizeGB
		NewSizeGB = $NewSizeGB
		RecoveryPartitionRecreated = $RecoveryPartitionRecreated
		WindowsREEnabled = $WindowsREEnabled
	}
}

# SIG # Begin signature block
# MIIF0AYJKoZIhvcNAQcCoIIFwTCCBb0CAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUXqfyt1YqSJuu6wJzaSnUIbtB
# l4ugggNKMIIDRjCCAi6gAwIBAgIQFhG2sMJplopOBSMb0j7zpDANBgkqhkiG9w0B
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
# BgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUrrvL
# dnlLf1dlTELMB+bNPz4Mvp4wDQYJKoZIhvcNAQEBBQAEggEAb1rPtp0lpFv6PZnV
# 0sB3dzI+ALX1wZd/svY1H8Tn2xfCKo+mCTcXu7TKsvB+corTGStpfLvrvCiAtgy8
# ir0cvNLKcIuYSGnrd7LEUWVr0gOTiLM6M24k9IgRAOv/+tdaUAkKIzYyd5u3vYbA
# g77x9pzGTe5H161RKj/pJkQNI+HLObQ3m23fgw+sTpkZL7zIDNZuontoSHp0VDW3
# Amd8FjAxRID74udvg/nVn+VGcDmbwWGe23DHBzYAhg3H2RvNsFB5+7//Zc0lIfd6
# Tck3s2Q3oR2b38FDTbHS3elD6maHFliSuYOzdqPU53XpyKil4SIlulhOKteq6zuE
# PDp4DA==
# SIG # End signature block
