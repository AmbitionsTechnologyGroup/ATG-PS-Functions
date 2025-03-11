function Update-CloudflareDnsRecord {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, HelpMessage = "Which IP should be used for the record: internal/external")]
        [ValidateSet("internal", "external")]
        [string]$WhatIp,

        [Parameter(Mandatory = $true, HelpMessage = "DNS A record to be updated")]
        [string]$DnsRecord,

        [Parameter(Mandatory = $true, HelpMessage = "Cloudflare's Zone ID")]
        [string]$ZoneId,

        [Parameter(Mandatory = $true, HelpMessage = "Cloudflare Zone API Token")]
        [string]$CloudflareZoneApiToken,

        [Parameter(HelpMessage = "Use Cloudflare proxy on dns record true/false")]
        [bool]$Proxied = $false,

        [Parameter(HelpMessage = "TTL in seconds (120-7200) or 1 for Auto")]
        [ValidateScript({($_ -ge 120 -and $_ -le 7200) -or $_ -eq 1})]
        [int]$Ttl = 120,

        [Parameter(HelpMessage = "Telegram Notifications (yes/no)")]
        [ValidateSet("yes", "no")]
        [string]$NotifyMeTelegram = "no",

        [Parameter(HelpMessage = "Telegram Chat ID")]
        [string]$TelegramChatId = "",

        [Parameter(HelpMessage = "Telegram Bot API Key")]
        [string]$TelegramBotAPIToken = "",

        [Parameter(HelpMessage = "Discord Server Notifications (yes/no)")]
        [ValidateSet("yes", "no")]
        [string]$NotifyMeDiscord = "no",

        [Parameter(HelpMessage = "Discord Webhook URL")]
        [string]$DiscordWebhookURL = ""
    )

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    ### updateDNS.log file of the last run for debug
    $File_LOG = "$PSScriptRoot\update-cloudflare-dns.log"
    $FileName = "update-cloudflare-dns.log"

    if (!(Test-Path $File_LOG)) {
        New-Item -ItemType File -Path $PSScriptRoot -Name ($FileName) | Out-Null
    }

    Clear-Content $File_LOG
    $DATE = Get-Date -UFormat "%Y/%m/%d %H:%M:%S"
    Write-Output "==> $DATE" | Tee-Object $File_LOG -Append

    ### Check if set to internal ip and proxy
    if (($WhatIp -eq "internal") -and ($Proxied)) {
        Write-Output 'Error! Internal IP cannot be Proxied' | Tee-Object $File_LOG -Append
        return
    }

    ### Get External ip from https://checkip.amazonaws.com
    if ($WhatIp -eq 'external') {
        $ip = (Invoke-RestMethod -Uri "https://checkip.amazonaws.com" -TimeoutSec 10).Trim()
        if (!([bool]$ip)) {
            Write-Output "Error! Can't get external ip from https://checkip.amazonaws.com" | Tee-Object $File_LOG -Append
            return
        }
        Write-Output "==> External IP is: $ip" | Tee-Object $File_LOG -Append
    }

    ### Get Internal ip from primary interface
    if ($WhatIp -eq 'internal') {
        $ip = $((Find-NetRoute -RemoteIPAddress 1.1.1.1).IPAddress|out-string).Trim()
        if (!([bool]$ip) -or ($ip -eq "127.0.0.1")) {
            Write-Output "==>Error! Can't get internal ip address" | Tee-Object $File_LOG -Append
            return
        }
        Write-Output "==> Internal IP is $ip" | Tee-Object $File_LOG -Append
    }

    ### Get IP address of DNS record from 1.1.1.1 DNS server when proxied is "false"
    if ($Proxied -eq $false) {
        $dns_record_ip = (Resolve-DnsName -Name $DnsRecord -Server 1.1.1.1 -Type A | Select-Object -First 1).IPAddress.Trim()
        if (![bool]$dns_record_ip) {
            Write-Output "Error! Can't resolve the ${DnsRecord} via 1.1.1.1 DNS server" | Tee-Object $File_LOG -Append
            return
        }
        $is_proxed = $Proxied
    }

    ### Get the dns record id and current proxy status from cloudflare's api when proxied is "true"
    if ($Proxied -eq $true) {
        $dns_record_info = @{
            Uri     = "https://api.cloudflare.com/client/v4/zones/$ZoneId/dns_records?name=$DnsRecord"
            Headers = @{"Authorization" = "Bearer $CloudflareZoneApiToken"; "Content-Type" = "application/json" }
        }
        
        $response = Invoke-RestMethod @dns_record_info
        if ($response.success -ne "True") {
            Write-Output "Error! Can't get dns record info from cloudflare's api" | Tee-Object $File_LOG -Append
        }
        $is_proxed = $response.result.proxied
        $dns_record_ip = $response.result.content.Trim()
    }

    ### Check if ip or proxy have changed
    if (($dns_record_ip -eq $ip) -and ($is_proxed -eq $Proxied)) {
        Write-Output "==> DNS record IP of $DnsRecord is $dns_record_ip, no changes needed. #Exiting..." | Tee-Object $File_LOG -Append
        return
    }

    Write-Output "==> DNS record of $DnsRecord is: $dns_record_ip. Trying to update..." | Tee-Object $File_LOG -Append

    ### Get the dns record information from cloudflare's api
    $cloudflare_record_info = @{
        Uri     = "https://api.cloudflare.com/client/v4/zones/$ZoneId/dns_records?name=$DnsRecord"
        Headers = @{"Authorization" = "Bearer $CloudflareZoneApiToken"; "Content-Type" = "application/json" }
    }

    $cloudflare_record_info_resposne = Invoke-RestMethod @cloudflare_record_info
    if ($cloudflare_record_info_resposne.success -ne "True") {
        Write-Output "Error! Can't get $DnsRecord record inforamiton from cloudflare API" | Tee-Object $File_LOG -Append
        return
    }

    ### Get the dns record id from response
    $dns_record_id = $cloudflare_record_info_resposne.result.id.Trim()

    ### Push new dns record information to cloudflare's api
    $update_dns_record = @{
        Uri     = "https://api.cloudflare.com/client/v4/zones/$ZoneId/dns_records/$dns_record_id"
        Method  = 'PUT'
        Headers = @{"Authorization" = "Bearer $CloudflareZoneApiToken"; "Content-Type" = "application/json" }
        Body    = @{
            "type"    = "A"
            "name"    = $DnsRecord
            "content" = $ip
            "ttl"     = $Ttl
            "proxied" = $Proxied
        } | ConvertTo-Json
    }

    $update_dns_record_response = Invoke-RestMethod @update_dns_record
    if ($update_dns_record_response.success -ne "True") {
        Write-Output "Error! Update Failed" | Tee-Object $File_LOG -Append
        return
    }

    Write-Output "==> Success!" | Tee-Object $File_LOG -Append
    Write-Output "==> $DnsRecord DNS Record Updated To: $ip, ttl: $Ttl, proxied: $Proxied" | Tee-Object $File_LOG -Append

    if ($NotifyMeTelegram -eq "yes" -And $TelegramChatId -ne "" -And $TelegramBotAPIToken -ne "") {
        $telegram_notification = @{
            Uri    = "https://api.telegram.org/bot$TelegramBotAPIToken/sendMessage?chat_id=$TelegramChatId&text=$DnsRecord DNS Record Updated To: $ip"
            Method = 'GET'
        }
        $telegram_notification_response = Invoke-RestMethod @telegram_notification
        if ($telegram_notification_response.ok -ne "True") {
            Write-Output "Error! Telegram notification failed" | Tee-Object $File_LOG -Append
        }
    }

    if ($NotifyMeDiscord -eq "yes" -And $DiscordWebhookURL -ne "") { 
        $discord_message = "$DnsRecord DNS Record Updated To: $ip (was $dns_record_ip)" 
        $discord_payload = [PSCustomObject]@{content = $discord_message} | ConvertTo-Json
        $discord_notification = @{
            Uri    = $DiscordWebhookURL
            Method = 'POST'
            Body = $discord_payload
            Headers = @{ "Content-Type" = "application/json" }
        }
        try {
            Invoke-RestMethod @discord_notification
        } catch {
            Write-Host "==> Discord notification request failed. Here are the details for the exception:" | Tee-Object $File_LOG -Append
            Write-Host "==> Request StatusCode:" $_.Exception.Response.StatusCode.value__ | Tee-Object $File_LOG -Append
            Write-Host "==> Request StatusDescription:" $_.Exception.Response.StatusDescription | Tee-Object $File_LOG -Append
        }
    }
}