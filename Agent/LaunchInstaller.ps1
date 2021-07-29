param (
    [Switch]$Monitor
)
### 1.0.0 on 2021-02-21 - David Brooks, Premier Technology Solutions
### 1.0.1 on 2021-03-23 - Robby Swartenbroekx, b-inside bv
####################################################################
# - Adapted updated Batch file version of InstallAgent to PowerShell
Write-Host "CustomerID: $($args[0])" -ForegroundColor Green
Write-Host "Token: $($args[1])" -ForegroundColor Green
$CustomerID = $args[0]
$RegistrationToken = $args[1]
Write-Host "Monitor switch is present: $($Monitor.IsPresent)"

# - Launcher Script Name
$LauncherScript = "Agent Setup PS Launcher"
# - Setup Script Name
$SetupScript = "Agent Setup PS Script"
if (-not [System.Diagnostics.EventLog]::SourceExists($LauncherScript)) {
    New-EventLog -Source $LauncherScript -LogName Application
}

# Device Info Table
$Device = @{}
#Get OS version information from WMI
$WMIos = Get-WmiObject Win32_OperatingSystem
[Version] $Device.OSBuild =
if ($null -eq $WMIos.Version)
#If unable to retrieve from WMI, get from CIM
{ (Get-CimInstance Win32_OperatingSystem).Version }
else
{ $WMIos.Version }
# Operating System Architecture
if ($Device.OSBuild -lt "6.1") {
    Write-Host "OS Not Compatible with either the Agent or the $SetupScript" -ForegroundColor Red
    Write-EventLog -EntryType Error -EventId 13 -LogName Application -Source $LauncherScript -Message  "The OS is not compatible with the N-Central Agent or the $SetupScript." > $null
    Exit 2
}

# Attempt to create local cache folder for InstallAgent
$TempFolder = "$env:windir\Temp\AGPO"
if (!(Test-Path $TempFolder)) {
    New-Item $TempFolder -ItemType Directory -Force > $Null
    if (!$?) {
        Write-Host "Unable to create temp folder" -ForegroundColor Red
        Write-EventLog -EntryType Error -EventId 13 -LogName Application -Source $LauncherScript -Message  "$SetupScript is unable to create temp folder in $TempFolder for install" > $null
        Exit 2
    }
}
# Copy contents to local cache folder
$DeployFolder = "$(Split-Path $MyInvocation.MyCommand.Path -Parent)"
Write-Host "Copying $DeployFolder to local cache in $TempFolder"
Copy-Item "$DeployFolder\*" "$TempFolder\" -Recurse -Force
Write-Host "Number of Arguments $($args.Count)"
switch ($args.Count) {
    0 {
        # Only PartnerConfig.xml values will be used
        Write-Host "Launching with no parameters" -ForegroundColor Green
        $p = Start-Process -FilePath "$env:windir\System32\WindowsPowerShell\v1.0\powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -NoLogo -NoProfile -WindowStyle Hidden -File $TempFolder\InstallAgent.ps1 -LauncherPath $DeployFolder\" -PassThru
        break
    }
    1 {        
        # CustomerID from script parameter has preference over PartnerConfig.xml, will failback to PartnerConfig.xml
        Write-Host "Launching with CustomerID" -ForegroundColor Green
        $p = Start-Process -FilePath "$env:windir\System32\WindowsPowerShell\v1.0\powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -NoLogo -NoProfile -WindowStyle Hidden -File $TempFolder\InstallAgent.ps1 -CustomerID $CustomerID -LauncherPath $DeployFolder\" -PassThru
        break
    }
    2 {
        # Partner token from script parameter has preference over PartnerConfig.xml, will failback to partnerconfig.xml
        Write-Host "Launching with CustomerID and Token" -ForegroundColor Green
        $p = Start-Process -FilePath "$env:windir\System32\WindowsPowerShell\v1.0\powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -NoLogo -NoProfile -WindowStyle Hidden -File $TempFolder\InstallAgent.ps1 -CustomerID $CustomerID -RegistrationToken $RegistrationToken -LauncherPath $DeployFolder\" -PassThru
        break
    }
}
# Successfully launched...

if ($null -eq $p) {
    Write-EventLog -EntryType Error -EventId 13 -LogName Application -Source $LauncherScript -Message  "$SetupScript encountered an error starting the launcher" > $null
    Exit 2
}
else {
    Write-Host "Successfully launched $TempFolder\InstallAgent.ps1 with $($args.Count) arguments" -ForegroundColor Green
    Write-EventLog -EntryType Information -EventId 10 -LogName Application -Source $LauncherScript -Message  "Successfully launched $TempFolder\InstallAgent.ps1 with $($args.Count) arguments" > $null

    if ($Monitor.IsPresent) {
        
        Write-Host "Launched InstallAgent with PID: $($p.Id), waiting on Exit"
        $RegPaths = @{
            Summary      = "HKLM:\SOFTWARE\N-able Community\InstallAgent"
            Installation = "HKLM:\SOFTWARE\N-able Community\InstallAgent\Installation"
            Diagnosis    = "HKLM:\SOFTWARE\N-able Community\InstallAgent\Diagnosis"
        }

        while (-not $p.HasExited) {
                Start-Sleep 1
                Clear-Host
                if (Test-Path $RegPaths.Summary) {
                    Write-Host "Progress: " -ForegroundColor Green -NoNewline
                    Get-ItemProperty $RegPaths.Summary | Select-Object * -ExcludeProperty PS* | Format-List *
                }
        }
        if ($p.ExitCode -eq 0) {
            Write-Host "Script ran successfully, displaying registry results:" -ForegroundColor Green
            $RegPaths.Keys | ForEach-Object { 
                if (Test-Path $RegPaths[$_]) {
                    Write-Host "$($_): " -ForegroundColor Green -NoNewline;
                    Get-ItemProperty $RegPaths[$_] | Select-Object * -ExcludeProperty PS* | Format-List *
                }
            }
            Write-Host "Check logs for additional details"
        }
        else {
            Write-Host "Script ran successfully, displaying registry results:"
            $RegPaths.Keys | ForEach-Object { 
                if (Test-Path $RegPaths[$_]) {
                    Write-Host "$($_): " -ForegroundColor Green -NoNewline;
                    Get-ItemProperty $RegPaths[$_] | Select-Object * -ExcludeProperty PS* | Format-List *
                }
            }
            Write-Host "Check logs for additional details"
            Write-EventLog -EntryType Error -EventId 13 -LogName Application -Source $LauncherScript -Message  "$SetupScript encountered an error starting the launcher" > $null
        }

    }
}
