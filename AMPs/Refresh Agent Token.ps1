# AMPLified version of AME-Justin's token refresh script as inspired by Chris Reid, by David Brooks
# Version 1.0.0
# Note: Requires following NC Role permissions
# > Devices -> Network Devices -> Edit Device Settings [Read Only]
# > Devices -> Network Devices -> Registration Tokens [Manage]

<#region Input Parameters used in AMP:
 $username
 $password
 $serverHost
 $expirationTolerance
 $JWT
#>

# Generate a pseudo-unique namespace to use with the New-WebServiceProxy and associated types.
$NWSNameSpace = "NAble" + ([guid]::NewGuid()).ToString().Substring(25)
$KeyPairType = "$NWSNameSpace.eiKeyValue"

# Bind to the namespace, using the Webserviceproxy
$bindingURL = "https://" + $serverHost + "/dms2/services2/ServerEI2?wsdl"
$nws = New-Webserviceproxy $bindingURL -Namespace ($NWSNameSpace)

# Set up and execute the query
$KeyPair = New-Object -TypeName $KeyPairType
$KeyPair.Key = 'listSOs'
$KeyPair.Value = "false"

#Attempt to connect
Try {
    $CustomerList = $nws.customerList("", $JWT, $KeyPair)
}
Catch {
    Write-Host "Could not connect: $($_.Exception.Message)"
    exit
}

#Create customer report ArrayList
$Customers = New-Object System.Collections.ArrayList
ForEach ($Entity in $CustomerList) {
    $CustomerAssetInfo = @{}
    ForEach ($item in $Entity.items) { $CustomerAssetInfo[$item.key] = $item.Value }
    $o = [PSCustomObject]@{
        CustomerID                  = $CustomerAssetInfo["customer.customerid"]
        Name                        = $CustomerAssetInfo["customer.customername"]
        ParentID                    = $CustomerAssetInfo["customer.parentid"]
        RegistrationToken           = $CustomerAssetInfo["customer.registrationtoken"]
        RegistrationTokenExpiryDate = $CustomerAssetInfo["customer.registrationtokenexpirydate"]
    }
    $Customers.Add($o) > $null
}

$SecurePass = ConvertTo-SecureString $password -AsPlainText -Force
$PSUserCredential = New-Object PSCredential ($username, $SecurePass)
$date = Get-Date

function updatetoken($customer) {
    $uri = "https://$serverHost/dms/FileDownload?customerID=$($customer.customerid)&softwareID=101"
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $uri -UseBasicParsing -Credential $PSUserCredential | Out-Null
}
foreach ($customer in $customers) {
    if (-not ($customer.registrationtokenexpirydate)) {
        #No Registration Token
        updatetoken($customer)
    }
    #Expires soon
    else {
        $expirationdate = [datetime]::ParseExact(($customer.registrationtokenexpirydate).split(" ")[0], 'yyyy-MM-dd', $null)
        if ($expirationdate -lt $date.AddDays($expirationTolerance)) {
            updatetoken($customer)
        }
    }
}