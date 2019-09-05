<#
    .SYNOPSIS
        Will run on-demand snapshots based on a list of VMs 
    .DESCRIPTION
        Script reads a defined text file, containing a list of VM Names. Tests for Rubrik Powershell module installation, \
        if not present attempts to install. Checks to see if credentials (encrypted) exist in directory for defined Rubrik \
        if not asks for credentials, saves them, and exits. Rerun script after defining credentials. Then will look up each \
        VM in list and queue on-demand snapshot for each, applying the defined SLA domain for retention. 
    .INPUTS
        -rubrik_host - IP or hostname to Rubrik CDM Cluster
        -vm_file - filename of text file containing list of VMs to queue snapshots
        -sla_name - SLA Domain Name to assign retention to on-demand
    .OUTPUTS
        Summary of incurred events
    .EXAMPLE
        .\on-demand.ps1 -rubrik_host amer2-rbk01.rubrikdemo.com -vm_file test.txt -sla_name Bronze
    .LINK
        None
    .NOTES
        Name:       on-demand.ps1 
        Created:    09/05/2019
        Author:     pmilano1
#>


param (
    [string]$rubrik_host = $(Read-Host -Prompt 'Input your Rubrik IP or Hostname'),
    [string]$sla_name = $(Read-Host -Prompt 'Input the SLA Domain name for retention purposes'),
    [string]$vm_file = $(Read-Host -Prompt 'Input relative path to file containing VM list')
)

$g=0
$b=0

# Check for file
if (Test-Path $vm_file){
  write-host "$vm_file is valid"
}
else{
  write-host "$vm_file cannot be opened"
  exit
}


# Check for / Install Rubrik Posh Mod
$RubrikModuleCheck = Get-Module -ListAvailable Rubrik
if ($RubrikModuleCheck -eq $null) {
    Install-Module -Name Rubrik -Scope CurrentUser -Confirm:$false
}
Import-Module Rubrik
$RubrikModuleCheck = Get-Module -ListAvailable Rubrik
if ($RubrikModuleCheck -eq $null) {
  write-host "Could not deploy Rubrik Powershell Module. Please see https://powershell-module-for-rubrik.readthedocs.io/en/latest/"
}

# Check for Credentials
$Credential = ''
$CredentialFile = "$($PSScriptRoot)\.$($rubrik_host).cred"
if (Test-Path $CredentialFile){
  write-host "Credentials found for $($rubrik_host)"
  $Credential = Import-CliXml -Path $CredentialFile
}
else {
  write-host "$($CredentialFile) not found"
  $Credential = Get-Credential -Message "Credentials not found for $($rubrik_host), please enter them now."
  $Credential | Export-CliXml -Path $CredentialFile
  exit
}

$conx = ''
try {
  $conx = (Connect-Rubrik -Server $rubrik_host -Credential $Credential)
}
catch {
  write-host "Could not log into $($rubrik_host)" 
  write-host "If bad credentials, remove $($CredentialFile) and rerun." 
}
Write-Host "Logged into $($rubrik_host)"

foreach ($r in get-content($vm_file)){
  try {
    Get-RubrikVM -Name $r | New-RubrikSnapshot -SLA $sla_name -Confirm:$false | Out-Null
    write-host "$($r) - On Demand Queued"
    $g++
  }
  catch{
    write-host "Failed to initiate snapshot of $($r)"
    $b++
  }
}

write-host "Queued $($g) on-demand snapshot(s)"
if ($b){
  write-host "Failed to Queue $($b) on-demand snapshot(s)"
}
exit
