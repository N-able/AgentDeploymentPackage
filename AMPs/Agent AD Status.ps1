#region AMP startup variable. This region isn't in the the AMP itself.
$NetworkFolder = "Agent"
$GPOName = "n-able - Install Agent (PS)"
$NetLogonShare = "C:\Windows\SYSVOL\domain\scripts" # This is gathered inside the AMP
#endregion

$PartnerConfigFile = $NetLogonShare + "\" + $NetworkFolder + "\PartnerConfig.xml"

Try {
    [xml]$PCXml = Get-Content -Path $PartnerConfigFile
    $PartnerConfigFileVersion = $PCXml.Config.Version
    $NCentralVersion = $PCXml.config.Deployment.Typical.SOAgentVersion
    $InstallationFile = Try {
        $NCentralFileVersion = $PCXml.config.Deployment.Typical.SOAgentFileVersion
        $SOFileVersion = [System.Diagnostics.FileVersionInfo]::GetVersionInfo("$NetLogonShare\$NetworkFolder\$($PCXml.config.Deployment.Typical.InstallFolder)\$($PCxml.Config.Deployment.Typical.SOAgentFileName)").FileVersion
        if ($NCentralFileVersion -eq "$SOFileVersion.0") { "INFO: File version OK" } else { "ERROR: Wrong Installer File" }
    }
    Catch {
        "ERROR: $($PCxml.Config.Deployment.Typical.SOAgentFileName) file not found"
    }
    $CustomerId = $PCXml.Config.Deployment.Typical.CustomerId
    $RegistrationToken = if ($PCXml.Config.Deployment.Typical.RegistrationToken) { "INFO: Present" } else { "ERROR: Registration token missing" }
}
Catch {
    $PartnerConfigFileVersion = "ERROR: PartnerConfig.xml file not found"
    $NCentralVersion = "ERROR: PartnerConfig.xml file not found"
    $InstallationFile = "ERROR: PartnerConfig.xml file not found"
    $CustomerID = 0
    $RegistrationToken = "ERROR: PartnerConfig.xml file not found"
}

$OSVersion = [system.environment]::OSVersion.Version
$GPOInstalled = if (($OSVersion.Major -eq 10) -or (($OSVersion.Major -eq 6) -and ($OSVersion.Minor -ge 2))) {
    (get-gpo -name $GPOName -ErrorAction ignore).Count
}
else {
    -1
}