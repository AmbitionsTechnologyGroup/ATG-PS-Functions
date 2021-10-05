<#
.DESCRIPTION
  Using an Office 365 Global Administrator Account, connect to the tenant
  using PowerShell to obtain as much data from the site as possible.
#>

using module .\Base.psm1

$HashSep = ('#' * 60 + "`n")

# get the primary doomain name; email address
Write-Host "$HashSep [+] Office 365 Tenant Info"
$365Domain = Read-Host "What is the source Office 365 Domain Name (i.e. `"example.com`")?"
$365AdminEmail = "MailMigration@$365Domain"

$prompt = Read-Host "Enter the Global Admin's email address [DEFAULT: $365AdminEmail]"
If ($prompt) { $365AdminEmail = $prompt }

Write-Host $HashSep [+] Project Root Directory
If (Test-Path -Path $env:OneDrive) {
    $ProjectRootDir = "$env:OneDrive\Documents\Migration\$365Domain"
} Else {
    $ProjectRootDir = "$env:USERPROFILE\Documents\Migration\$365Domain"
}
Write-Host "Project Home Directory: $ProjectRootDir"

If (!(Test-Path $ProjectRootDir)) {
    Write-Host "Creating Project Root Directory"
    New-Item -Type Directory $ProjectRootDir | Out-Null
}

Write-Host "$HashSep [+] Connecting PowerShell to MS Online Services"
Connect-365Services -UserName $365AdminEmail

# get mailboxes
Write-Host $HashSep [+] Gathering User Mailboxes
$365UserMailboxes = Get-365UserMailboxes
Write-Host Done!

# shared mailboxes
Write-Host $HashSep [+] Gathering Shared Mailboxes
$365SharedMailboxes = Get-365SharedMailboxes
Write-Host Done!

# distribution groups
Write-Host $HashSep [+] Gathering Distribution Groups
$365DistributionGroups = Get-365DistributionGroups
Write-Host Done!

Write-Host "Disconnecting 365 services..."
Disconnect-ExchangeOnline -Confirm:$false
Disconnect-AzureAD

# export user mailboxes to CSV
$UserMailboxOutput = "$ProjectRootDir\UserMailboxes.csv"
"Exporting user mailboxes to: $UserMailboxOutput"
$365UserMailboxes | Export-Csv -Path "$UserMailboxOutput" -NoTypeInformation

# export shared mailboxes to CSV
If ($365SharedMailboxes) {
  $SharedMailboxesOutput = "$ProjectRootDir\SharedMailboxes.csv"
  "Exporting shared mailboxes to: $SharedMailboxesOutput"
  $365SharedMailboxes | Export-Csv -Path "$SharedMailboxesOutput" -NoTypeInformation
} Else {
  Write-Host -BackgroundColor Black -ForegroundColor Yellow `
  "  [!] No Shared Mailboxes were found in the tenant"
}

# export distribution groups to CSV
$DistributionGroupOutput = "$ProjectRootDir\DistributionGroups.csv"
"Exporting user mailboxes to: $UserMailboxOutput"
$365DistributionGroups | Export-Csv -Path "$DistributionGroupOutput" -NoTypeInformation
