### Create example Customer/Token table for example
$CustomerTokenTable = @{}
100..110 | % { $CustomerTokenTable[[string]$_] = [System.Guid]::NewGuid() }

### Template for agent activation key install method data
$ActivationKeyTemplate = @{
    "Parameter"      = "AGENTACTIVATIONKEY"
    "FailedAttempts" = 0
    "Type"           = "Activation Key: Token/AppId"
    "MaxAttempts"    = 1
    "Value"          = "<base64 encoded value>"
    "Name"           = "Activation Key : Token (Current Script) / Appliance ID (Existing Installation)"
    "Attempts"       = 0
    "Failed"         = $false
    "Available"      = $true
}

### Template for registration key install method data
$RegistrationKeyTemplate = @{
    "Parameter"      = "CUSTOMERID"
    "FailedAttempts" = 0
    "Type"           = "Registration Token: CustomerId/Token"
    "MaxAttempts"    = 1
    "Value"          = "<customerid>|<token>"
    "Name"           = "Site ID/Registration Token (Current Script)"
    "Attempts"       = 0
    "Failed"         = $false
    "Available"      = $true
}

function GetCustomInstallMethods {
    # Check if the script input is not null
    if ($null -ne $Script.CustomerID) {
        # and the CustomerID is in our custom lookup table..
        if ($null -ne $CustomerTokenTable[[string]$Script.CustomerID]) {
            # Construction the RegistrationKey type activation used for replace/new install methods
            $NewMethodData = $RegistrationKeyTemplate.Clone()
            # Construct the value, for our purposes we use the | character as a delimeter between the ID and token
            $NewMethodData.Value = "$($Script.CustomerID)|$($CustomerTokenTable[[string]$Script.CustomerID])"
            # Overwrite the Method data for Method F, which is the CutomerID/Reg token from current script
            $Install.MethodData.F = $NewMethodData

            # We can also generate an activation key for upgrades
            if ($null -ne $Agent.Appliance.ID) {
                # Construction the RegistrationKey type activation used for replace/new install methods
                $NewActKeyMethodData = $ActivationKeyTemplate.Clone()
                # Insert the activation key value
                $NewActKeyMethodData.Value = NewEncodedKey -Server $Agent.Appliance.AssignedServer -ID $Agent.Appliance.ID -token ($CustomerTokenTable[[string]$Script.CustomerID]).Guid
                # Override the Method data for Method A
                $Install.MethodData.A = $NewActKeyMethodData

            }
        }
    }
}
