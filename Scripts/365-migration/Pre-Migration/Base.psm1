
# Define MailboxUser Class
Class MailboxUser {
    [string]$FullName
    [string]$FirstName
    [string]$LastName
    [bool]$IsLicensed
    [bool]$IsDirSynced
    [string]$UserPrincipalName
    [string]$EmailAddress
    [string]$EmailAliases
    [string]$ArchiveStatus
    [datetime]$WhenMailboxCreated
    [string]$Title
    [string]$Department
    [string]$OfficeLocation
    [string]$Licenses
    [string]$OrganizationalUnit
}

Class SharedMailbox {
    [string]$DisplayName
    [string]$SamAccountName
    [string]$UserPrincipalName
    [string]$MailboxMembers
    [string]$EmailAliases
    [datetime]$WhenMailboxCreatedUtc
    [string]$UsageLocation
    [bool]$IsDirSynced
    [bool]$HiddenFromAddressLists
    [bool]$LitigationHoldEnabled
}

Class DistributionGroup {
    [string]$DisplayName
    [string]$Name
    [string]$GroupType
    [string]$GroupMembers
    [string]$SamAccountName
    [string]$PrimarySmtpAddress
    [string]$EmailAliases
    [string]$ManagedBy
    [bool]$IsDirSynced
    [datetime]$WhenCreatedUtc
}

Function Get-365UserMailboxes {

    $365Mailboxes = @()

    # get all usermailboxes
    $UserMailboxes = Get-Mailbox -RecipientTypeDetails UserMailbox -ResultSize Unlimited

    $counter = 1
    ForEach ($UserMailbox in $UserMailboxes) {

        [int]$pct = (($counter / $UserMailboxes.Count) * 100)
        $status = "$pct% Complete  [{0}`/{1}]" -f $counter, $UserMailboxes.Count
        Write-Progress -Activity "   Gathering User Mailbox Details" -Status $status -PercentComplete $pct
        $counter++

        $365User = [MailboxUser]::new()

        # first, connect MSOnline and see if this user is licensed
        $MsolUser = Get-MsolUser -UserPrincipalName $UserMailbox.UserPrincipalName
        $365User.IsLicensed = $MsolUser.IsLicensed
        If ($365User.IsLicensed) {
            $365User.Licenses  = (($MsolUser.Licenses.AccountSkuId) -join "`n")
        }

        # next check if the user is synced with AAD
        $365User.IsDirSynced = $UserMailbox.IsDirSynced

        # if they are DirSynced, get their on-premisis OU name
        If ($365User.IsDirSynced) {
            $AADUser = Get-AzureADUser -ObjectId $MsolUser.UserPrincipalName
            $365User.OrganizationalUnit = $AADUser.ExtensionProperty.onPremisesDistinguishedName
        }

        $365User.FullName  = $MsolUser.DisplayName
        $365User.FirstName  = $MsolUser.FirstName
        $365User.LastName  = $MsolUser.Lastname
        $365User.UserPrincipalName  = $MsolUser.UserPrincipalName
        $365User.EmailAddress  = $UserMailbox.PrimarySmtpAddress
        $365User.EmailAliases  = (($UserMailbox.EmailAddresses | `
          Where-Object {$_ -clike "smtp:*"} | `
          ForEach-Object {$_ -replace "smtp:",""}) -join "`n")
        $365User.ArchiveStatus  = $UserMailbox.ArchiveStatus
        $365User.WhenMailboxCreated  = $UserMailbox.WhenMailboxCreated
        $365User.Title  = $MsolUser.Title
        $365User.Department  = $AADUser.Department
        $365User.OfficeLocation  = $MsolUser.Office

        # add this 365User to 365Mailboxes array
        $365Mailboxes += $365User
    }

    Return $365Mailboxes

}

