function ReadKey {
    ### Parameters
    ###############################
    param ($Key)
    ### Function Body
    ###############################
    # Test if the Key if Missing if so return $null
    if ((Test-Path $Key) -eq $false)
    { $null } 
    else {
        Get-ItemProperty $Key | Select-Object * -ExcludeProperty PS*
    }
}

$AgentRegPath = "HKLM:\SOFTWARE\N-Able Community\InstallAgent"
$OldAgentRegPath = "HKLM:\SOFTWARE\SolarWinds MSP Community\InstallAgent"
if (Test-Path $AgentRegPath){
    $Path = $AgentRegPath 
} else {
    $Path = $OldAgentRegPath 
}

$InstallAgentResults = ReadKey $Path

# These value is almost always present
$AgentLastDiagnosed = if ($null -ne $InstallAgentResults.AgentLastDiagnosed) { $InstallAgentResults.AgentLastDiagnosed }else { Get-Date 1900 }

# This value is present if the script has installed or upgraded at some point
$AgentLastInstalled = if ($null -ne $InstallAgentResults.AgentLastInstalled) { $InstallAgentResults.AgentLastInstalled } else { Get-Date 1900 }

# These values are always present
$ScriptAction = if ($null -ne $InstallAgentResults.ScriptAction) { $InstallAgentResults.ScriptAction } else { '-' }
$ScriptExitCode = if ($null -ne $InstallAgentResults.ScriptExitCode) { $null -ne $InstallAgentResults.ScriptExitCode } else { 404 }
$ScriptLastRan = if ($null -ne $InstallAgentResults.ScriptLastRan) { $InstallAgentResults.ScriptLastRan } else { Get-Date 1900 }
$ScriptMode = if ($null -ne $InstallAgentResults.ScriptMode) { $InstallAgentResults.ScriptMode } else { '-' }
$ScriptResult = if ($null -ne $InstallAgentResults.ScriptResult) { $InstallAgentResults.ScriptSequence } else { '-' }
$ScriptSequence = if ($null -ne $InstallAgentResults.ScriptSequence) { $InstallAgentResults.ScriptSequence } else { '-' }
$ScriptVersion = if ($null -ne $InstallAgentResults.ScriptVersion) { [int]$InstallAgentResults.ScriptVersion.Replace('.', '') } else { 404 }