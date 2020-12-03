<#
.SYNOPSIS
    Invoke-StartService - Start all essential services that are not running.
.DESCRIPTION
    This script finds non-running services that are set to start automatically, and starts them.
.NOTES
    File Name: Start-Service.ps1
    Author: Karl Mitschke
    Requires: Powershell V2
    Created:  11/03/2011
.EXAMPLE
Invoke-StartService
Description
-----------
Starts services on the local machine that are set to start automatically.
.EXAMPLE
C:\PS> Invoke-StartService -Computer Exch2010
Description
-----------
Starts services on the computer Exch2010 that are set to start automatically.
.EXAMPLE
C:\PS> Get-ExchangeServer | Invoke-StartService -WhatIf
Description
-----------
Displays services on all Exchange servers which are currently stopped and are set to start automatically.
Remove the WhatIf parameter to start the services.
.EXAMPLE
C:\PS> $cred = Get-Credential -Credential mitschke\karlm
C:\PS> Invoke-StartService.ps1 -ComputerName (Get-Content -Path ..\Servers.txt) -Credential $cred -WhatIf
Description
-----------
Displays services on all servers in the file Servers.txt which are currently stopped and are set to start automatically.
Remove the WhatIf parameter to start the services.
.PARAMETER ComputerName
    The Computer(s) to start services on. If not specified, defaults to the local computer.
.PARAMETER Credential
    The Credential to use. If not specified, runs under the current security context.
#>

[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
param (
[Parameter(
Position = 0,
ValueFromPipeline=$true,
Mandatory = $false
)]
[string[]]$ComputerName = $env:ComputerName,
[Parameter(
Position = 1,
Mandatory = $false
)]
$Credential
)

BEGIN{
#region PSBoundParameters modification
if ($Credential -ne $null -and $Credential.GetType().Name -eq "String"){
$PSBoundParameters.Remove("Credential") | Out-Null
$PSBoundParameters.Add("Credential", (Get-Credential -Credential $Credential))
}
$PSBoundParameters.Remove("WhatIf") | Out-Null
#endregion
#region Return Codes
$ReturnCode = @{}
$ReturnCode.Add(0,"Success")
$ReturnCode.Add(1,"Not Supported")
$ReturnCode.Add(2,"Access Denied")
$ReturnCode.Add(3,"Dependent Services Running")
$ReturnCode.Add(4,"Invalid Service Control")
$ReturnCode.Add(5,"Service Cannot Accept Control")
$ReturnCode.Add(6,"Service Not Active")
$ReturnCode.Add(7,"Service Request Timeout")
$ReturnCode.Add(8,"Unknown Failure")
$ReturnCode.Add(9,"Path Not Found")
$ReturnCode.Add(10,"Service Already Running")
$ReturnCode.Add(11,"Service Database Locked")
$ReturnCode.Add(12,"Service Dependency Deleted")
$ReturnCode.Add(13,"Service Dependency Failure")
$ReturnCode.Add(14,"Service Disabled")
$ReturnCode.Add(15,"Service Logon Failure")
$ReturnCode.Add(16,"Service Marked For Deletion")
$ReturnCode.Add(17,"Service No Thread")
$ReturnCode.Add(18,"Status Circular Dependency")
$ReturnCode.Add(19,"Status Duplicate Name")
$ReturnCode.Add(20,"Status Invalid Name")
$ReturnCode.Add(21,"Status Invalid Parameter")
$ReturnCode.Add(22,"Status Invalid Service Account")
$ReturnCode.Add(23,"Status Service Exists")
$ReturnCode.Add(24,"Service Already Paused")
#endregion
#region Splatting
$Class = @{
Class = "Win32_Service"
}
$FindFilter = @{
Filter = "startmode='auto' and state<>'running' and (name > 'clra' or name < 'clr')"
}
#endregion
}
PROCESS {
#region Do the work
try
{
foreach ($Service in Get-WmiObject @Class @FindFilter @PSBoundParameters){
$StartFilter = @{
Filter = "Name = '$($Service.Name)'"
}
switch ((Get-WmiObject @Class @StartFilter).State){
Paused {$Action = "ResumeService()";$Verb = "Resuming";Break}
Stopped {$Action = "StartService()";$Verb = "Starting";Break}
Unknown {$Action = "InterrogateService()";$Verb = "Interrogating";Break}
Running {$Action = "InterrogateService()";$Verb = "Interrogating";Break}
"Start Pending" {$Action = "InterrogateService()";$Verb = "Interrogating";Break}
"Stop Pending" {$Action = "InterrogateService()";$Verb = "Interrogating";Break}
"Continue Pending" {$Action = "InterrogateService()";$Verb = "Interrogating";Break}
"Pause Pending" {$Action = "InterrogateService()";$Verb = "Interrogating";Break}
}
if ($pscmdlet.ShouldProcess($($Service.__SERVER), "$Verb service '$($Service.DisplayName)'")){
$Result = $null
$Command = "(Get-WmiObject @Class @StartFilter @PSBoundParameters).$Action"
[int32]$Result = (Invoke-Expression -Command $Command).ReturnValue
switch ($Result){
0 {Write-Output "$($Verb.Replace("ing","ed")) service '$($Service.DisplayName)' on $($Service.__SERVER)"; break}
default {Write-Error -Message "Error $($Verb) service '$($Service.DisplayName)' on $($Service.__SERVER). Error: $($ReturnCode[$Result])."}
}
}
}
}
catch{
Write-Error "Error trying to connect and retrieve services from $ComputerName"
}
#endregion
}