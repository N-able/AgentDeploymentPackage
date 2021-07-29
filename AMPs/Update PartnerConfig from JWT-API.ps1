<#
### Script of unknown origin, modified to work with 2020.
.SYNOPSIS
This script is used to update the PartnerConfig.xml used by the InstallAgent for N-Central

.DESCRIPTION
This script is used to update the PartnerConfig.xml used by the InstallAgent for N-Central, it achieves this by:
- Pulls the Customer ID from the Agent Maintenance service, if that fails...
- - Pulls local details about the NC server and appliance ID, then retrieves the CustomerID from the NC API
- Uses the Customer ID to retrieve the Customer agent token using the NC API

The script is intended to be run from within an AMP, and the AMP passes through the following variables associated the the following sections of the PartnerConfig.xml:
> Branding 
$Branding = "My MSP @ MSP.com"

> Deployment
$LocalFolder ""
$NetworkFolder 

> Typical
$SOAgentFileName
$SOAgentVersion
$SOAgentFileVersion

>AzNableProxy service by Kelvin Tegelaar
>Azure is the more secure way to pass the Registration token. Check Kelvin's AzNableProxy https://github.com/KelvinTegelaar/AzNableProxy

$AzNableProxyUri
$AzNableAuthCode

#>

### Begin Code

# Get the path based on the NetLogon share
$NetLogonShare = (get-smbshare -name NetLogon -ErrorAction SilentlyContinue).Path
# Failsafe to try it with a hardcoded version if no NetLogon share is found
If (-not $NetLogonShare) { $NetLogonShare = "C:\Windows\SYSVOL\domain\scripts" }
$PartnerConfigFile = $NetLogonShare + "\" + $NetworkFolder + "\PartnerConfig.xml"

### Method 1 of retrieving CustomerID from AgentMaintenanceSchedules.xml
### Method 1 credited to Prejay of Doherty.

# Set CustomerId to -1, we can use this later to check if there is an issue with the provided Id or it wans't provided
$CustomerId = -1

$AgentMaintenanceSchedulesConfig = ("{0}\N-able Technologies\Windows Agent\config\AgentMaintenanceSchedules.xml" -f ${Env:ProgramFiles(x86)})
if (Test-Path $AgentMaintenanceSchedulesConfig) {
    $AgentMaintenanceSchedulesXML = [xml](Get-Content -Path $AgentMaintenanceSchedulesConfig)
    $RebootMessagelogoURL = $AgentMaintenanceSchedulesXML.AgentMaintenanceSchedules.rebootmessagelogourl
    $CustomerID = [Regex]::Matches($RebootMessagelogoURL, '(?<=\=)(.*?)(?=&)').Value
}

# Get nCentral Server based on the installed agent
$AgentConfigFolder = (Get-WmiObject win32_service -filter "Name like 'Windows Agent Service'").PathName
$AgentConfigFolder = $AgentConfigFolder.Replace("bin\agent.exe", "config").Replace('"', '')
$ServerConfigXML = [xml](Get-Content "$AgentConfigFolder\ServerConfig.xml")
$serverHost = $ServerConfigXML.ServerConfig.ServerIP

### Setup connection to NC Webproxy namespace, this will be used later for NC API calls
$NWSNameSpace = "NAble" + ([guid]::NewGuid()).ToString().Substring(25)
$KeyPairType = "$NWSNameSpace.EiKeyValue"

$bindingURL = "https://" + $serverHost + "/dms2/services2/ServerEI2?wsdl"
$nws = New-Webserviceproxy $bindingURL -Namespace ($NWSNameSpace)

### JWT
#$JWT = "Very long string"

