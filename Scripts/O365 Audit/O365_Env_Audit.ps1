<#
	O365 Environment Scripting T20200915.0046 - O365 Environment Scripting | Research Project
	Family of Commands
	Audit what is set/not set
	On Demand Audits
	Audit to Reports/Dashboard
	Script Location – Knowledgebase
	IT Glue Document
	Git Hub script locations
	Settings we want to set O365
	Standards
+	Enable Audit Logs – set 365 days - https://o365reports.com/2020/01/21/enable-mailbox-auditing-in-office-365-powershell/#Enable-Mailbox-Auditing-by-Default
	MFA Confirmation
	Block Basic Auth
	Deleted Items Retention to max (30 day)
	Disables all shared mailbox sign-in?
	Alerting and Reporting
	Periodic confirmation that standards stay set
	Logins – Foreign Country, Excessive Failure
	Forward to External Addresses
	Deleted item deletion
	Auto-move/delete rules
	Sharepoint Site Creation
	Upload of .aspx, other formats?
	Quality of Life
	Junk Email Filter disable
	Spam Filter ProofPoint replacement
	Spam Filter
	Email Encryption
	Data protection policy (PII, HIPAA)
	URL Protection
#>
$OrgConfig = Get-OrganizationConfig
$OrgName = $OrgConfig.DisplayName


Write-Host "Enable Audit Logs – set 365 days"
Write-Host "Checking Mailbox Audit Settings"
$OrgAuditDisabled = $OrgConfig.AuditDisabled
$MailboxesAuditBypassed = Get-MailboxAuditBypassAssociation -ResultSize Unlimited | Select Identity,WhenCreated,AuditBypassEnabled | Where {$_.AuditBypassEnabled -eq $True}
$PerMailboxAuditSettings = Get-MailBox * | Select Identity,AuditEnabled,AuditLogAgeLimit

If ($OrgAuditDisabled) {
	Write-Host "[BAD] $OrgName does not have organization wide auditing enabled."
	Do {
		$Answer = Read-Host -Prompt 'Do you want to enable organization wide auditing? (y/n)'
		If (!($Answer -match 'y' -or $Answer -match 'n')) {Write-Host 'Please answer "y" for Yes or "n" for No.'}
	}
	Until ($Answer -match 'y' -or $Answer -match 'n')
	If ($Answer -match 'y') {
		Write-Host "Enabling organization wide auditing with the command: Set-OrganizationConfig -AuditDisabled $False -Verbose"
		Set-OrganizationConfig -AuditDisabled $False -Verbose
		Get-OrganizationConfig | Select AuditDisabled
	}
} Else {
	Write-Host "[GOOD] $OrgName does have organization wide auditing enabled."
	If ($MailboxesAuditBypassed) {
		Write-Host "[BAD] However, the following user(s) have a bypass on the audit:`n $MailboxesAuditBypassed"
		Do {
			$Answer = Read-Host -Prompt 'Do you want to enable auditing on all of these accounts? (y/n)'
			If (!($Answer -match 'y' -or $Answer -match 'n')) {Write-Host 'Please answer "y" for Yes or "n" for No.'}
		}
		Until ($Answer -match 'y' -or $Answer -match 'n')
		If ($Answer -match 'y') {
			Write-Host "[GOOD] Enabling auditing on all of these accounts with the command: Set-MailboxAuditBypassAssociation –Identity <Identity> -AuditBypassEnabled $false"
			$MailboxesAuditBypassed | ForEach-Object {Set-MailboxAuditBypassAssociation –Identity $_.Identity -AuditBypassEnabled $false}
		} Else {
			Write-Host "[INFORM] If you wish to enable auditing on any of these accounts, use the command:`n`tSet-MailboxAuditBypassAssociation –Identity <Identity> -AuditBypassEnabled $false"
		}
	} Else {
		Write-Host "[GOOD] No users have a bypass enabled."
	}
}

$EnabledAuditMailBoxes = $PerMailboxAuditSettings | Where-Object {$_.AuditEnabled -eq $True}
$ShortAuditAgeMailboxes = $EnabledAuditMailBoxes | Where-Object {[int]($_.AuditLogAgeLimit).Split(".")[0] -lt 365}
Write-Host "There are $(($EnabledAuditMailBoxes).Count) mailboxes with Audit enabled"
If ($ShortAuditAgeMailboxes) {
	Write-Host "[BAD] There are $(($ShortAuditAgeMailboxes).Count) mailboxes with an audit age limit less then 1 year"
	Do {
		$Answer = Read-Host -Prompt 'Do you want to extend the audit age limit on all of these accounts? (y/n)'
		If (!($Answer -match 'y' -or $Answer -match 'n')) {Write-Host 'Please answer "y" for Yes or "n" for No.'}
	}
	Until ($Answer -match 'y' -or $Answer -match 'n')
	If ($Answer -match 'y') {
		Write-Host "[GOOD] Extending the audit age limit to 365 days on all of these accounts with the command:`n`tSet-Mailbox –Identity <Identity> –AuditLogAgeLimit 365"
		$ShortAuditAgeMailboxes | ForEach-Object {Set-Mailbox –Identity $_.Identity –AuditLogAgeLimit 365;$newMailbox = Get-Mailbox -Identity "$_.Identity" | Select Identity,AuditEnabled,AuditLogAgeLimit; Write-Host "$($newMailbox.Identity) has now been set to an age limit of $(($newMailbox.AuditLogAgeLimit).Split(".")[0]) days"; $newMailbox = $Null}
	} Else {
		Write-Host "[INFORM] If you wish to Extend the audit age limit to 365 days on any of these accounts with the command:`n`tSet-Mailbox –Identity <Identity> –AuditLogAgeLimit 365"
	}
} ELSE {
	Write-Host "[GOOD] There are no mailboxes with an audit age limit less then 1 year"
}