Function Get-365SharedMailboxes {

    $365SharedMailboxes = @()

    $SharedMailboxes = Get-Mailbox -RecipientTypeDetails SharedMailbox -ResultSize Unlimited

    $counter = 1
    ForEach ($SharedMailbox in $SharedMailboxes) {

        [int]$pct = (($counter / $SharedMailboxes.Count) * 100)
        $status = "$pct% Complete  [{0}`/{1}]" -f $counter, $SharedMailboxes.Count
        Write-Progress -Activity "   Gathering Shared Mailbox Details" -Status $status -PercentComplete $pct
        $counter++

        $365SharedMailbox = [SharedMailbox]::new()

        $365SharedMailbox.DisplayName = $SharedMailbox.DisplayName
        $365SharedMailbox.SamAccountName = $SharedMailbox.SamAccountName
        $365SharedMailbox.UserPrincipalName = $SharedMailbox.UserPrincipalName
        $365SharedMailbox.MailboxMembers = (($SharedMailbox | Get-MailboxPermission | `
            Select-Object User,AccessRights | `
            Where-Object {$_.User -like "*@*" } | ForEach-Object {`
                $_.User + ";" + $_.AccessRights}) -join "`n")
        $365SharedMailbox.EmailAliases = (($SharedMailbox.EmailAddresses | `
            Where-Object {$_ -clike "smtp:*"} | `
            ForEach-Object {$_ -replace "smtp:",""}) -join "`n")
        $365SharedMailbox.DisplayName = $SharedMailbox.DisplayName
        $365SharedMailbox.WhenMailboxCreatedUtc = $SharedMailbox.WhenCreatedUTC
        $365SharedMailbox.UsageLocation = $SharedMailbox.UsageLocation
        $365SharedMailbox.IsDirSynced = $SharedMailbox.IsDirSynced
        $365SharedMailbox.HiddenFromAddressLists = $SharedMailbox.HiddenFromAddressLists
        $365SharedMailbox.LitigationHoldEnabled = $SharedMailbox.LitigationHoldEnabled

        # add the mailbox to the collection
        $365SharedMailboxes += $365SharedMailbox
    }

    Return $365SharedMailboxes

}

Function Get-365DistributionGroups {

    $365DistributionGroups = @()

    # get all distro groups
    $DistributionGroups = Get-DistributionGroup -ResultSize Unlimited

    $counter = 1
    ForEach ($DistributionGroup in $DistributionGroups) {

        [int]$pct = (($counter / $DistributionGroups.Count) * 100)
        $status = "$pct% Complete  [{0}`/{1}]" -f $counter, $DistributionGroups.Count
        Write-Progress -Activity "   Gathering Distribution Group Details" -Status $status -PercentComplete $pct
        $counter++

        $365DistroGroup = [DistributionGroup]::new()

        $365DistroGroup.DisplayName = $DistributionGroup.DisplayName
        $365DistroGroup.Name = $DistributionGroup.Name
        $365DistroGroup.GroupType = $DistributionGroup.GroupType
        $365DistroGroup.IsDirSynced = $DistributionGroup.IsDirSynced
        $365DistroGroup.SamAccountName = $DistributionGroup.SamAccountName
        $365DistroGroup.PrimarySmtpAddress = $DistributionGroup.PrimarySmtpAddress
        $365DistroGroup.EmailAliases = (($DistributionGroup.EmailAddresses | `
          Where-Object {$_ -clike "smtp:*"} | `
          ForEach-Object {$_ -replace "smtp:",""}) -join "`n")
        $365DistroGroup.GroupMembers = ((Get-DistributionGroupMember $DistributionGroup.PrimarySmtpAddress `
          | Select-Object PrimarySmtpAddress).PrimarySmtpAddress -join "`n")
        $365DistroGroup.ManagedBy = $DistributionGroup.ManagedBy
        $365DistroGroup.WhenCreatedUtc = $DistributionGroup.WhenCreatedUTC

        $365DistributionGroups += $365DistroGroup

    }
    Return $365DistributionGroups
}

Function Connect-365Services {
    param ([string]$UserName)

    Write-Host "Connecting to ExchangeOnline. Please enter global admin credentials."
    If ($PSVersionTable.PSVersion.Major -eq 7) {
        Connect-ExchangeOnline -Device
    } Else {
        Connect-ExchangeOnline -UserPrincipalName $UserName -ShowBanner:$false
    }

    Write-Host "Connecting to MSOLService..."
    Connect-MsolService

    Write-Host "Connecting to Azure AD..."
    Connect-AzureAD
}

Export-ModuleMember -Function Get-365UserMailboxes, Get-365DistributionGroups, Get-365SharedMailboxes, Connect-365Services