### Method 2 of obtaining customer ID
### Method 2 provied by Robby S, b-inside
if ($CustomerId -eq -1) {
    # Determine who we are
    $ApplianceConfigXML = [xml](Get-Content "$Script:AgentConfigFolder\ApplianceConfig.xml")
    $applianceID = $ApplianceConfigXML.ApplianceConfig.ApplianceID

    # Setup Keypairs array and Keypair object with search params for deviceGet method used against the NC server
    $KeyPairs = @()
    $KeyPair = New-Object -TypeName $KeyPairType
    $KeyPair.Key = 'applianceID'
    $KeyPair.Value = $applianceID
    $KeyPairs += $KeyPair
    $rc = $nws.deviceGet("", $JWT, $KeyPairs)
    Write-Host "nCentral Server = "($serverHost) 
    try {
        $CustomerId = ($rc[0].info | ForEach-Object { if ($_.key -eq "device.customerid") { $_.Value } })
    }
    catch {
        Write-Host "Could not connect: $($_.Exception.Message)"
        exit
    }
    write-host "CustomerId = $CustomerId"
}

$badCustomerIds = @(-1, "-1", "", $null)
if ($badCustomerIds -contains $CustomerId) {
    Write-Host "Unable to retrieve valid CustomerID, exiting"
    Exit 2
}

### Now we gather the token from the N-Central server using the provided information
# Code snippet credit goes to Chris Reid, Jon Czerwinski and Kelvin Telegaar

# Set up and execute the query
$KeyPair = New-Object -TypeName $KeyPairType
$KeyPair.Key = 'listSOs'
$KeyPair.Value = "False"
Try {
    $CustomerList = $nws.customerList("", $JWT, $KeyPair)
}
Catch {
    Write-Host "Could not connect: $($_.Exception.Message)"
    exit
}

$found = $False
$rowid = 0
While ($rowid -lt $CustomerList.Count -and $found -eq $False) {
    If ($customerlist[$rowid].items[0].Value -eq [int]$CustomerID) {
        Foreach ($rowitem In $CustomerList[$rowid].items) {
            If ($rowitem.key -eq "customer.registrationtoken") {
                $RetrievedRegistrationToken = $rowitem.value
                If ($RetrievedRegistrationToken -eq "") {
                    Write-Host "Note that a valid Registration Token was not returned even though the customer was found. This happens when an agent install has never been downloaded for that customer. Try to download an agent from the N-Central UI and run this script again"
                }
            }
        }
    }
    $rowid++
}

Write-Host "Here is the registration token for CustomerID" $CustomerID":" $RetrievedRegistrationToken -ForegroundColor Green

# Refresh Partner XML
if (Test-Path $PartnerConfigFile) {
    [xml]$xmlDocument = Get-Content -Path $PartnerConfigFile

    # Branding
    $xmlDocument.Config.Branding.ErrorContactInfo = $Branding

    # Server
    $xmlDocument.Config.Server.NCServerAddress = $serverHost

    ### Deployment
    # LocalFolder, NetworkFolder
    $xmlDocument.Config.Deployment.LocalFolder = $LocalFolder
    $xmlDocument.Config.Deployment.NetworkFolder = $NetworkFolder

    # Typical
    $xmlDocument.Config.Deployment.Typical.SOAgentFileName = $SOAgentFileName
    $xmlDocument.Config.Deployment.Typical.SOAgentVersion = $SOAgentVersion
    $xmlDocument.Config.Deployment.Typical.SOAgentFileVersion = $SOAgentFileVersion
    # (Customer ID and Token)
    $xmlDocument.Config.Deployment.Typical.CustomerId = $CustomerId
    $xmlDocument.Config.Deployment.Typical.RegistrationToken = $RetrievedRegistrationToken

    # AzNableProxy service by Kelvin Tegelaar
    # Azure is the more secure way to pass the Registration token. Check Kelvin's AzNableProxy https://github.com/KelvinTegelaar/AzNableProxy 
    $xmlDocument.Config.Deployment.Typical.AzNableProxyUri = $AzNableProxyUri
    $xmlDocument.Config.Deployment.Typical.AzNableAuthCode = $AzNableAuthCode

    $xmlDocument.Save($PartnerConfigFile)
    Write-Host "Saving Config to $PartnerConfigFile"
}
else {
    Write-Host "Unable to find PartnerConfig file!"
}
