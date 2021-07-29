# Core Functions for the Agent Setup Script (InstallAgent.ps1)
# Last Revised:   2021-03-23
# Module Version: 6.0.1

### INITIALIZATION FUNCTIONS
###############################

function DebugGetMethods {
    ### Function Body
    ###############################
    ### This function is not used during normal script operation, it is used for the validation during development
    # Provides a Gridview of the install methods hashtable
    $paramOrder = @(
        @{n = 'Key'; e = { $key } },
        @{n = 'Name'; e = { $_.Name } },        
        #@{n = 'Parameter'; e = { $_.Parameter } },
        @{n = 'Available'; e = { $_.Available } },
        @{n = 'Failed'; e = { $_.Failed } },
        @{n = 'Value'; e = { $_.Value } },
        @{n = 'Token'; e = { $_.Token } },
        @{n = 'Type'; e = { $_.Type } },
        @{n = 'Attempts'; e = { $_.Attempts } },
        @{n = 'MaxAttempts'; e = { $_.MaxAttempts } }
    )
    $Install.MethodData.Keys | ForEach-Object { $key = $_; $Install.MethodData[$_] | ForEach-Object { [PSCustomObject]$_ } } | Select-Object $paramOrder | Sort-Object Key | Out-GridView
}

function DebugGetAppliance {
    ### Function Body
    ###############################
    ### This function is not used during normal script operation, it is used for the validation during development
    # Provides a Gridview of the installed agent and historicall installs
    $paramOrder = @(
        @{n = 'Key'; e = { $key } },
        @{n = 'ID'; e = { $_.ID } },
        @{n = 'WindowsVersion'; e = { $_.WindowsVersion } },
        @{n = 'Version'; e = { $_.Version } },
        @{n = 'SiteID'; e = { $_.SiteID } },
        @{n = 'AssignedServer'; e = { $_.AssignedServer } },
        @{n = 'LastInstall'; e = { $_.LastInstall } },
        @{n = 'ActivationKey'; e = { $_.ActivationKey } }
    )

    $keys = @("Appliance", "History")
    $
    
    Agent.Keys | Where-Object { $keys -contains $_ } | ForEach-Object { $key = $_; $Agent[$_] } | ForEach-Object { [PSCustomObject]$_ } | Select-Object $paramOrder | Sort-Object Key | Out-GridView
}

function DebugGetProxyTokens {
    ### Function Body
    ###############################
    ### This function is not used during normal script operation, it is used for the validation during development
    # Function submits all CustomerIDs through the RequestAzWebProxyToken function to retrieve the registration token
    # Note this updates the InstallMethod.Value param, so it may prevent further execution depend on debug point
    # To reset, use DiagnoseAgent and GetInstallMethods functions
    $SC.InstallMethods.UsesAzProxy.Keys | ForEach-Object {
        if ($SC.InstallMethods.UsesAzProxy[$_]) {
            $Install.ChosenMethod = $Install.MethodData.$_
            if ($null -ne $Install.ChosenMethod.Value) {
                RequestAzWebProxyToken
            }
        }
    }
}

function WriteKey {
    ### Parameters
    ###############################
    param ($Key, $Properties)
    ### Function Body
    ###############################
    # Create the Key if Missing
    if ((Test-Path $Key) -eq $false)
    { New-Item -Path $Key -Force >$null }
    # Add Properties and Assign Values
    $Properties.Keys |
    ForEach-Object { New-ItemProperty -Path $Key -Name $_ -Value $Properties.$_ -Force >$null }
}

function AlphaValue {
    ### Parameters
    ###############################
    param ($Value, [Switch] $2Digit)
    ### Function Body
    ###############################
    if ($2Digit.IsPresent -eq $true)
    { return ("A" + [String]([Char]($Value - 35))) }
    else
    { return ([String]([Char]($Value + 65))) }
}

function Quit {
    ### Parameters
    ###############################
    param ($Code)
    ### Function Body
    ###############################
    ### Update the Script Registry Keys
    # Assign the Appropriate Error Message
    switch ($Code) {
        # Successful Execution
        0 {
            $Script.Execution.ScriptAction = $SC.SuccessScriptAction
            $LCode = AlphaValue $Code
            break
        }
        # Documented Typical Error
        { @(1..25) -contains $_ }
        { $LCode = AlphaValue $Code; break }
        # Documented Internal Error
        { @(100..125) -contains $_ }
        { $LCode = AlphaValue $Code -2Digit; break }
        # Undocumented Error
        Default
        { $Code = 999; $LCode = "Error"; break }
    }
    $Comment = $SC.Exit.$LCode.ExitResult
    ### Publish Execution Results to the Registry
    # Create a New Registry Key for Script Results and Actions
    if ((Test-Path ($Script.Results.ScriptKey)) -eq $false)
    { New-Item $($Script.Results.ScriptKey) -Force >$null }
    # Collect Final Execution Values
    $Script.Execution.ScriptResult = $Comment
    $Script.Execution.ScriptExitCode = $Code
    # Write Final Execution Values
    WriteKey $Script.Results.ScriptKey $Script.Execution
    ### Append the Function Info if a Validation Error Occurs
    if ($Code -match $SC.Validation.InternalErrorCode) {
        $Script.Results.Function = $Function.Name
        $Script.Results.LineNumber = $Function.LineNumber
        $Script.Results.Details += @("`n== Error Details ==")
        $Script.Results.Details += @($SC.Exit.$LCode.ExitMessage)
        $Script.Results.Details +=
        if ($null -ne $Script.Results.Function)
        { @("Function Name:  " + $Script.Results.Function) }
        $Script.Results.Details +=
        if ($null -ne $Script.Results.LineNumber)
        { @("Called at Line:  " + $Script.Results.LineNumber) }
        $Script.Results.Details +=
        if ($null -ne $Script.Results.Parameter)
        { @("Parameter Name:  " + $Script.Results.Parameter) }
        $Script.Results.Details +=
        if ($null -ne $Script.Results.GivenParameter)
        { @("Given Parameter:  " + $Script.Results.GivenParameter) }
    }
    ### Format the Message Data for the Event Log
    # Add the Overall Script Result
    $Script.Results.EventMessage += @("Overall Script Result:  " + $SC.Exit.$LCode.ExitType + "`n")
    # Add the Completion Status of Each Sequence
    $Script.Sequence.Order |
    ForEach-Object {
        $Script.Results.EventMessage += @(
            $_,
            $Script.Sequence.Status[([Array]::IndexOf($Script.Sequence.Order, $_))]
        ) -join ' - '
    }
    # Add the Detailed Messages for Each Sequence
    $Script.Results.EventMessage += @("`n" + ($Script.Results.Details -join "`n"))
    # For Typical Errors, Add the Branded Error Contact Message from Partner Configuration
    if (
        ($Code -ne 999) -and
        ($Code -ne 0) -and
        ($null -ne $Config.ErrorContactInfo)
    ) {
        $Script.Results.EventMessage +=
        "`n--=========================--",
        "`nTo report this documented issue, please submit this Event Log entry to:`n",
        $Config.ErrorContactInfo
    }
    # Combine All Message Items
    $Script.Results.EventMessage = ($Script.Results.EventMessage -join "`n").TrimEnd('')
    ### Publish Execution Results to the Event Log
    # Create a New Key for the Event Source if Required
    if ((Test-Path $Script.Results.ScriptEventKey) -eq $false)
    { New-EventLog -Source $Script.Results.ScriptSource -LogName $Script.Results.EventLog }
    # Write the Event
    Write-EventLog -LogName $Script.Results.EventLog -Source $Script.Results.ScriptSource -EventID (9000 + $Code) -EntryType $Script.Results.ErrorLevel -Message $Script.Results.EventMessage -Category 0
    ### Cleanup Outdated Items
    $SC.Paths.Old.Values |
    ForEach-Object { Remove-Item $_ -Recurse -Force 2>$null }
    ### Cleanup Working Folder
    Remove-Item $Script.Path.InstallDrop -Force -Recurse 2>$null
    if (!$DebugMode.isPresent) {
        Remove-Item $Script.Path.TempFolder -Force -Recurse 2>$null
    }    
    exit $Code
}

function Log {
    ### Parameters
    ###############################
    param
    (
        $EventType, $Code,
        $Message, $Sequence,
        [Switch] $BeginSequence,
        [Switch] $EndSequence,
        [Switch] $Exit
    )
    ### Parameter Validation
    ###############################
    # Notes:
    # If you are ending a sequence, log the EndSequence with no other parameters
    # Always submit an EventType, Code and Message if you are not calling the end sequence
    if ($EndSequence.IsPresent -eq $true)
    { <# Other Parameters are not Required #> }
    else { 
        if ($BeginSequence.IsPresent -eq $true) {
            # EventType and Code are not Required
            $EventType = "Information"
            $Code = 0
        }
        else {
            ### EventType - Must be a Valid Full or Partial Event Type
            $EventType =
            switch ($EventType) {
                { "Information" -like ($_ + "*") }
                { "Information"; break }
                { "Warning" -like ($_ + "*") }
                { "Warning"; break }
                { "Error" -like ($_ + "*") }
                { "Error"; break }
                Default
                { $null; break }
            }
            if ($null -eq $EventType) {
                # ERROR - Invalid Parameter
                $Script.Results.Parameter = "EventType"
                $Script.Results.GivenParameter = $EventType
                Quit 100
            }
        }
        ### Message - Must be a String
        if (
            ($null -ne $Message) -and
            (($Message -is [String]) -or
                ($Message -is [Array]))
        ) {
            if ($Message -is [Array])
            { $Message = $Message -join "`n" }
        }
        else {
            # ERROR - Invalid Parameter
            $Script.Results.Parameter = "Message"
            Quit 100
        }
        ### Sequence - Must be a String
        if ($null -ne $Sequence) {
            if ($Sequence -is [String])
            { $Script.Execution.ScriptSequence = $Sequence }
            else {
                # ERROR - Invalid Parameter
                $Script.Results.Parameter = "Sequence"
                $Script.Results.GivenParameter = $Sequence
                Quit 100
            }
        }
        else {
            if ($null -eq $Script.Execution.ScriptSequence) {
                # ERROR - Invalid Parameter
                $Script.Results.Parameter = "Sequence"
                $Script.Results.GivenParameter = "None Provided (Required Parameter when there is no Active Sequence)"
                Quit 100
            }
        }
    }
    ### Function Body
    ###############################
    if ($EndSequence.IsPresent -eq $false) {
        ### Update Script Event Level
        $Script.Results.ErrorLevel =
        switch ($Script.Results.ErrorLevel) {
            { $null -eq $_ }
            { $EventType; break }
            "Information"
            { $EventType; break }
            "Warning"
            { if ($EventType -eq "Error") { $EventType }; break }
        }
    }
    ### Update Script Sequence Results
    # Update Sequence Order
    if ($Script.Sequence.Order -notcontains $Script.Execution.ScriptSequence)
    { $Script.Sequence.Order += @($Script.Execution.ScriptSequence) }
    # Determine the Sequence Status
    if ($BeginSequence.IsPresent -eq $true) {
        $Status = $SC.SequenceStatus.C
        # Add Sequence Header Before Detail Message
        $Script.Results.Details +=
        ("--== " + $Script.Execution.ScriptSequence + " ==--"),
        $Message
    }
    if (($BeginSequence.IsPresent -eq $false) -and ($EndSequence.IsPresent -eq $false)) {
        $Status =
        switch ($Code) {
            0
            { $Script.Sequence.Status[-1]; break }
            { $null -eq $_ }
            { ($SC.SequenceStatus.B + " (UNKNOWN)"); break }
            Default
            { ($SC.SequenceStatus.B + " ($Code)"); break }
        }
        # Add Detail Message to Current Sequence
        $Script.Results.Details += @("`n" + $Message)
    }
    if ($EndSequence.IsPresent -eq $true) {
        # Change Status to COMPLETE Unless Otherwise Specified
        $Status =
        if ($Script.Sequence.Status[-1] -eq $SC.SequenceStatus.C)
        { $SC.SequenceStatus.A } else { $Script.Sequence.Status[-1] }
        # Add Sequence Footer After Detail Message
        $Script.Results.Details += @("--== " + $Script.Execution.ScriptSequence + " Finished ==--`n")
    }
    # Update the Event Log Sequence Status
    $SelectedStatus = [Array]::IndexOf($Script.Sequence.Order, $Sequence)
    switch (($Script.Sequence.Status).Count) {
        { $_ -le $SelectedStatus }
        { $Script.Sequence.Status += @($Status) }
        Default
        { ($Script.Sequence.Status)[$SelectedStatus] = $Status }
    }
    # Update the Registry Sequence Status if Required
    if (@($BeginSequence.IsPresent, $EndSequence.IsPresent) -contains $true)
    { WriteKey $Script.Results.ScriptKey $Script.Execution }
    ### Terminate if Requested
    if ($Exit.IsPresent -eq $true) { Quit $Code }
}

function CatchError {
    ### Parameters
    ###############################
    param ($Code, $Message, [Switch] $Exit)
    ### Function Body
    ###############################
    # Add a Message if Found
    if ($null -ne $Message)
    { $Out = @($Message) }
    else
    { $Out = @("The Script encountered an undocumented error.") }
    # Get Any Exception Info
    if ($null -ne $ExceptionInfo) {
        if ($null -ne $InvocationInfo.Line) {
            $ExcCmd = ($InvocationInfo.Line).Replace("-ErrorAction Stop", "").Trim()
            $ExcCmdLN = $InvocationInfo.ScriptLineNumber
        }
        $ExcLookup = $ExceptionInfo.InnerException
        do {
            $ExcMsg += @($ExcLookup.Message)
            $ExcLookup = $ExcLookup.InnerException
        } while ($null -ne $ExcLookup)
        $ExcMsg |
        ForEach-Object { if ($null -ne $_) { $ExcMsgItems++ } }
        if (-not ($ExcMsgItems -gt 0))
        { $ExcMsg = @($ExceptionInfo.Message) }
        if (($null -ne $ExcCmd) -and ($null -ne $ExcCmdLN)) {
            $Out += 
            "== Command Details ==",
            ("Faulting Line Number:  " + $ExcCmdLN),
            ("Faulting Command:  " + $ExcCmd + "`n")
        }
        $Out +=
        "== Error Message ==",
        ($ExcMsg -join "`n")
    }
    Log E $Code $Out
    if ($Exit.IsPresent -eq $true) { Quit $Code }
}

function GetDeviceInfo {
    ### Function Body
    ###############################
    ### Computer Details
    $WMIinfo = Get-WmiObject Win32_ComputerSystem
    $WMIos = Get-WmiObject Win32_OperatingSystem
    # Device Name
    [String] $Device.Hostname = & "$env:windir\SYSTEM32\HOSTNAME.EXE"
    [String] $Device.Name = $WMIinfo.Name
    # Domain Role
    [String] $Device.FQDN = $WMIinfo.Domain
    $Device_Flags =
    "Role", "IsWKST", "IsSRV",
    "IsDomainJoined", "IsDC", "IsBDC"
    $Device_Values =
    switch ($WMIinfo.DomainRole) {
        0
        { @("Standalone Workstation", $true, $false, $false, $false, $false); break }
        1
        { @("Domain/Member Workstation", $true, $false, $true, $false, $false); break }
        2
        { @("Standalone Server", $false, $true, $false, $false, $false); break }
        3
        { @("Domain/Member Server", $false, $true, $true, $false, $false); break }
        4
        { @("Domain Controller (DC)", $false, $true, $true, $true, $false); break }
        5
        { @("Baseline Domain Controller (BDC)", $false, $true, $true, $true, $true); break }
        Default
        { $null; break }
    }
    if ($null -ne $Device_Values) {
        for ($i = 0; $i -lt $Device_Flags.Count; $i++)
        { $Device.($Device_Flags[$i]) = $Device_Values[$i] }
    }
    # Last Boot Time
    [DateTime] $Device.LastBootTime =
    if ($null -ne $WMIos.LastBootUpTime)
    { Get-Date ($WMIos.ConvertToDateTime($WMIos.LastBootUpTime)) -UFormat "%Y-%m-%d %r" } else { 0 }
    ### OS/Software Details
    # PowerShell Version
    [Version] $Device.PSVersion =
    if ($null -ne $PSVersionTable)
    { $PSVersionTable.PSVersion } else { "1.0" }
    # Operating System Name/Build
    [String] $Device.OSName = ($WMIos.Caption).Trim().Replace("Microsoftr", "Microsoft").Replace("Serverr", "Server").Replace("Windowsr", "Windows")
    [Version] $Device.OSBuild =
    if ($null -eq $WMIos.Version)
    { ($PSVersionTable.BuildVersion.ToString()) }
    else
    { $WMIos.Version }
    # Operating System Architecture
    [String] $Device.Architecture =
    if ($Device.OSBuild -le "6.0") {
        if ($Device.OSName -like "*64*")
        { "64-bit" } else { "32-bit" }
    }
    else {
        if ($WMIos.OSArchitecture -like "*64*")
        { "64-bit" } else { "32-bit" }
    }
    # Program Files Location
    [String] $Device.PF32 =
    if ($Device.Architecture -eq "64-bit")
    { ($env:SystemDrive + "\Program Files (x86)") }
    else
    { ($env:SystemDrive + "\Program Files") }
    [String] $Device.PF = ($env:SystemDrive + "\Program Files")
    # Server Core Installation
    $CoreSKUs = @(12..14), 29, @(39..41), @(43..46), 53, 63, 64
    [Boolean] $Device.ServerCore =
    if ($CoreSKUs -contains $WMIos.OperatingSystemSKU)
    { $true } else { $false }
}

function GetNETVersion {
    ### Function Body
    ###############################
    ### Retrieve .NET Framework Version
    $NETinfo =
    Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP' -Recurse |
    Get-ItemProperty -Name Version, Release -ErrorAction SilentlyContinue |
    Where-Object { $_.PSChildName -eq "Full" } |
    Select-Object Version, Release,
    @{
        Name       = "Product"
        Expression = {
            $NET = $_
            switch ($NET) {
                { $_.Version -eq "4.0.30319" }
                { "4.0"; break }
                { $_.Release -eq 378389 }
                { "4.5"; break }
                { @(378675, 378758) -contains $_.Release }
                { "4.5.1"; break }
                { $_.Release -eq 379893 }
                { "4.5.2"; break }
                { @(393295, 393297) -contains $_.Release }
                { "4.6"; break }
                { @(394254, 394271) -contains $_.Release }
                { "4.6.1"; break }
                { @(394802, 394806) -contains $_.Release }
                { "4.6.2"; break }
                { @(460798, 460805) -contains $_.Release }
                { "4.7"; break }
                { @(461308, 461310) -contains $_.Release }
                { "4.7.1"; break }
                { @(461808, 461814) -contains $_.Release } 
                { "4.7.2"; break }
                { @(528040, 528049) -contains $_.Release } 
                { "4.8"; break }
                { $_.Release -gt 528049 }
                { "4.8"; $DisplayProduct = "4.8 or Newer"; break }
                Default {
                    $NETVer = $NET.Version.Split(".")
                    $Product = @($NETVer[0], $NETVer[1]) -join '.'
                    $Product
                    $DisplayProduct = ($Product + " (Unverified)")
                    break
                }
            }
        }
    }
    ### Summarize Version Info
    if ($null -ne $NETinfo) {
        $Device.NETVersion = [Version] (ValidateVersion $($NETinfo.Version))
        $Device.NETProduct = [Version] (ValidateVersion $($NETinfo.Product))
        $Device.NETDisplayProduct =
        if ($null -ne $DisplayProduct)
        { $DisplayProduct } else { $Device.NETProduct }
    }
}

function SelfElevate {
    ### Function Body
    ###############################
    $CU_ID = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $CU_Principal = New-Object System.Security.Principal.WindowsPrincipal($CU_ID)
    $Admin_Role = [System.Security.Principal.WindowsBuiltInRole]::Administrator
    if (-not $CU_Principal.IsInRole($Admin_Role)) {
        $Proc = New-Object System.Diagnostics.ProcessStartInfo "PowerShell"
        $Proc.Arguments = ("-ExecutionPolicy Bypass -NoLogo -NoProfile -WindowStyle Hidden -File `"" + $Script.Invocation + "`"")
        $Script.Parameters.Keys |
        ForEach-Object {
            $i = $_
            $Proc.Arguments +=
            if ($Script.Parameters.$i -like "* *")
            { (" -" + $i + " `"" + $Script.Parameters.$i) }
            else
            { (" -" + $i + " " + $Script.Parameters.$i) }
        }
        if ($Device.OSBuild -gt "6.0") { $Proc.Verb = "runas" }
        [System.Diagnostics.Process]::Start($Proc) >$null
        exit
    }
}

### VALIDATION FUNCTIONS
###############################

function ValidateVersion {
    ### Parameters
    ###############################
    param ($Version, $Digits)
    ### Definitions
    ###############################
    # Function Info
    $Function.LineNumber = $MyInvocation.ScriptLineNumber
    $Function.Name = '{0}' -f $MyInvocation.MyCommand
    ### Parameter Validation
    ###############################
    # Version - Must be a Valid Version String
    $Version = [String] $Version
    if ($Version -notmatch $SC.Validation.VersionNumber.Accepted) {
        # ERROR - Invalid Parameter
        $Script.Results.Parameter = "Version"
        $Script.Results.GivenParameter = ($Version + " - Must be a Valid Version String")
        Quit 100
    }
    # Places - Must be an Integer between 2 and 4
    if ($null -eq $Digits)
    { $Digits = 4 }
    else {
        if ($Digits -notmatch $SC.Validation.VersionNumberDigits) {
            # ERROR - Invalid Parameter
            $Script.Results.Parameter = "Digits"
            $Script.Results.GivenParameter = ([String]($Digits) + " - Must be an Integer (2-4)")
            Quit 100
        }
    }
    ### Function Body
    ###############################
    $NewVersion = $Version
    $VerCount = $Version.Split('.').Count
    while ($VerCount -lt $Digits) {
        $NewVersion += ".0"
        $VerCount = ($NewVersion).Split('.').Count
    }
    while ($VerCount -gt $Digits) {
        if ($NewVersion -eq $NewVersion.TrimEnd('0').TrimEnd('.'))
        { break } else { $NewVersion = $NewVersion.TrimEnd('0').TrimEnd('.') }
        $VerCount = $NewVersion.Split('.').Count
    }
    return $NewVersion
}

function ValidateItem {
    ### Parameters
    ###############################
    param ($Path, [Switch] $Folder, [Switch] $NoNewItem, [Switch] $RemoveItem)
    ### Definitions
    ###############################
    # Function Info
    $Function.LineNumber = $MyInvocation.ScriptLineNumber
    $Function.Name = '{0}' -f $MyInvocation.MyCommand
    ### Parameter Validation
    ###############################
    # Path - Must be a Local Absolute Path
    $Path |
    ForEach-Object {
        if ($_ -notmatch $SC.Validation.LocalFolderPath) {
            # ERROR - Invalid Parameter
            $Script.Results.Parameter = "Path"
            $Script.Results.GivenParameter = ($Version + " (Must be a Local Absolute Path)")
            Quit 100
        }
    }
    ### Function Body
    ###############################
    $RequiredType =
    if ($Folder.IsPresent -eq $true)
    { "Container" } else { "Leaf" }
    $ImposterType =
    if ($Folder.IsPresent -eq $true)
    { "Leaf" } else { "Container" }
    $NewItemType =
    if ($Folder.IsPresent -eq $true)
    { "Directory" } else { "File" }
    $Path |
    ForEach-Object {
        $p = $_
        # Check for and Remove Imposters
        if ((Test-Path $p -PathType $ImposterType) -eq $true)
        { Remove-Item $p -Recurse -Force 2>$null }
        if ($NoNewItem.IsPresent -eq $false) {
            # Create an Empty Item if Required
            if ((Test-Path $p) -eq $false)
            { New-Item $p -ItemType $NewItemType -Force >$null 2>$null }
        }
        $ValidateResult +=
        if ($RemoveItem.IsPresent -eq $true) {
            Remove-Item $p -Recurse -Force 2>$null
            @((Test-Path $p) -eq $false)
        }
        else
        { @((Test-Path $p -PathType $RequiredType) -eq $true) }
    }
    return $ValidateResult
}

function ValidatePartnerConfig {
    ### Definitions
    ###############################
    # Function Info
    $Function.LineNumber = $MyInvocation.ScriptLineNumber
    $Function.Name = '{0}' -f $MyInvocation.MyCommand
    # Execution Info
    $Script.Execution.ScriptAction = "Validating Partner Configuration"
    WriteKey $Script.Results.ScriptKey $Script.Execution
    ### Branding Values
    $Partner.Config.Branding.GetEnumerator() |
    Where-Object { $_.Name -ne '#comment' } |
    ForEach-Object { $Config.$($_.Name) = $_.'#text' }
    ### Script Behavior Values
    $Partner.Config.ScriptBehavior.GetEnumerator() |
    Where-Object { $_.Name -ne '#comment' } |
    ForEach-Object { $Config.$($_.Name) = $_.'#text' }
    ### Server Values
    $Partner.Config.Server.GetEnumerator() |
    Where-Object { $_.Name -ne '#comment' } |
    ForEach-Object { $Config.$($_.Name) = $_.'#text' }
    ### Service Behavior Values
    $Partner.Config.ServiceBehavior.GetEnumerator() |
    Where-Object { $_.Name -ne '#comment' } |
    ForEach-Object { $Config.$("Service" + $_.Name) = $_.'#text' }
    ### Deployment Values
    $Config.LocalFolder = $Partner.Config.Deployment.LocalFolder
    $Config.NetworkFolder = $Partner.Config.Deployment.NetworkFolder
    # Installer Values
    if ($Device.OSBuild -ge "6.1") {
        # Use Typical (Latest) Agent
        $InstallInfo = $Partner.Config.Deployment.Typical
    }
    else {
        # Use Legacy Agent (Retain Support for Windows XP/Server 2003)
        # Legacy support no longer available, error out
        $InstallInfo = $Partner.Config.Deployment.Legacy
        $Out = "Name-Central Agent for Windows is no longer supported on Vista/2008 and earlier"
        Log E 19 $Out -Exit
    }
    $Config.InstallFolder = $InstallInfo.InstallFolder
    $Config.AgentFile = $InstallInfo.SOAgentFileName
    $Config.AgentVersion = $InstallInfo.SOAgentVersion
    $Config.AgentFileVersion = $InstallInfo.SOAgentFileVersion
    $Config.CustomerId = $InstallInfo.CustomerId
    $Config.RegistrationToken = $InstallInfo.RegistrationToken
    $Config.AzNableProxyUri = $InstallInfo.AzNableProxyUri
    $Config.AzNableAuthCode = $InstallInfo.AzNableAuthCode
    $Config.NETFile = $InstallInfo.NETFileName
    $Config.NETVersion = $InstallInfo.NETVersion
    $Config.NETFileVersion = $InstallInfo.NETFileVersion
    $Config.EnforceBehaviorPolicy = if ($Partner.Config.ServiceBehavior.EnforcePolicy -like "True") {$true} else {$false}
    $Config.ForceAgentCleanup = if ($Partner.Config.ScriptBehavior.ForceAgentCleanup -like "True") {$true} else {$false}
    $Config.UseWSDLVerifcation = if ($Partner.Config.ScriptBehavior.UseWSDLVerification -like "True") {$true} else {$false}

    ### Function Body
    ###############################
    ### Validate Required Items from Partner Configuration
    $ConfigUpdate = @{}
    $Config.Keys |
    ForEach-Object {
        $i = $_
        $Invalid =
        switch ($i) {
            # Branding Values
            "ErrorContactInfo" {
                # Remove Outlying Blanks if Present
                $ConfigUpdate.$i =
                if (@($null, '') -notcontains $Config.$i)
                { ($Config.$i).Trim() }
                # No Validation for Branding
                $false
                break
            }
            # Script Behavior Values
            "BootTimeWaitPeriod" {
                # Remove Outlying Blanks if Present
                $ConfigUpdate.$i =
                if (@($null, '') -notcontains $Config.$i)
                { ($Config.$i).Trim() }
                # Must be a Number from 0 to 60
                if (
                    ($ConfigUpdate.$i -notmatch $SC.Validation.WholeNumberUpto2Digit) -or
                    (
                        ($ConfigUpdate.$i -match $SC.Validation.WholeNumberUpto2Digit) -and
                        ((([Int] $ConfigUpdate.$i) -lt 0) -or (([Int] $ConfigUpdate.$i) -gt 60))
                    )
                )
                { $true }
                else {
                    $false
                    # Convert Minutes to Seconds
                    $ConfigUpdate.$i = [Int] $ConfigUpdate.$i * 60
                }
                break
            }
            "InstallTimeoutPeriod" {
                # Remove Outlying Blanks if Present
                $ConfigUpdate.$i =
                if (@($null, '') -notcontains $Config.$i)
                { ($Config.$i).Trim() }
                # Must be a Number from 1 to 60
                if (
                    ($ConfigUpdate.$i -notmatch $SC.Validation.WholeNumberUpto2Digit) -or
                    (
                        ($ConfigUpdate.$i -match $SC.Validation.WholeNumberUpto2Digit) -and
                        ((([Int] $ConfigUpdate.$i) -lt 1) -or (([Int] $ConfigUpdate.$i) -gt 60))
                    )
                )
                { $true }
                else {
                    $false
                    # Convert to Integer
                    $ConfigUpdate.$i = [Int] $ConfigUpdate.$i
                }
                break
            }
            # Server Values
            "NCServerAddress" {
                # Remove Outlying Blanks/Slashes if Present
                $ConfigUpdate.$i =
                if (@($null, '') -notcontains $Config.$i)
                { ($Config.$i).Trim('/ ') }
                # Remove Protocol Header if Present
                if ($ConfigUpdate.$i -match $NC.Validation.ServerAddress.Accepted)
                { $ConfigUpdate.$i = ($ConfigUpdate.$i).Split('/')[2] }
                # Must be a Valid Server Address
                if ($ConfigUpdate.$i -notmatch $NC.Validation.ServerAddress.Valid)
                { $true } else { $false }
                break
            }
            "PingCount" {
                # Remove Outlying Blanks if Present
                $ConfigUpdate.$i =
                if (@($null, '') -notcontains $Config.$i)
                { ($Config.$i).Trim() }
                # Must be a Number from 1 to 100
                if (
                    ($ConfigUpdate.$i -notmatch $SC.Validation.WholeNumberUpto3Digit) -or
                    (
                        ($ConfigUpdate.$i -match $SC.Validation.WholeNumberUpto3Digit) -and
                        ((([Int] $ConfigUpdate.$i) -lt 1) -or (([Int] $ConfigUpdate.$i) -gt 100))
                    )
                )
                { $true }
                else {
                    $false
                    # Convert to Integer
                    $ConfigUpdate.$i = [Int] $ConfigUpdate.$i
                }
                break
            }
            "PingTolerance" {
                # Remove Outlying Blanks if Present
                $ConfigUpdate.$i =
                if (@($null, '') -notcontains $Config.$i)
                { ($Config.$i).Trim() }
                # Must be a Number from 0 to 100
                if (
                    ($ConfigUpdate.$i -notmatch $SC.Validation.WholeNumberUpto3Digit) -or
                    (
                        ($ConfigUpdate.$i -match $SC.Validation.WholeNumberUpto3Digit) -and
                        ((([Int] $ConfigUpdate.$i) -lt 0) -or (([Int] $ConfigUpdate.$i) -gt 100))
                    )
                )
                { $true }
                else {
                    $false
                    # Convert to Integer
                    $ConfigUpdate.$i = [Int] $ConfigUpdate.$i
                }
                break
            }
            "ProxyString" {
                # Remove Outlying Blanks if Present
                $ConfigUpdate.$i =
                if (@($null, '') -notcontains $Config.$i)
                { ($Config.$i).Trim() }
                # No Validation for Proxy String
                $false
                break
            }
            # Service Behavior Values
            { $_ -match '^ServiceAction.$' } {
                # Remove Outlying Blanks if Present
                $ConfigUpdate.$i =
                if (@($null, '') -notcontains $Config.$i)
                { ($Config.$i).Trim() }
                # Must be one of these Values and No Previous Service Actions can be Empty
                if (
                    (
                        ($null -ne $ConfigUpdate.$i) -and
                        ($ConfigUpdate.$i -ne 'RESTART') -and
                        ($ConfigUpdate.$i -ne 'RUN') -and
                        ($ConfigUpdate.$i -ne 'REBOOT')
                    ) -or
                    (
                        ($i -eq 'ActionB') -and
                        ($null -ne $ConfigUpdate.$i) -and
                        ($null -eq $ConfigUpdate.$($i -creplace ('B$', 'A')))
                    ) -or
                    (
                        ($i -eq 'ActionC') -and
                        ($null -ne $ConfigUpdate.$i) -and
                        (
                            ($null -eq $ConfigUpdate.$($i -creplace ('C$', 'A'))) -or
                            ($null -eq $ConfigUpdate.$($i -creplace ('C$', 'B')))
                        )
                    )
                )
                { $true } else { $false }
                break
            }
            "ServiceCommand" {
                # Remove Outlying Blanks if Present
                $ConfigUpdate.$i =
                if (@($null, '') -notcontains $Config.$i)
                { ($Config.$i).Trim() }
                # No Validation for Command
                $false
                break
            }
            { $_ -match '^ServiceDelay.$' } {
                # Remove Outlying Blanks if Present
                $ConfigUpdate.$i =
                if (@($null, '') -notcontains $Config.$i)
                { ($Config.$i).Trim() }
                # Assume No Delay if there is No Corresponding Action
                if ($null -eq $ConfigUpdate.$($i -creplace (('Delay' + $i[-1]), ('Action' + $i[-1]))))
                { $ConfigUpdate.$i = $null }
                # Must be a Number from 0 to 3600
                if (
                    ($null -ne $ConfigUpdate.$i) -and
                    (
                        ($ConfigUpdate.$i -notmatch $SC.Validation.WholeNumberUpto4Digit) -or
                        (
                            ($ConfigUpdate.$i -match $SC.Validation.WholeNumberUpto4Digit) -and
                            ((([Int] $ConfigUpdate.$i) -lt 0) -or (([Int] $ConfigUpdate.$i) -gt 3600))
                        )
                    )
                )
                { $true }
                else {
                    $false
                    # Convert to Integer (Seconds to Milliseconds)
                    $ConfigUpdate.$i =
                    if ($null -ne $ConfigUpdate.$i)
                    { ([Int] $ConfigUpdate.$i) * 1000 } else { [Int] 0 }
                }          
                break
            }
            "ServiceReset" {
                # Remove Outlying Blanks if Present
                $ConfigUpdate.$i =
                if (@($null, '') -notcontains $Config.$i)
                { ($Config.$i).Trim() }
                # Must be a Number from 0 to 44640
                if (
                    ($null -ne $ConfigUpdate.$i) -and
                    (
                        ($ConfigUpdate.$i -notmatch $SC.Validation.WholeNumberUpto5Digit) -or
                        (
                            ($ConfigUpdate.$i -match $SC.Validation.WholeNumberUpto5Digit) -and
                            ((([Int] $ConfigUpdate.$i) -lt 0) -or (([Int] $ConfigUpdate.$i) -gt 44640))
                        )
                    )
                )
                { $true }
                else {
                    $false
                    # Convert to Integer (Minutes to Seconds)
                    $ConfigUpdate.$i =
                    if ($null -ne $ConfigUpdate.$i)
                    { ([Int] $ConfigUpdate.$i) * 60 } else { [Int] 0 }
                }          
                break
            }
            "ServiceStartup" {
                # Remove Outlying Blanks if Present
                $ConfigUpdate.$i =
                if (@($null, '') -notcontains $Config.$i)
                { ($Config.$i).Trim() }
                # Accept Partial String Values
                if ("Automatic" -like ($ConfigUpdate.$i + "*")) {
                    $j = $i.Replace('Startup', '')
                    $ConfigUpdate.$i = "Automatic"
                    $ConfigUpdate.$($j + 'QueryString') = "Auto"
                    $ConfigUpdate.$($j + 'RepairString') = "Auto"
                    $ConfigUpdate.$($j + 'RequireDelay') = $false
                }
                if ("Delay" -like ($ConfigUpdate.$i + "*")) {
                    $j = $i.Replace('Startup', '')
                    $ConfigUpdate.$i = "Delay"
                    $ConfigUpdate.$($j + 'QueryString') = "Auto"
                    $ConfigUpdate.$($j + 'RepairString') = "Delayed-Auto"
                    $ConfigUpdate.$($j + 'RequireDelay') = $true
                }
                # Must be one of these Values
                if (@("Automatic", "Delay") -notcontains $ConfigUpdate.$i)
                { $true } else { $false }
                break
            }
            # Deployment Values
            "AgentFile" {
                # Remove Outlying Blanks/Periods if Present
                $ConfigUpdate.$i =
                if (@($null, '') -notcontains $Config.$i)
                { ($Config.$i).Trim('. ') }
                # Must be a Valid Executable File Name
                if ($ConfigUpdate.$i -notmatch $SC.Validation.FileNameEXE)
                { $true } else { $false }
                break
            }
            "AgentFileVersion" {
                # Remove Outlying Blanks if Present
                $ConfigUpdate.$i =
                if (@($null, '') -notcontains $Config.$i)
                { ($Config.$i).Trim() }
                # Must be a Version Number with up to 4 Digits
                if ($ConfigUpdate.$i -notmatch $SC.Validation.VersionNumber.Accepted)
                { $true }
                else {
                    $false
                    # Fill Empty Trailing Values with Zeroes
                    if ($ConfigUpdate.$i -notmatch $SC.Validation.VersionNumber.Valid)
                    { $ConfigUpdate.$i = ValidateVersion $($ConfigUpdate.$i) }
                    # Convert to Version
                    $ConfigUpdate.$i = [Version] $ConfigUpdate.$i
                }
                break
            }
            "AgentVersion" {
                # Remove Outlying Blanks if Present
                $ConfigUpdate.$i =
                if (@($null, '') -notcontains $Config.$i)
                { ($Config.$i).Trim() }
                # Must be a Version Number with up to 4 Digits
                if ($ConfigUpdate.$i -notmatch $SC.Validation.VersionNumber.Accepted)
                { $true }
                else {
                    $false
                    # Fill Empty Trailing Values with Zeroes
                    if ($ConfigUpdate.$i -notmatch $SC.Validation.VersionNumber.Valid)
                    { $ConfigUpdate.$i = ValidateVersion $($ConfigUpdate.$i) }
                    # Convert to Version
                    $ConfigUpdate.$i = [Version] $ConfigUpdate.$i
                }          
                break
            }
            "InstallFolder" {
                # Remove Outlying Blanks/Periods if Present
                $ConfigUpdate.$i =
                if (@($null, '') -notcontains $Config.$i)
                { ($Config.$i).Trim('. ') }
                # Must be a Valid Folder Name
                if ($ConfigUpdate.$i -notmatch $SC.Validation.ItemName)
                { $true } else { $false }
                break
            }
            "CustomerId" {
                # CustomerId can be null in the case it isn't being used, validate on null
                if ("" -eq $Config.$i) { $false; break }
                # Remove Outlying Blanks/Periods if Present
                $ConfigUpdate.$i =
                if (@($null, '') -notcontains $Config.$i)
                { ($Config.$i).Trim('. ') }
                # Must be a Valid Folder Name
                if ($ConfigUpdate.$i -notmatch $SC.Validation.WholeNumberUpto5Digit)
                { $true } else { $false }
                break
            }
            "RegistrationToken" {
                # Registration token can be null in the case it isn't being used, validate on null
                if ("" -eq $Config.$i) { $false; break }
                # Remove Outlying Blanks/Periods if Present
                $ConfigUpdate.$i =
                if (@($null, '') -notcontains $Config.$i)
                { ($Config.$i).Trim('. ') }
                # Must be a Valid Folder Name
                if ($ConfigUpdate.$i -notmatch $SC.Validation.GUID)
                { $true } else { $false }
                break
            }
            "LocalFolder" {
                # Remove Trailing Slash if Present
                $ConfigUpdate.$i =
                if (@($null, '') -notcontains $Config.$i)
                { ($Config.$i).Trim('\ ') }
                # Must be a Local Absolute Path
                if ($ConfigUpdate.$i -notmatch $SC.Validation.LocalFolderPath)
                { $true } else { $false }
                break
            }       
            "NETFile" {
                # Remove Outlying Blanks/Periods if Present
                $ConfigUpdate.$i =
                if (@($null, '') -notcontains $Config.$i)
                { ($Config.$i).Trim('. ') }
                # Must be a Valid Executable File Name
                if ($ConfigUpdate.$i -notmatch $SC.Validation.FileNameEXE)
                { $true } else { $false }
                break
            }
            "NETFileVersion" {
                # Remove Outlying Blanks if Present
                $ConfigUpdate.$i =
                if (@($null, '') -notcontains $Config.$i)
                { ($Config.$i).Trim() }
                # Must be a Version Number with up to 4 Digits
                if ($ConfigUpdate.$i -notmatch $SC.Validation.VersionNumber.Accepted)
                { $true }
                else {
                    $false
                    # Fill Empty Trailing Values with Zeroes
                    if ($ConfigUpdate.$i -notmatch $SC.Validation.VersionNumber.Valid)
                    { $ConfigUpdate.$i = ValidateVersion $($ConfigUpdate.$i) }
                    # Convert to Version
                    $ConfigUpdate.$i = [Version] $ConfigUpdate.$i
                }
                break
            }
            "NETVersion" {
                # Remove Outlying Blanks if Present
                $ConfigUpdate.$i =
                if (@($null, '') -notcontains $Config.$i)
                { ($Config.$i).Trim() }
                # Must be a Version Number with up to 4 Digits
                if ($ConfigUpdate.$i -notmatch $SC.Validation.VersionNumber.Accepted)
                { $true }
                else {
                    $false
                    # Fill Empty Trailing Values with Zeroes
                    if ($ConfigUpdate.$i -notmatch $SC.Validation.VersionNumber.Valid)
                    { $ConfigUpdate.$i = ValidateVersion $($ConfigUpdate.$i) }
                    # Convert to Version
                    $ConfigUpdate.$i = [Version] $ConfigUpdate.$i
                }
                break
            }
            "NetworkFolder" {
                # Remove Outlying Blanks/Periods if Present
                $ConfigUpdate.$i =
                if (@($null, '') -notcontains $Config.$i)
                { ($Config.$i).Trim('. ') }
                # Must be a Valid Folder Name
                if ($ConfigUpdate.$i -notmatch $SC.Validation.ItemName)
                { $true } else { $false }
                break
            }
        }
        if ($Invalid -eq $true)
        { $InvalidConfig += @($i) }
    }
    # Update Config Table
    $ConfigUpdate.Keys |
    ForEach-Object { $Config.$_ = $ConfigUpdate.$_ }
    # Report on any Invalid Configuration Items
    if ($null -ne $InvalidConfig) {
        $Out =
        "One or more items in the Partner Configuration was invalid.`n",
        "Please verify the following values:"
        $InvalidConfig |
        Sort-Object |
        ForEach-Object { $Out += @($_) }
        Log E 2 $Out -Exit
    }
    else {
        $Out = @("All Required values in the Partner Configuration were successfully validated.")
        Log I 0 $Out
    }
    # Note valid CustomerId and Registration token
    if ( $null -ne $Config.CustomerId -and $null -ne $Config.RegistrationToken) {
        $Out = @("Valid CustomerId and Registration token found in Partner Configuration")
        Log I 0 $Out
    }
    if ($Config.AzNableProxyUri -ne "" -and $Config.AzNableAuthCode -ne "") {
        $Out = @("AzNableProxyUri and AuthCode found")
        $Config.IsAzNableAvailable = $true
        Log I 0 $Out
    }
    else {
        $Config.IsAzNableAvailable = $false
    }
    ### Populate Configuration History Location from Partner Configuration
    if ((ValidateItem $Config.LocalFolder -Folder) -eq $false) {
        # ERROR - Unable to Validate Configuration History Folder
        CatchError 104 "The Script was unable to validate the Configuration History Folder." -Exit
    }
    $Agent.Path.History = @($Config.LocalFolder, $SC.Names.HistoryFile) -join '\'
}

function ValidateExecution {
    ### Definitions
    ###############################
    # Function Info
    $Function.LineNumber = $MyInvocation.ScriptLineNumber
    $Function.Name = '{0}' -f $MyInvocation.MyCommand
    # Execution Info
    $Script.Execution.ScriptAction = "Determining Execution Mode"
    WriteKey $Script.Results.ScriptKey $Script.Execution
    ### Function Body
    ###############################
    ### Build Installation Source Paths
    $Install.Sources = @{
        "Demand"  = @{ "Path" = ($LauncherPath + $Config.InstallFolder) }
        "Network" = @{
            "Path" = @(
                "\", $Device.FQDN, "NETLOGON",
                $Config.NetworkFolder, $Config.InstallFolder
            ) -join '\'
        }
        "Sysvol"  = @{
            "Path" = @(
                "\", $Device.FQDN, "sysvol" , $Device.FQDN, "scripts",
                $Config.NetworkFolder, $Config.InstallFolder
            ) -join '\'
        }
    }
    ### Determine Execution Mode
    $Script.Execution.ScriptMode =
    switch ($Install.Sources.Demand.Path) {
        $Install.Sources.Network.Path
        { if ([Security.Principal.WindowsIdentity]::GetCurrent().IsSystem) { $SC.ExecutionMode.B } else { $SC.ExecutionMode.A }; break }
        $Install.Sources.Sysvol.Path
        { if ([Security.Principal.WindowsIdentity]::GetCurrent().IsSystem) { $SC.ExecutionMode.B } else { $SC.ExecutionMode.A }; break }
        Default
        { $SC.ExecutionMode.A; break }
    }
    ### Log Execution Mode
    WriteKey $Script.Results.ScriptKey $Script.Execution
    # Wait if Device has Recently Booted
    if (
        ($null -ne $Device.LastBootTime) -and
        ($Device.LastBootTime -ge (Get-Date).AddSeconds( - ($Config.BootTimeWaitPeriod)))
    ) {
        # Update Execution Info
        $Script.Execution.ScriptAction = "Waiting Before Diagnosis"
        WriteKey $Script.Results.ScriptKey $Script.Execution
        # Wait for Required Duration
        [Int] $WaitTime =
        $Config.BootTimeWaitPeriod - (
            ((Get-Date) - ([DateTime] $Device.LastBootTime)) |
            Select-Object -ExpandProperty TotalSeconds
        )
        $Out =
        ("Windows has booted within the " + $Config.BootTimeWaitPeriod + "-second Wait Period specified in the Partner Config.`n"),
        ("Waiting the remaining " + $WaitTime + " seconds before Diagnosis...")
        Log I 0 $Out
        Start-Sleep -Seconds $WaitTime
    }
}

### DIAGNOSIS FUNCTIONS
###############################

function ReadXML {
    ### Parameters
    ################################
    param ($XMLContent, $XPath)
    ### Definitions
    ###############################
    # Function Info
    $Function.LineNumber = $MyInvocation.ScriptLineNumber
    $Function.Name = '{0}' -f $MyInvocation.MyCommand
    ### Parameter Validation
    ################################
    ### XMLContent - Must be Full XML Text or an Absolute Path to an XML File
    # Validate Full XML Text
    if ($XMLContent -isnot [Xml]) {
        # Validate Absolute XML Path
        if ($XMLContent -match $SC.Validation.LocalFilePathXML) {
            # Verify File Exists
            if ((Test-Path $XMLContent -PathType Leaf 2>$null) -eq $true)
            { [Xml] $XMLContent = Get-Content $XMLContent }
            else {
                # ERROR - File Does Not Exist
                $Script.Results.Parameter = "XMLContent"
                $Script.Results.GivenParameter = ("[" + $XMLContent + "] - The XML File does not Exist")
                Quit 104
            }
        }
        else {
            # ERROR - Invalid Parameter
            $Script.Results.Parameter = "XMLContent"
            $Script.Results.GivenParameter = "Must be Valid XML File Content OR Absolute Path to an XML File"
            Quit 100
        }
    }
    # XPath - Must be an XML Path to an Existing Element (Document Element if omitted)
    ## Start with /, remove trailing /
    if ($null -eq $XPath)
    { $XPath = @("", $XMLContent.DocumentElement.Name, "*") -join '/' }
    else {
        if ($XPath -notmatch $SC.Validation.XMLElementPath) {
            # ERROR - Invalid Parameter
            $Script.Results.Parameter = "XPath"
            $Script.Results.GivenParameter = ("[" + $XPath + "] - Must be a Valid XML Path String (e.g. /MyConfig/Settings/*)")
            Quit 100
        }
    }
    ### Function Body
    ################################
    $Hash = @{}
    # Collect the Properties in the Current Element
    $XMLContent.SelectNodes($XPath) |
    Where-Object { $_.IsEmpty -eq $false } |
    ForEach-Object {
        $Node = $_
        switch ($Node.ChildNodes | Select-Object -ExpandProperty NodeType) {
            # Store Values from Current Element
            "Text"
            { $Hash.$($Node.Name) = $Node.ChildNodes | Select-Object -ExpandProperty Value; break }
            # Iterate through Elements for more Values
            "Element"
            { $Hash.$($Node.Name) = ReadXML $XMLContent $(@(($XPath -split '/\*')[0], $Node.Name, '*') -join '/'); break }
        }
    }
    return $Hash
}

function WriteXML {
    ### Parameters
    ###############################
    param ($XMLPath, $Root, $Values)
    ### Definitions
    ###############################
    # Function Info
    $Function.LineNumber = $MyInvocation.ScriptLineNumber
    $Function.Name = '{0}' -f $MyInvocation.MyCommand
    ### Parameter Validation
    ###############################
    # XMLPath - Must be an Absolute Path
    if ($XMLPath -notmatch $SC.Validation.LocalFilePathXML) {
        # ERROR - Invalid Parameter
        $Script.Results.Parameter = "XMLPath"
        $Script.Results.GivenParameter = ("[" + $XMLPath + "] - Must be an Absolute File Path with XML Extension")
        Quit 100
    }
    # Root - Must be a Valid XML Element Name
    if ($Root -notmatch $SC.Validation.XMLElementName) {
        # ERROR - Invalid Parameter
        $Script.Results.Parameter = "Root"
        $Script.Results.GivenParameter = "Must be a Valid XML Element Name"
        Quit 100
    }
    # Values - Must be a Hashtable with a Single Root Key
    if ($Values -isnot [Hashtable]) {
        # ERROR - Invalid Parameter
        $Script.Results.Parameter = "Values"
        $Script.Results.GivenParameter = "Must be a Hashtable with a Single Root Key"
        Quit 100
    }
    ### Function Body
    ###############################  
    ### Remove XML Document if Required
    if ((Test-Path $XMLPath) -eq $true)
    { Remove-Item $XMLPath -Force 2>$null }
    ### Create a New XML Document with Provided Values
    [Xml] $XMLDoc = New-Object System.Xml.XmlDocument
    # Write the XML Declaration
    $Declaration = $XMLDoc.CreateXmlDeclaration("1.0", "UTF-8", $null)
    $XMLDoc.AppendChild($Declaration) >$null
    # Write the Root Element
    $RootElement = $XMLDoc.CreateElement($Root)
    $XMLDoc.AppendChild($RootElement) >$null
    # Write  Elements
    $Values.Keys |
    Sort-Object |
    ForEach-Object {
        $Element = $XMLDoc.CreateElement($_)
        $Text = $XMLDoc.CreateTextNode($Values.$_)
        $Element.AppendChild($Text) >$null
        $RootElement.AppendChild($Element) >$null
    }
    $XMLDoc.Save($XMLPath)
}

function QueryServices {
    ### Definitions
    ###############################
    # Function Info
    $Function.LineNumber = $MyInvocation.ScriptLineNumber
    $Function.Name = '{0}' -f $MyInvocation.MyCommand
    ### Function Body
    ###############################
    ### Get Agent Service / Process Info
    $($Agent.Services.Data.Keys) |
    ForEach-Object {
        $s = $_
        # Get Service Status
        $Agent.Services.Data.$s = Get-WmiObject Win32_Service -Filter "Name='$s'"
        if ($null -ne $Agent.Services.Data.$s) {
            # Validate Related Process Info
            $P0 = ($Agent.Services.Data.$s.PathName).Split()[0]
            $P1 =
            switch ($P0) {
                { ($_ -match '^"') -and ($_ -match '"$') }
                { $P0.Trim('"'); break }
                { $_ -match '^"' }
                { ($Agent.Services.Data.$s.PathName).Split('"')[1]; break }
                { $_ -match '\.\S{3,}$' }
                { $P0; break }
                Default
                { $Agent.Services.Data.$s.PathName; break }
            }
            $p = $P1.Split('\')[-1]
            # Report Process Status
            $Agent.Processes.$s = @{
                "FilePath" = $P1
                "Name"     = $p -replace '\.\S{3,}$', ''
                "ID"       =
                if ($Agent.Services.Data.$s.ProcessID -eq 0)
                { $null } else { $Agent.Services.Data.$s.ProcessID }
            }
            ### Get Service Failure Behavior
            $FailureRaw = & SC.EXE QFAILURE $s 5000
            # Get Service Reset Period
            $FailureReset = (
                (
                    $FailureRaw |
                    Where-Object { $_ -like "*RESET_PERIOD*" }
                ) -split (' : ')
            )[-1]
            # Get Service Failure Actions
            $ActionIndex = 
            [Array]::IndexOf(
                $FailureRaw,
                ($FailureRaw | Where-Object { $_ -like "*FAILURE_ACTIONS*" })
            )
            if ($ActionIndex -ge 0) {
                $FailureRaw[$ActionIndex..($ActionIndex + 2)] |
                Where-Object { $_ -ne '' } |
                ForEach-Object {
                    $F1 = ($_ -split (' : '))[-1]
                    $FailureActions += @(($F1 -split (' -- '))[0].Trim())
                    $FailureDelays += @(((($F1 -split (' -- '))[-1] -split (' = '))[-1]).Split(' ')[0])
                }
            }
            # Get Service Failure Command (if present)
            $FailureCommand = (
                (
                    $FailureRaw |
                    Where-Object { $_ -like "*COMMAND_LINE*" }
                ) -split (' : ')
            )[-1]
            if ($FailureCommand -eq '')
            { $FailureCommand = $null }
            # Report Failure Behavior Status
            $Agent.Services.Failure.$s = @{
                "Actions" = @{}
                "Command" = $FailureCommand
                "Delays"  = @{}
                "Reset"   = $FailureReset
            }
            for ($i = 0; $i -lt 3; $i++) {
                $Agent.Services.Failure.$s.Actions.$(AlphaValue $i) =
                if ($null -ne $FailureActions)
                { $FailureActions[$i] } else { $null }
            }
            for ($i = 0; $i -lt 3; $i++) {
                $Agent.Services.Failure.$s.Delays.$(AlphaValue $i) =
                if ($null -ne $FailureDelays)
                { $FailureDelays[$i] } else { $null }
            }
        }
        else {
            # Write Dummy Values for Process and Service Failure Behavior
            $Agent.Processes.$s = $null
            $Agent.Services.Failure.$s = $null
        }
    }
    ### Report Current Status
    # Agent Exectuables Exist
    $Agent.Health.ProcessesExist =
    if (
        (
            $Agent.Processes.GetEnumerator() |
            Where-Object { $null -ne $_.Value.FilePath } |
            ForEach-Object { (Test-Path $_.Value.FilePath -PathType Leaf) -eq $true }
        ).Count -eq $Agent.Services.Data.Count
    )
    { $true } else { $false }
    # Agent Processes Running
    $Agent.Health.ProcessesRunning =
    if (
        ($Agent.Health.ProcessesExist -eq $true) -and
        (
            (
                $Agent.Processes.GetEnumerator() |
                ForEach-Object { $null -ne $_.Value.ID }
            ) -notcontains $false
        )
    )
    { $true } else { $false }
    # Agent Services Exist
    $Agent.Health.ServicesExist =
    if ($Agent.Services.Data.Values -notcontains $null)
    { $true } else { $false }
    # Agent Services Failure Behavior Configured
    if ($Config.EnforceBehaviorPolicy -eq $true) {
        $Agent.Health.ServicesBehaviorCorrect =
        if (
            (
                $Agent.Services.Failure.GetEnumerator() |
                ForEach-Object {
                    switch ($_) {
                        { $null -eq $_.Value }
                        { $false; break }
                        {
                            (
                                (
                                    (
                                        $_.Value.Actions.GetEnumerator() |
                                        ForEach-Object {
                                            if ($null -ne $_.Value)
                                            { $_.Value.Split()[0] -eq $Config.$("ServiceAction" + $_.Name) }
                                            else { $false }
                                        }
                                    ) -notcontains $false
                                ) -and
                                (
                                    (
                                        $_.Value.Delays.GetEnumerator() |
                                        ForEach-Object { $_.Value -eq $Config.$("ServiceDelay" + $_.Name) }
                                    ) -notcontains $false
                                ) -and
                                ($_.Value.Reset -eq $Config.ServiceReset) -and
                                ($_.Value.Command -eq $Config.ServiceCommand)
                            )
                        }
                        { $true; break }
                        Default
                        { $false; break }
                    }
                }
            ) -notcontains $false
        )
        { $true } else { $false }
    }
    else {
        $Agent.Health.ServicesBehaviorCorrect = $true
    }
    # Agent Services Running
    $Agent.Health.ServicesRunning =
    if (
        ($Agent.Health.ServicesExist -eq $true) -and
        (
            (
                $Agent.Services.Data.GetEnumerator() |
                ForEach-Object { $_.Value.State -eq "Running" }
            ) -notcontains $false
        )
    )
    { $true } else { $false }
    # Agent Services Startup Configured
    $Agent.Health.ServicesStartupCorrect =
    if (
        (
            $Agent.Services.Data.GetEnumerator() |
            ForEach-Object {
                switch ($_) {
                    { $null -eq $_.Value }
                    { $false; break }
                    {
                        ($_.Value.StartMode -eq $Config.ServiceQueryString) -and
                        (
                            ($_.Value.DelayedAutoStart -eq $Config.ServiceRequireDelay) -or
                            @(
                                if (
                                    (
                                        Get-ItemProperty (@($SC.Paths.ServiceKey, $_.Value.Name) -join '\') 2>$null |
                                        Select-Object -ExpandProperty DelayedAutoStart 2>$null
                                    ) -eq 1
                                )
                                { $Config.ServiceRequireDelay -eq $true } else { $Config.ServiceRequireDelay -eq $false }
                            )
                        )
                    }
                    { $true; break }
                    Default
                    { $false; break }
                }
            }
        ) -notcontains $false
    )
    { $true } else { $false }
}

function TestNCServer {
    ### Definitions
    ###############################
    # Function Info
    $Function.LineNumber = $MyInvocation.ScriptLineNumber
    $Function.Name = '{0}' -f $MyInvocation.MyCommand
    ### Function Body
    ###############################
    # Ping Name-Central Server and Google DNS
    for ($i = 1; $i -le $Config.PingCount; $i++) { 
        $PingNCTest += @(Test-Connection $Config.NCServerAddress -Count 1 -Quiet)
        Start-Sleep -Milliseconds 300
        $PingGoogleTest += @(Test-Connection '8.8.8.8' -Count 1 -Quiet)
        Start-Sleep -Milliseconds 300
    }
    # Check if Results Pass the Partner Threshold
    $NCSuccessRate = ($PingNCTest -like $true).Count / $PingNCTest.Count
    $NCResult =
    if ((($PingNCTest -like $true).Count / $PingNCTest.Count) -ge ($Config.PingTolerance / 100))
    { $true } else { $false }
    $GoogleSuccessRate = ($PingGoogleTest -like $true).Count / $PingGoogleTest.Count
    $GoogleResult =
    if ($GoogleSuccessRate -ge ($Config.PingTolerance / 100))
    { $true } else { $false }
    # Evaluate and Log Connectivity Check Result
    switch ($NCResult) {
        $false {
            $Out = @(
                switch ($GoogleResult) {
                    $false
                    { "Device appears not to have Internet connectivity at present.`n"; break }
                    $true
                    { ("Device appears to have Internet connectivity, but is unable to reliably connect to the " + $NC.Products.NCServer.Name + ".`n"); break }
                },
                "The Script will assess and perform Offline Repairs where possible until connectivity is restored."
            )
            Log W 0 $Out
        }
        $true {
            $Out = @(
                switch ($GoogleResult) {
                    $false { 
                        switch ($NCSuccessRate) {
                            { $_ -lt 1 } {
                                # Warn on Dropped Packets
                                $Flag = "W"
                                ("Device appears to have connectivity to the " + $NC.Products.NCServer.Name + ", but is dropping some packets.")
                                break
                            }
                            1 {
                                $Flag = "I"
                                ("Device has reliable connectivity to the " + $NC.Products.NCServer.Name + ".")
                                break
                            }
                        },
                        "However, the general Internet Connectivity Test failed. It's possible Google DNS Server is experiencing issues at present."
                        break
                    }
                    $true { 
                        switch ($NCSuccessRate) {
                            { $_ -lt 1 } {
                                # Warn on Dropped Packets
                                $Flag = "W"
                                ("Device appears to have connectivity to the " + $NC.Products.NCServer.Name + ", but is dropping some packets.")
                                break
                            }
                            1 {
                                $Flag = "I"
                                ("Device has reliable connectivity to the " + $NC.Products.NCServer.Name + ".")
                                break
                            }
                        },
                        "General Internet Connectivity is reliable."
                        break
                    }
                }
            )      
            Log $Flag 0 $Out
            break
        }
    }
    # Check if Agent has Connectivity to Server in Partner Configuration

    if ($Config.UseWSDLVerifcation -and $NCResult -eq $false) {
        $client = New-Object System.Net.WebClient
        try {
            $response = $client.DownloadString("https://$($Config.NCServerAddress)/dms2/services2/ServerEI2?wsdl")
            $xmlResponse = [xml]$response
            if ($xmlResponse.definitions.service.port.address.location -eq "https://$($Config.NCServerAddress)/dms2/services2/ServerEI2") {
                $Flag = "W"
                $Out = ("Device failed ping test, but succeeded on WSDL verification method for " + $NC.Products.NCServer.Name + ", script will proceed with online activities")             
                Log $Flag 0 $Out
            }
        }
        catch {
            $Flag = "W"
            $Out = ("WSDL verification method for " + $NC.Products.NCServer.Name + "failed, Offline Repairs will be performed possible until connectivity is restored.")             
            Log $Flag 0 $Out   
        }
    }

    $Install.NCServerAccess =
    if ($null -ne $Flag)
    { $true } else { $false }
}

function NewEncodedKey ([string]$Server, [string]$ID, [string]$token) {
    $DecodedActivationKey = "HTTPS://$($Server):443|$ID|1|$token|0"
    [Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($DecodedActivationKey))
}

function DiagnoseAgent {
    ### Parameters
    ###############################
    param ([Switch] $NoLog, [Switch] $NoServerCheck)
    ### Definitions
    ###############################
    # Function Info
    $Function.LineNumber = $MyInvocation.ScriptLineNumber
    $Function.Name = '{0}' -f $MyInvocation.MyCommand
    # Execution Info
    switch ($Script.Sequence.Order[-1]) {
        $SC.SequenceNames.D {
            Log I 0 "Re-Checking Agent Health after Repair Action(s)..."
            break
        }
        $SC.SequenceNames.E {
            if ($NoLog.IsPresent -eq $false)
            { Log I 0 "Re-Checking Agent Health after Install Action..." }
            break
        }
        Default {
            $Script.Execution.ScriptAction = "Diagnosing Existing Installation"
            WriteKey $Script.Results.ScriptKey $Script.Execution
            break
        }
    }
    ### Function Body
    ###############################
    ### Initialize/Clear Diagnostics Tables
    $Agent.Appliance = @{}
    $Agent.Docs = @{
        $NC.Products.Agent.ApplianceConfig = @{}
        $NC.Products.Agent.InstallLog      = @{}
        $SC.Names.HistoryFile              = @{}
        "Registry"                         = @{}
    }
    $Agent.Health = @{}
    $Agent.History = @{}
    ### Get Info About the Current Installation
    # Review Appliance Configuration
    if ((Test-Path $Agent.Path.ApplianceConfig -PathType Leaf) -eq $true) {
        # Read Appliance Config XML
        $Agent.Docs.$($NC.Products.Agent.ApplianceConfig) = ReadXML $Agent.Path.ApplianceConfig
        # Read Server Config XML
        $Agent.Docs.$($NC.Products.Agent.ServerConfig) = ReadXML $Agent.Path.ServerConfig
    }
    # Review Checker Log
    if ((Test-Path $Agent.Path.Checker -PathType Leaf) -eq $true) {
        # Retrieve Values
        $NC.Products.Agent.InstallLogFields |
        ForEach-Object {
            $t_Found = Select-String ($_ + "\s+:") $Agent.Path.Checker
            $Agent.Docs.$($NC.Products.Agent.InstallLog).$_ =
            if ($null -ne $t_Found)
            { ($t_Found.Line -split (' : '))[1].Trim() } else { $null }
        }
    }
    # Detect and Review Registry Uninstall Key
    $Agent.Path.Registry = (
        Get-ChildItem $NC.Paths.$("UninstallKey" + $Device.Architecture.Split('-')[0]) |
        ForEach-Object { Get-ItemProperty $_.PSPath } |
        Where-Object { $_.DisplayName -eq $NC.Products.Agent.WindowsName }
    ).PSPath
    if ($null -ne $Agent.Path.Registry) {
        $RegistryTable = @{}
        Get-ItemProperty $Agent.Path.Registry |
        Get-Member -MemberType NoteProperty |
        Select-Object -ExpandProperty Name |
        ForEach-Object { $RegistryTable.Add($_, (Get-ItemProperty $Agent.Path.Registry).$_) }
        $Agent.Docs.Registry = $RegistryTable
    }
    ### Get Info About Last Known Installation (in case Agent is Missing)
    if ((Test-Path $Agent.Path.History -PathType Leaf) -eq $true) {
        # Read Agent Configuration History XML
        $Agent.Docs.$($SC.Names.HistoryFile) = ReadXML $Agent.Path.History
    }
    ### Validate All Discovered Info
    $($Agent.Docs.Keys | Sort-Object) |
    ForEach-Object {
        $d = $_
        # Set the Appropriate Information Key for each Document
        $($Agent.Docs.$d.Keys) |
        ForEach-Object {
            $i = $_
            # Set the Appropriate Table Keys, Value Names and Match Criteria
            $AppInfo =
            switch ($i) {
                # Common Info
                "Version" {
                    switch ($d) {
                        $SC.Names.HistoryFile
                        { @($i, $SC.Validation.VersionNumber.Valid); break }
                        Default
                        { $null; break }
                    }
                    break
                }
                # Appliance Unique Info
                "ApplianceID"
                { @("ID", $NC.Validation.ApplianceID); break }
                "ApplianceVersion"
                { @("Version", $SC.Validation.VersionNumber.Valid); break }
                "CustomerID"
                { @("SiteID", $NC.Validation.CustomerID); break }
                # Checker Unique Info
                "Activation Key"
                { @("ActivationKey", $NC.Validation.ActivationKey.Encoded); break }
                "Appliance ID"
                { @("ID", $NC.Validation.ApplianceID); break }
                "Customer ID"
                { @("SiteID", $NC.Validation.CustomerID); break }
                "Install Time"
                { @("LastInstall", $null); break }
                "Package Version"
                { @("WindowsVersion", $SC.Validation.VersionNumber.Valid); break }
                # History Unique Info
                "ActivationKey"
                { @($i, $NC.Validation.ActivationKey.Encoded); break }
                "HistoryUpdated"
                { @($i, $null); break }
                "ID"
                { @($i, $NC.Validation.ApplianceID); break }
                "LastInstall"
                { @($i, $null); break }
                "ScriptSiteID"
                { @($i, $NC.Validation.CustomerID); break }
                "SiteID"
                { @($i, $NC.Validation.CustomerID); break }
                "WindowsVersion"
                { @($i, $SC.Validation.VersionNumber.Valid); break }
                # Registry Unique Info
                "DisplayVersion"
                { @($i, $SC.Validation.VersionNumber.Valid); break }
                "InstallDate"
                { @($i, $null); break }
                "InstallLocation"
                { @($i, $SC.Validation.LocalFolderPath); break }
                "UninstallString"
                { @($i, $null); break }
                # Server Unique Info
                "ServerIP"
                { @("AssignedServer", $null); break }
                Default
                { $null; break }
            }
            # Apply Additional Formatting to Select Data
            if ($null -ne $AppInfo) { 
                $FormattedInfo =
                if ($null -ne $Agent.Docs.$d.$i) {
                    switch ($i) {
                        # Date Values
                        "InstallDate" {
                            if ($Agent.Docs.Registry.InstallDate.Length -eq 8) {
                                Get-Date (
                                    @(
                                        -join $Agent.Docs.Registry.InstallDate[0..3],
                                        -join $Agent.Docs.Registry.InstallDate[4..5],
                                        -join $Agent.Docs.Registry.InstallDate[6..7]
                                    ) -join '-'
                                ) -UFormat $SC.DateFormat.Short
                            }
                            else {
                                Get-Date -UFormat $SC.DateFormat.Short
                            }
                        }
                        { @("HistoryUpdated", "Install Time", "LastInstall") -contains $_ } {
                            try
                            { Get-Date $Agent.Docs.$d.$i -UFormat $SC.DateFormat.Full }
                            catch
                            { $null }
                            break
                        }
                        # InstallLocation Value
                        "InstallLocation"
                        { ($Agent.Docs.$d.$i).Trim('\ '); break }
                        # Version Values
                        {
                            @(
                                "ApplianceVersion", "DisplayVersion", "Package Version",
                                "Version", "WindowsVersion"
                            ) -contains $_
                        } {
                            ValidateVersion $($Agent.Docs.$d.$i)
                            break
                        } 
                        Default
                        { $Agent.Docs.$d.$i; break }
                    }
                }
                else { $null }
                # Validate the Info
                $ValidatedInfo =
                if (($null -ne $FormattedInfo) -and ($FormattedInfo -match $AppInfo[1]))
                { $FormattedInfo } else { $null }
                if ($null -ne $ValidatedInfo) {
                    # Add Valid Info to Appliance/History Tables
                    if ($null -eq $Agent.$($SC.Validation.Docs.$d).$($AppInfo[0]))
                    { $Agent.$($SC.Validation.Docs.$d).$($AppInfo[0]) = $ValidatedInfo }
                }
            }
        }
    }
    ### Build Activation Key/Appliance ID from Available Parts if Required
    foreach ($t in @($($Agent.Appliance), $($Agent.History))) {
        # Activation Key
        if ($null -eq $t.ActivationKey) {
            # Build Activation Key
            $ChosenToken = 
            if ($null -ne $Install.ChosenMethod.Token) {
                $Install.ChosenMethod.Token
            }
            elseif ($null -ne $Script.RegistrationToken) {
                $Script.RegistrationToken
            }
            elseif ($null -ne $Config.RegistrationToken) {
                $Config.RegistrationToken
            }
            
            if ($null -ne $t.ID) {
                $r = $($Agent)
                $r.DecodedActivationKey = "HTTPS://$($Agent.Appliance.AssignedServer):443|$($t.ID)|1|$($ChosenToken)|0"
                # Add the Value
                $t.ActivationKey =
                [System.Convert]::ToBase64String(
                    [System.Text.Encoding]::UTF8.GetBytes($r.DecodedActivationKey)
                )
            }
        }
    }

    ### Build Activation Key ID from Available Parts if Required
    ### Build activation key from script input and Appliance ID
    # "Activation Key : Token (Current Script) / Appliance ID (Existing Installation)"
    if ($Agent.Appliance.ID -and $Script.RegistrationToken) {
        #Activation Key: Appliance Server/Appliance App ID/Script Token
        $Script.ActivationKey = NewEncodedKey $Agent.Appliance.AssignedServer $Agent.Appliance.ID $Script.RegistrationToken
    }
    
    ### Build activation key from Partner Config and Appliance ID
    # "Activation Key : Token (Partner Config) / Appliance ID (Existing Installation)"
    if ($Agent.Appliance.ID -and $Config.RegistrationToken) {
        $Config.ActivationKey = NewEncodedKey $Agent.Appliance.AssignedServer $Agent.Appliance.ID $Config.RegistrationToken
    }
    ### Update or Create Historical Configuration File if Required
    UpdateHistory
    ### Check for a Corrupt or Disabled Agent
    QueryServices
    ### Check for a Missing Agent
    # Agent is Installed
    $Agent.Health.Installed =
    if (
        ($null -ne $Agent.Path.Registry) -and
        ((ValidateItem $(@($Device.PF32, $NC.Paths.BinFolder, $NC.Products.Agent.Process) -join '\') -NoNewItem) -eq $true)
    ) {
        if ((Test-Path $Agent.Path.Registry) -eq $true)
        { $true } else { $false }
    }
    else { $false }
    # Log Discovered Agent Status
    if (($Agent.Health.Installed -eq $true) -and ($NoLog.IsPresent -eq $false)) {
        $Out = @("Found:")
        $Out += @(
            switch ($Agent.Appliance) {
                { ($null -ne $_.Version) } {
                    switch ($_.WindowsVersion) {
                        $null
                        { ($NC.Products.Agent.Name + " Version - " + $Agent.Appliance.Version) }
                        Default
                        { ($NC.Products.Agent.Name + " Version - " + $Agent.Appliance.Version + " (Windows " + $Agent.Appliance.WindowsVersion + ")") }
                    }
                }
                { $null -eq $_.Version } {
                    switch ($_.WindowsVersion) {
                        $null
                        { ($NC.Products.Agent.Name + " Version - (Windows " + $Agent.Registry.DisplayVersion + ")") }
                        Default
                        { ($NC.Products.Agent.Name + " Version - (Windows " + $Agent.Appliance.WindowsVersion + ")") }
                    }
                }
                { $null -ne $_.LastInstall }
                { ("Installed on " + (Get-Date $Agent.Appliance.LastInstall -UFormat $SC.DateFormat.FullMessageOnly)) }
                { $null -eq $_.LastInstall }
                { ("Installed on " + $InstallDate) }
            }
        )
        Log I 0 -Message $Out
    }
    ### Check if Appliance ID is Invalid
    $Agent.Health.ApplianceIDValid =
    if ($Agent.Docs.$($NC.Products.Agent.ApplianceConfig).ApplianceID -match $NC.Validation.ApplianceID)
    { $true } else { $false }
    ### Check if Installed Agent is Up to Date
    $Agent.Health.VersionCorrect =
    if ($Agent.Health.Installed) {
        if (
            (
                ($null -ne $Agent.Appliance.Version) -and
                (([Version] $Agent.Appliance.Version) -ge ([Version] $Config.AgentVersion))
            ) -or
            (
                ($null -ne $Agent.Appliance.WindowsVersion) -and
                (([Version] $Agent.Appliance.WindowsVersion) -ge ([Version] $Config.AgentFileVersion))
            )
        )
        { $true } else { $false }
    }
    else { $false }
    ### Verify Connectivity to Partner Server
    if ($NoServerCheck.IsPresent -eq $false)
    { TestNCServer }
    ### Check if Installed Agent Server Address matches Partner Configuration
    $Agent.Health.AssignedToPartnerServer =
    if ($Agent.Appliance.AssignedServer -eq $Config.NCServerAddress)
    { $true } else { $false }
    ### Summarize Agent Health
    # Update Status
    $Agent.Health.AgentStatus =
    switch ($Agent.Health) {
        { $_.Values -notcontains $false }
        { $SC.ApplianceStatus.A; break }
        { $_.Installed -eq $false }
        { $SC.ApplianceStatus.G; break }
        { @($_.ProcessesExist, $_.ServicesExist) -contains $false }
        { $SC.ApplianceStatus.F; break }
        { $_.AssignedToPartnerServer -eq $false } {
            if ($Agent.Appliance.AssignedServer -eq $NC.Products.Agent.ServerDefaultValue)
            { $SC.ApplianceStatus.C } else { $SC.ApplianceStatus.E }
            break
        }
        { @($_.ProcessesRunning, $_.ServicesRunning) -contains $false }
        { $SC.ApplianceStatus.D; break }
        { $_.ApplianceIDValid -eq $false }
        { $SC.ApplianceStatus.C; break }
        {
            @(
                $_.VersionCorrect,
                $_.ServicesBehaviorCorrect,
                $_.ServicesStartupCorrect
            ) -contains $false
        }
        { $SC.ApplianceStatus.B; break }
    }
    # Update Registry Values
    $Script.Execution.AgentLastDiagnosed = Get-Date -UFormat $SC.DateFormat.Full
    WriteKey $Script.Results.ScriptDiagnosisKey $Agent.Health
    # Identify/Log Needed Repairs
    if ($NoLog.IsPresent -eq $false) {
        $Out = @("Current Agent Status is " + $Agent.Health.AgentStatus + ":")
        $Out += @(
            switch ($Agent.Health.AgentStatus) {
                $SC.ApplianceStatus.A
                { "No Action Required"; break }
                { @($SC.ApplianceStatus.E, $SC.ApplianceStatus.F, $SC.ApplianceStatus.G) -contains $_ }
                { "Installation Required"; break }
                { @($SC.ApplianceStatus.C, $SC.ApplianceStatus.D) -contains $_ }
                { "Repair Required"; break }
                $SC.ApplianceStatus.B {
                    switch ($Agent.Health) {
                        { $_.VersionCorrect -eq $false }
                        { "Agent Update Required" }
                        { $_.ServicesBehaviorCorrect -eq $false }
                        { "Service Failure Behavior Adjustment Required" }
                        { $_.ServicesStartupCorrect -eq $false }
                        { "Service Startup Type Adjustment Required" }
                    }
                    break
                }
            }
        )
        Log I 0 $Out
    }
    # Determine Sequence Behavior After Diagnosis
    if (($Agent.Health.AgentStatus -eq $SC.ApplianceStatus.A) -and ($Script.Sequence.Order[-1] -eq $SC.SequenceNames.C)) {
        # No Further Action Required After Initial Diagnosis
        Log -EndSequence
        Log I -Code 0 -Message "No Further Action Required After Initial Diagnosis - Exiting" -Exit
    }
    # Proceed to Next Sequence or Return to Current Sequence
}

### REPAIR FUNCTIONS
###############################

function VerifyServices {
    ### Definitions
    ###############################
    # Function Info
    $Function.LineNumber = $MyInvocation.ScriptLineNumber
    $Function.Name = '{0}' -f $MyInvocation.MyCommand
    # Execution Info
    $Script.Execution.ScriptAction =
    switch ($Script.Sequence.Order[-1]) {
        $SC.SequenceNames.D
        { "Verifying Service Repair"; break }
        $SC.SequenceNames.E
        { "Monitoring Agent Services Post-Install"; break }
    }
    WriteKey $Script.Results.ScriptKey $Script.Execution
    ### Function Body
    ###############################
    # Check Current Service Status
    QueryServices
    # Verify Processes Have Not Terminated or Restarted for 2 Minutes
    do {
        $Agent.Services.Data.Keys |
        ForEach-Object {
            $s = $_
            $MatchID = $Agent.Processes.$s.ID
            $ProcessFound =
            if ($null -ne $MatchID)
            { Get-Process -Id $MatchID 2>$null }
            $ProcessMatch += @(
                if ($null -ne $ProcessFound) {
                    if ($ProcessFound.ProcessName -eq $Agent.Processes.$s.Name)
                    { $true } else { $false }
                }
                else { $false }
            )
        }
        Start-Sleep 10
    }
    while (($ProcessMatch -notcontains $false) -and ($ProcessMatch.Count -lt 12))
    # Complete/Fail Verification
    if ($ProcessMatch.Count -ge 12)
    { return $true }
    else {
        # Re-Check Current Service Status
        QueryServices
        # Re-check with the New PIDs (in case of Agent-issued Service Restart, Upgrade, etc.)
        do {
            $Agent.Services.Data.Keys |
            ForEach-Object {
                $s = $_
                $MatchID = $Agent.Processes.$s.ID
                $ProcessFound =
                if ($null -ne $MatchID)
                { Get-Process -Id $MatchID 2>$null }
                $ProcessMatch += @(
                    if ($null -ne $ProcessFound) {
                        if ($ProcessFound.ProcessName -eq $Agent.Processes.$s.Name)
                        { $true } else { $false }
                    }
                    else { $false }
                )      
                Start-Sleep 10
            }
        }
        while (($ProcessMatch -notcontains $false) -and ($ProcessMatch.Count -lt 12))
        # Complete/Fail Verification
        if ($ProcessMatch.Count -ge 12)
        { return $true } else { return $false }
    }
}

function FixServices {
    ### Parameters
    ###############################
    param ([Switch] $Restart, [Switch] $Disable)
    ### Definitions
    ###############################
    # Function Info
    $Function.LineNumber = $MyInvocation.ScriptLineNumber
    $Function.Name = '{0}' -f $MyInvocation.MyCommand
    ### Function Body
    ############################### 
    $Agent.Services.Data.Keys |
    ForEach-Object {
        $s = $_
        if ($Disable.IsPresent -eq $true) {
            ### Stop and Disable the Services Instead
            & SC.EXE CONFIG "$s" START= "Disabled" >$null 2>$null
            & TASKKILL.EXE /PID $Agent.Processes.$s.ID /F >$null 2>$null
            Get-Service -Name $s 2>$null | Stop-Service 2>$null -WarningAction SilentlyContinue
        }
        else {
            ### Start or Restart the Service
            try {
                switch ($Agent.Services.Data.$s.State) {
                    "Running" {
                        # Service Running - Attempt to Restart Only if Specified
                        if ($Restart.IsPresent -eq $true) {
                            & TASKKILL.EXE /PID $Agent.Processes.$s.ID /F >$null 2>$null
                            if (@(0, 128) -contains $LASTEXITCODE) {
                                Get-Service -Name $s | Stop-Service 2>$null -WarningAction SilentlyContinue
                                Get-Service -Name $s | Start-Service 2>&1 -ErrorAction Stop
                            }
                            else {
                                # Fail the Repair if the Process cannot be Killed
                                $RepairResult =
                                if ($RepairResult -ne $false)
                                { $false } else { $RepairResult }
                            }
                        }
                        break
                    }
                    "Stopped" {
                        # Service Stopped - Attempt to Start
                        Get-Service -Name $s | Start-Service 2>&1 -ErrorAction Stop
                        break
                    }
                    Default {
                        # Service Pending Action or Not Responding - Kill Process and Attempt to Start
                        & TASKKILL.EXE /PID $Agent.Processes.$s.ID /F >$null 2>$null
                        if (@(0, 128) -contains $LASTEXITCODE) {
                            Get-Service -Name $s | Stop-Service 2>$null -WarningAction SilentlyContinue
                            Get-Service -Name $s | Start-Service 2>&1 -ErrorAction Stop
                        }
                        else {
                            # Fail the Repair if the Process cannot be Killed
                            $RepairResult =
                            if ($RepairResult -ne $false)
                            { $false } else { $RepairResult }
                        }
                        break
                    }
                }
            }
            catch {
                # Fail the Repair if the Service cannot Start
                $RepairResult =
                if ($RepairResult -ne $false)
                { $false } else { $RepairResult }
            }
        }
    }
    if ($Disable.IsPresent -eq $false) {
        # Re-Check Service/Process Status After Repair
        $RepairResult = VerifyServices
        # Complete the Repair unless it Otherwise Failed
        $RepairResult =
        if ($RepairResult -eq $true)
        { $RepairResult } else { $false }
        return $RepairResult
    }
}

function FixOrphanedAppliance {
    ### Definitions
    ###############################
    # Function Info
    $Function.LineNumber = $MyInvocation.ScriptLineNumber
    $Function.Name = '{0}' -f $MyInvocation.MyCommand
    ### Function Body
    ###############################
    ### Replace the Appliance ID in the Appliance Configuration
    [Xml] $XMLDoc = Get-Content $Agent.Path.ApplianceConfig
    # Select the Most Recent Appliance ID to do the Replacement
    $SelectedID =
    switch ($Agent) {
        { $null -ne $_.Appliance.ID }
        { $Agent.Appliance.ID; break }
        { $null -ne $_.History.ID }
        { $Agent.History.ID; break }
        Default {
            # Fail the Repair - No Valid Appliance ID Found
            return $false
        }
    }
    $XMLDoc.ApplianceConfig.ApplianceID = $SelectedID
    $XMLDoc.Save($Agent.Path.ApplianceConfig)
    Remove-Item $Agent.Path.ApplianceConfigBackup -Force
    ### Replace the Server IPs in the Server Configuration
    [Xml] $XMLDoc = Get-Content $Agent.Path.ServerConfig
    $XMLDoc.ServerConfig.ServerIP = $Config.NCServerAddress
    $XMLDoc.ServerConfig.BackupServerIP = $Config.NCServerAddress
    $XMLDoc.Save($Agent.Path.ServerConfig)
    Remove-Item $Agent.Path.ServerConfigBackup -Force
    return $true
}

function FixStartupType {
    ### Definitions
    ###############################
    # Function Info
    $Function.LineNumber = $MyInvocation.ScriptLineNumber
    $Function.Name = '{0}' -f $MyInvocation.MyCommand
    ### Function Body
    ###############################
    $Agent.Services.Data.Keys |
    Sort-Object |
    ForEach-Object {
        $CurrentService = $_
        ### Ensure Service Startup is Configured Properly
        & SC.EXE CONFIG "$CurrentService" START= $Config.ServiceRepairString >$null 2>$null
        # Fail the Repair if Service Configuration is Unsuccessful
        $RepairResult =
        if ($RepairResult -ne $false)
        { $LASTEXITCODE -eq 0 } else { $RepairResult }
    }
    return $RepairResult
}

function FixFailureBehavior {
    ### Definitions
    ###############################
    # Function Info
    $Function.LineNumber = $MyInvocation.ScriptLineNumber
    $Function.Name = '{0}' -f $MyInvocation.MyCommand
    ### Function Body
    ############################### 
    $Agent.Services.Data.Keys |
    Sort-Object |
    ForEach-Object {
        $CurrentService = $_
        ### Ensure Service Failure Behavior is Configured Properly
        # Build Command String
        $ActionsPart = @(
            @("A", "B", "C") |
            ForEach-Object {
                $CurrentAction = $_
                @($Config.$("ServiceAction" + $CurrentAction), $Config.$("ServiceDelay" + $CurrentAction)) -join '/'
            }
        ) -join '/'
        # Configure the Service
        if ($null -ne $Config.ServiceCommand)
        { & SC.EXE FAILURE "$CurrentService" ACTIONS= $ActionsPart RESET= $Config.ServiceReset COMMAND= $Config.ServiceCommand >$null 2>$null }
        else
        { & SC.EXE FAILURE "$CurrentService" ACTIONS= $ActionsPart RESET= $Config.ServiceReset >$null 2>$null }
        # Fail the Repair if Service Configuration is Unsuccessful
        $RepairResult =
        if ($RepairResult -ne $false)
        { $LASTEXITCODE -eq 0 } else { $RepairResult }
    }
    return $RepairResult
}

function RepairAgent {
    ### Definitions
    ###############################
    # Function Info
    $Function.LineNumber = $MyInvocation.ScriptLineNumber
    $Function.Name = '{0}' -f $MyInvocation.MyCommand
    # Execution Info
    $Script.Execution.ScriptAction = "Performing Applicable Repairs"
    WriteKey $Script.Results.ScriptKey $Script.Execution
    ### Function Body
    ###############################
    ### Check if Installation is Required
    $Out = 
    switch ($Agent.Health.AgentStatus) {
        $SC.ApplianceStatus.G
        { ("The " + $NC.Products.Agent.Name + " is currently not installed."); break }
        $SC.ApplianceStatus.F
        { ("The current " + $NC.Products.Agent.Name + " installation is damaged and must be re-installed."); break }
        $SC.ApplianceStatus.E
        { ("The current " + $NC.Products.Agent.Name + " installation is not authenticating with the Partner Name-Central Server and must be re-installed."); break }
        { $Agent.Health.VersionCorrect -eq $false }
        { ("The current " + $NC.Products.Agent.Name + " installation is out of date and must be upgraded."); break }
    }
    if ($null -ne $Out) {
        # Skip Repair Sequence
        $Script.Sequence.Status[-1] = $SC.SequenceStatus.D
        Log I 0 ("The Repair Sequence was skipped. " + $Out)
    }
    else {
        ### Select Repairs to Perform
        switch ($Agent.Health) {
            { $_.ApplianceIDValid -eq $false }
            { $Repair.Required += @("A") }
            { $_.ServicesStartupCorrect -eq $false }
            { $Repair.Required += @("B") }
            { $_.ServicesBehaviorCorrect -eq $false }
            { $Repair.Required += @("C") }
            { @($_.ProcessesRunning, $_.ServicesRunning) -contains $false }
            { $Repair.Required += @("D") }
        }
        if ($null -eq $($Repair.Required)) {
            # ERROR - Repairs Required but None Selected
            Quit 101
        }
        else {
            ### Perform Selected Repairs
            $Repair.Required |
            ForEach-Object {
                switch ($_) {
                    "A" {
                        # Repair Appliance ID
                        $Repair.Results.$($SC.Repairs.$_.Name) = FixOrphanedAppliance
                    }
                    "B" {
                        # Repair Service Startup Type
                        $Repair.Results.$($SC.Repairs.$_.Name) = FixStartupType
                    }
                    "C" {
                        # Repair Service Failure Behavior
                        $Repair.Results.$($SC.Repairs.$_.Name) = FixFailureBehavior
                    }
                    "D" {
                        # Restart Agent Services/Processes
                        $Repair.Results.$($SC.Repairs.$_.Name) = FixServices
                    }
                }
            }
            ### Perform Post-Repair Actions
            # Determine Required Actions
            $Repair.Required |
            ForEach-Object { 
                $PostRepairActions += @(
                    switch ($SC.Repairs.$_.PostRepairAction) {
                        $null {
                            # No Post-Repair Action
                            break
                        }
                        Default {
                            # Add the Action to the List
                            $_
                            break
                        }
                    }
                )
            }
            # Perform Required Actions
            if ($PostRepairActions -contains $SC.RepairActions.A) {
                # Skip Recovery Actions since Installation is Required
                $Script.Sequence.Status[-1] = $SC.SequenceStatus.E
            }
            else {
                if ($PostRepairActions -contains $SC.RepairActions.B) {
                    # Restart the Agent Services
                    $Repair.Results.$($SC.Repairs.PostRepair.Name) = FixServices -Restart
                }
                ### Perform Recovery Actions if Required
                # Determine Required Actions
                $Repair.Results.Keys |
                ForEach-Object {
                    $CurrentRepair = $_
                    # Perform Recovery Actions only if the Repair Failed
                    if ($Repair.Results.$CurrentRepair -eq $false) {
                        $RecoveryActions += @(
                            switch (
                                $SC.Repairs.GetEnumerator() |
                                Where-Object { $_.Value.Name -eq $CurrentRepair } |
                                ForEach-Object { $_.Value.RecoveryAction }
                            ) {
                                $null {
                                    # No Recovery Action
                                    break
                                }
                                Default {
                                    # Add the Action to the List
                                    $_
                                    break
                                }
                            }
                        )
                    }
                }
                # Perform Required Actions
                if ($RecoveryActions -contains $SC.RepairActions.A) {
                    # Skip Remaining Recovery Actions since Installation is Required
                    $Script.Sequence.Status[-1] = $SC.SequenceStatus.E
                }
                else {
                    if ($RecoveryActions -contains $SC.RepairActions.B) {
                        # Restart the Agent Services
                        $Repair.Results.$($SC.Repairs.Recovery.Name) = FixServices -Restart
                    }
                }
            }
        }
        ### Re-Check Agent Status After Repairs
        DiagnoseAgent -NoLog -NoServerCheck
        ### Summarize Repair Results
        # Update Registry Values
        $Script.Execution.AgentLastRepaired = Get-Date -UFormat $SC.DateFormat.Full
        WriteKey $Script.Results.ScriptRepairKey $Repair.Results
        # Log Detailed Repair Results
        $Out = @("The following Repairs were attempted by the Script:")
        $Out +=
        $Repair.Results.Keys |
        Sort-Object |
        ForEach-Object {
            $CurrentRepair = $_
            $RepairStatus =
            switch ($Repair.Results.$CurrentRepair) {
                $true
                { "SUCCESS"; break }
                $false
                { "FAILURE"; break }
            }
            @($CurrentRepair + " - " + $RepairStatus)
        }
        Log I 0 $Out
        ### Determine Overall Repair Outcome
        switch ($Agent.Health.AgentStatus) {
            $SC.ApplianceStatus.A {
                # Complete Repair Sequence and Exit
                $Out = @(
                    switch ($Repair.Results) {
                        { @($_.$($SC.Repairs.PostRepair.Name), $_.$($SC.Repairs.Recovery.Name)) -contains $false } {
                            # Errors in Post-Repair/Recovery
                            "Some minor issues were encountered during Repairs, however the Script has found them to be resolved.",
                            "Possible reasons for this result may include:",
                            ("- A request to one or more " + $NC.Products.Agent.Name + " Services timed out"),
                            ("- A pre-existing operation was in place on one or more " + $NC.Products.Agent.Name + " Services")
                            break
                        }
                        Default {
                            # Agent Successfully Repaired without Issue
                            "The existing " + $NC.Products.Agent.Name + " installation was repaired successfully, without the need for installation."
                            break
                        }
                    }
                )
                Log -EndSequence
                Log I 0 $Out -Exit
            }
            Default {
                $Out = @(
                    switch ($Script.Sequence.Status[-1]) {
                        $SC.SequenceStatus.C {
                            # Fail Repair Sequence
                            $Script.Sequence.Status[-1] = $SC.SequenceStatus.F
                            switch ($Repair.Results) {
                                { # Errors in Post-Repair/Recovery
                                    @(
                                        $_.$($SC.Repairs.PostRepair.Name),
                                        $_.$($SC.Repairs.Recovery.Name)
                                    ) -contains $false
                                } {
                                    # Require Installation
                                    ("One or more Post-Repair or Recovery Actions failed. The current " + $NC.Products.Agent.Name + " must be re-installed.")
                                    break
                                }
                                Default {
                                    # Error(s) in Standard Repair
                                    ("Standard Repairs failed to fully correct all identified issues. The current " + $NC.Products.Agent.Name + " must be re-installed.")
                                    break
                                }
                            }
                        }
                        $SC.SequenceStatus.E {
                            # Abort Repair Sequence and Require an Install
                            ("The Repair Sequence was aborted. The current " + $NC.Products.Agent.Name + " cannot be fixed with standard repairs and must be re-installed.")
                            break
                        }
                    }
                )
                Log I 0 $Out
            }
        }
    }
}

### INSTALLATION FUNCTIONS
###############################

function SelectInstallers {
    ### Definitions
    ###############################
    # Function Info
    $Function.LineNumber = $MyInvocation.ScriptLineNumber
    $Function.Name = '{0}' -f $MyInvocation.MyCommand
    ### Function Body
    ###############################
    ### Validate Potential Installation Sources
    $Install.NETLOGONAccess =
    if ($Device.IsDomainJoined -eq $true) {
        try
        { Test-Path ("\\" + $Device.FQDN + "\NETLOGON") -PathType Container }
        catch [System.IO.IOException]
        { $false }
    }
    else { $false }
    # Check each Source for Required Installers
    $Install.Sources.Keys |
    Sort-Object |
    ForEach-Object {
        $CurrentSourceName = $_
        $CurrentSource = $Install.Sources.$_
        if (($CurrentSourceName -eq "Network" -or $CurrentSourceName -eq "Sysvol") -and ($Install.NETLOGONAccess -eq $false)) {
            $CurrentSource.Available = $false
            $CurrentSource.AgentFound = $false
            $CurrentSource.AgentValid = $false
            $CurrentSource.NETFound = $false
            $CurrentSource.NETValid = $false
        }
        else {  
            $CurrentSource.Available = Test-Path ($CurrentSource.Path) -PathType Container
            $CurrentSource.AgentFound =
            if ($CurrentSource.Available -eq $true) {
                # Verify Agent Installer Exists
                if (Test-Path ($CurrentSource.Path + "\" + $Config.AgentFile) -PathType Leaf) {
                    $true
                    $AgentFile = Get-Item ($CurrentSource.Path + "\" + $Config.AgentFile) 2>$null
                }
                else { $false }
            }
            else { $false }
            $CurrentSource.AgentValid =
            if ($CurrentSource.AgentFound -eq $true) {
                # Validate Agent Installer Version
                $CurrentSource.$($AgentFile.Name) = [Version] (ValidateVersion $($AgentFile.VersionInfo.FileVersion))
                if (
                    (($CurrentSource.$($AgentFile.Name)) -ne $Config.AgentFileVersion) -or
                    (($CurrentSource.$($AgentFile.Name)) -eq "0.0.0.0")
                )
                { $false } else { $true }
            }
            else { $false }
            $CurrentSource.NETFound =
            if ($CurrentSource.Available -eq $true) {
                # Verify .NET Installer Exists
                if (Test-Path ($CurrentSource.Path + "\" + $Config.NETFile) -PathType Leaf) {
                    $true
                    $NETFile = Get-Item ($CurrentSource.Path + "\" + $Config.NETFile) 2>$null
                }
                else { $false }
            }
            else { $false }
            $CurrentSource.NETValid =
            if ($CurrentSource.NETFound -eq $true) {
                # Validate .NET Installer Version
                $CurrentSource.$($NETFile.Name) = [Version] (ValidateVersion $($NETFile.VersionInfo.FileVersion))
                if (
                    (($CurrentSource.$($NETFile.Name)) -ne $Config.NETFileVersion) -or
                    (($CurrentSource.$($NETFile.Name)) -eq "0.0.0.0")
                )
                { $false } else { $true }
            }
            else { $false }
        }
        # Choose the Best Source for Each Installer
        if (@(0, $null) -contains $Install.ChosenAgent.Count) {
            # Select the Agent Source
            if ($CurrentSource.AgentValid -eq $true) {
                $Install.Sources.ChosenAgent = $CurrentSource.Path
                $Install.ChosenAgent = @{
                    "FileName"    = $AgentFile.Name
                    "InstallPath" = @($Script.Path.InstallDrop, $AgentFile.Name) -join '\'
                    "Path"        = @($Install.Sources.ChosenAgent, $AgentFile.Name) -join '\'
                    "Version"     = $CurrentSource.$($AgentFile.Name)
                }
            }
        }
        if (@(0, $null) -contains $Install.ChosenNET.Count) {
            # Select the .NET Source
            if ($CurrentSource.NETValid -eq $true) {
                $Install.Sources.ChosenNET = $CurrentSource.Path
                $Install.ChosenNET = @{
                    "FileName"    = $NETFile.Name
                    "InstallPath" = @($Script.Path.InstallDrop, $NETFile.Name) -join '\'
                    "Path"        = @($Install.Sources.ChosenNET, $NETFile.Name) -join '\'
                    "Version"     = $CurrentSource.$($NETFile.Name)
                }
            }
        }
    }
    ### Warn on Domain Joined Device with no Domain Access
    if (($Device.IsDomainJoined -eq $true) -and ($Install.NETLOGONAccess -eq $false))
    { Log W 0 ("Device is joined to the [" + $Device.FQDN + "] Domain, but either cannot currently reach a Domain Controller, or does not have access to the NETLOGON Folder.") }
    ### Log the Chosen Install Kits
    $Install.Results.SelectedAgentKit =
    switch ($Install.Sources.ChosenAgent) {
        $Install.Sources.Demand.Path
        { $SC.InstallKit.C; break }
        $Install.Sources.Network.Path
        { $SC.InstallKit.B; break }
        Default
        { $SC.InstallKit.A; break }
    }
    $Install.Results.SelectedNETKit =
    switch ($Install.Sources.ChosenNET) {
        $Install.Sources.Demand.Path
        { $SC.InstallKit.C; break }
        $Install.Sources.Network.Path
        { $SC.InstallKit.B; break }
        Default
        { $SC.InstallKit.A; break }
    }
    WriteKey $Script.Results.ScriptInstallKey $Install.Results
    ### Verify that Valid Installers were Found
    $Available =
    $Install.Sources.GetEnumerator() |
    ForEach-Object { $_.Value.Available }
    $AgentFound =
    $Install.Sources.GetEnumerator() |
    ForEach-Object { $_.Value.AgentFound }
    $NETFound =
    $Install.Sources.GetEnumerator() |
    ForEach-Object { $_.Value.NETFound }
    if (($null -ne $Install.ChosenAgent) -and ($null -ne $Install.ChosenNET))
    { Log I 0 ("Verified the correct Windows Installer versions for the " + $NC.Products.Agent.Name + " (" + $Install.ChosenAgent.Version + ") and .NET Framework (" + $Install.ChosenNET.Version + ") are available to the Script.") }
    else {
        # Display Required Installers
        $Out = @("The following Installer(s) are required by the Script in order to perform Installation Repairs on this system:")
        $Out +=
        ($Config.AgentFile + " Version - " + $Config.AgentVersion + " (Windows " + $Config.AgentFileVersion + ")"),
        ($Config.NETFile + " Version - " + (ValidateVersion $Config.NETVersion 2) + " (Windows " + (ValidateVersion $Config.NETFileVersion 2) + ")"),
        ""
        if ($Available -notcontains $true) {
            # No Installers Available from any Source
            $Out += @("No Installation Sources were available to the Script. Make sure that the relevant <SOAgentFileName>, <NETFileName>, and <InstallFolder> values in the Partner Configuration are correct and that the locations are available in the Deployment Package.")
            $ExitCode = 3
        }
        else {
            if (
                ($AgentFound -contains $true) -and
                ($NETFound -contains $true)
            ) {
                # Installer Version Mismatch
                $Out += @("The following Installer(s) were found, but do not match the Version required by the Partner Configuration:")
                switch ($Install.ChosenAgent.Version) {
                    { $null -ne $_ } {
                        # Valid Installer Found
                        break
                    }
                    Default {
                        # Collect Available Installer Paths/Versions
                        $Install.Sources.GetEnumerator() |
                        Where-Object { $_.Name -notlike "Chosen*" } |
                        ForEach-Object {
                            $AgentVersion = $_.Value.$($Config.AgentFile)
                            if ($null -ne $AgentVersion) {
                                $DisplayVersion =
                                if ($AgentVersion -eq "0.0.0.0")
                                { " - No Discovered Version" } else { (" Version - (Windows " + $AgentVersion + ")") }
                                $Out += @($Config.AgentFile + $DisplayVersion + " at " + $_.Value.Path)
                            }
                        }            
                        $Values += @("<SOAgentVersion>", "<SOAgentFileVersion>")
                        break
                    }
                }
                switch ($Install.ChosenNET.Version) {
                    { $null -ne $_ } {
                        # Valid Installer Found
                        break
                    }
                    Default {
                        # Collect Available Installer Paths/Versions
                        $Install.Sources.GetEnumerator() |
                        Where-Object { $_.Name -notlike "Chosen*" } |
                        ForEach-Object {
                            $NETVersion = $_.Value.$($Config.NETFile)
                            if ($null -ne $NETVersion) {
                                $DisplayVersion =
                                if ($NETVersion -eq "0.0.0.0")
                                { " - No Discovered Version" } else { (" Version - (Windows " + $NETVersion + ")") }
                                $Out += @($Config.NETFile + $DisplayVersion + " at " + $_.Value.Path)
                            }
                        }              
                        $Values += @("<NETVersion>", "<NETFileVersion>")
                        break
                    }
                }
                $Out +=
                "`nPlease update one of the following to the appropriate Version:",
                "- The Installer(s) listed above at their respective locations",
                "- The relevant values in the Partner Configuration:"
                $Out += @($Values)
                $ExitCode = 5
            }
            else {
                # Installer(s) Missing
                $Out += @(
                    if (($AgentFound -notcontains $true) -and ($NETFound -notcontains $true))
                    { "No Installers were found by the Script." }
                    else {
                        "The following Installer(s) were not found by the Script, or the name does not match the Partner Configuration:"
                        if ($AgentFound -notcontains $true) {
                            $Config.AgentFile
                            $MissingLocations += @($Install.Sources.ChosenAgent)
                        }
                        if ($NETFound -notcontains $true) {
                            $Config.NETFile
                            $MissingLocations += @($Install.Sources.ChosenNET)
                        }
                    }
                )
                $Out +=
                "`nVerify that the Installer(s) exist at:",
                $MissingLocations,
                "`nAlso verify that the relevant <AgentFileName> and <NETFileName> values in the Partner Configuration are correct."
                $ExitCode = 4
            }
        }
        Log E $ExitCode $Out -Exit
    }
}

function GetInstallMethods {
    ### Definitions
    ###############################
    # Function Info
    $Function.LineNumber = $MyInvocation.ScriptLineNumber
    $Function.Name = '{0}' -f $MyInvocation.MyCommand
    ### Function Body
    ###############################
    ### Get Potential Values for Installation
    $Values = @(
        $Script.ActivationKey,
        $Config.ActivationKey,        
        $Agent.History.ActivationKey,
        $Agent.Appliance.SiteID,
        ($Script.CustomerID),
        "$($Script.CustomerID)|$($Script.RegistrationToken)",
        "$($Agent.History.ScriptSiteID)|$($Agent.History.RegistrationToken)",
        "$($Config.CustomerId)|$($Config.RegistrationToken)",
        $Script.CustomerID,
        $Config.CustomerId
    )
    #Working here
    ### Populate Method Tables with Available Values
    for ($i = 0; $i -lt $Values.Count; $i++) {
        # Populate Method Tables
        $Install.MethodData.$(AlphaValue $i) = @{
            "Attempts"       = 0
            "Available"      =
            if (
                ($Agent.Health.AgentStatus -eq $SC.ApplianceStatus.E) -and
                ($i -lt 5)
            ) {
                # Only use Script Customer ID for Takeover Installations
                $false
            }
            elseif (!$Config.IsAzNableAvailable -and $SC.InstallMethods.UsesAzProxy.(AlphaValue $i)) {
                # If AzNableProxy configuration isn't available and method uses it...
                $false
            }
            elseif ($Config.IsAzNableAvailable -and $SC.InstallMethods.Type.(AlphaValue $i) -eq $SC.InstallMethods.InstallTypes.B -and $Agent.Health.Installed -eq $false) {
                # If the type is AzNableProxy, it is Activation Type install and the agent is not installed
                $false
            }
            else { $null -ne $Values[$i] -and "|" -ne $Values[$i] -and $Values[$i] -notlike "*|" }
            "Failed"         = $false
            "FailedAttempts" = 0
            "MaxAttempts"    = $SC.InstallMethods.Attempts.$(AlphaValue $i)
            "Name"           = $SC.InstallMethods.Names.$(AlphaValue $i)
            "Parameter"      =
            switch ($Values[$i]) {
                { $_ -match $NC.Validation.CustomerIDandToken }
                { $NC.InstallParameters.B; break }
                { $_ -match $NC.Validation.ActivationKey.Encoded }
                { $NC.InstallParameters.A; break }
                { $_ -match $NC.Validation.CustomerID }
                { $NC.InstallParameters.B; break }
                Default
                { $null; break }
            }
            "Value"          = $Values[$i]
            "Type"           = $SC.InstallMethods.Type.(AlphaValue $i)
        }
        # Populate Results Table only for Available Methods
        if ($Install.MethodData.$(AlphaValue $i).Available -eq $true) {
            $Install.MethodResults.$(AlphaValue $i) = @{
                "Method"           = $SC.InstallMethods.Names.$(AlphaValue $i)
                "MethodAttempts"   = 0
                "MethodSuccessful" = $null
            }
        }
    }
}

function MethodSummary {
    ### Definitions
    ###############################
    # Function Info
    $Function.LineNumber = $MyInvocation.ScriptLineNumber
    $Function.Name = '{0}' -f $MyInvocation.MyCommand
    # Execution Info
    $Script.Execution.ScriptAction = "Summarizing Installation Results"
    WriteKey $Script.Results.ScriptKey $Script.Execution
    ### Function Body
    ###############################
    # Update Registry Values
    $Script.Execution.AgentLastInstalled = Get-Date -UFormat $SC.DateFormat.Full
    WriteKey $Script.Results.ScriptInstallKey ($Install.Results + $Install.MethodResults.$($Install.ChosenMethod.Method))
    # Log Detailed Installation Results
    $Out = @("The following Installation attempts were made on the system:")
    $Out +=
    $Install.MethodResults.GetEnumerator() |
    Where-Object { $_.Value.MethodAttempts -gt 0 } |
    Select-Object -ExpandProperty Name |
    Sort-Object |
    ForEach-Object {
        $m = $_ 
        $MethodStatus =
        switch ($Install.MethodResults.$m.MethodSuccessful) {
            $true
            { "SUCCESS"; break }
            $false
            { "FAILURE"; break }
        }
        $AttemptDisplayValue =
        if ($Install.MethodResults.$m.MethodAttempts -eq 1)
        { "Attempt" } else { "Attempts" }
        @(
            $Install.MethodResults.$m.Method, "-",
            $Install.MethodResults.$m.MethodAttempts, $AttemptDisplayValue, "-",
            $MethodStatus
        ) -join ' '
    }
    Log I 0 $Out
}

function SelectInstallMethod {
    ### Definitions
    ###############################
    # Function Info
    $Function.LineNumber = $MyInvocation.ScriptLineNumber
    $Function.Name = '{0}' -f $MyInvocation.MyCommand
    ### Function Body
    ###############################
    ### Fail Current Method if Limit Exceeded
    if ($null -ne $Install.ChosenMethod.Method) {
        $MethodData = $($Install.MethodData.$($Install.ChosenMethod.Method))
        $MethodResults = $($Install.MethodResults.$($Install.ChosenMethod.Method))
        if ($Install.ChosenMethod.FailedAttempts -ge $Install.ChosenMethod.MaxAttempts) {
            # Fail the Method
            $MethodData.Failed = $true
            $MethodResults.MethodAttempts = $Install.ChosenMethod.Attempts
            $MethodResults.MethodSuccessful = $false
        }
    }
    ### Select the Next Install Method
    for ($i = 0; $i -lt $Install.MethodData.Count; $i++) {
        $MethodData = $($Install.MethodData.$(AlphaValue $i))
        if (
            ($MethodData.Available -eq $true) -and
            ($MethodData.Failed -eq $false)
        ) {
            # Check if a Different Method was Chosen than Previously
            if ($Install.ChosenMethod.Method -ne (AlphaValue $i)) {
                # Initialize New Method - Reset Attempts
                $Install.ChosenMethod = $MethodData
                $Install.ChosenMethod.Method = AlphaValue $i
            }
            # Begin a New Attempt
            $Install.ChosenMethod.Attempts++
            # Set Selection Flag
            $MethodChosen = $true
            break
        }
    }
    if ($MethodChosen -ne $true) {
        # ERROR - No Installation Methods Remaining
        MethodSummary
        $Out =
        ("All available Methods and Attempts to install the " + $NC.Products.Agent.Name + " were unsuccessful.`n"),
        ("Review the Event Log for any entries made by the " + $NC.Products.Agent.InstallerName + " Event Source for more details.")
        Log E 12 $Out -Exit
    }
}

function UpdateHistory {
    ### Definitions
    ###############################
    # Function Info
    $Function.LineNumber = $MyInvocation.ScriptLineNumber
    $Function.Name = '{0}' -f $MyInvocation.MyCommand
    ### Function Body
    ###############################
    # Update Configuration History File
    # This section is also responsible for:
    # "Activation Key : Token / Appliance ID (Historical Installation)"
    $LastUpdate =
    if ($Agent.History.Count -gt 0)
    { $Agent.History } else { @{} }
    $Agent.Appliance.GetEnumerator() |
    ForEach-Object {
        if ($null -ne $_.Value)
        { $LastUpdate.$($_.Name) = $_.Value }
    }
    $LastUpdate.HistoryUpdated = Get-Date -UFormat $SC.DateFormat.Full
    # Retain Customer IDs that were Successful in Activating the Agent
    if (
        ($null -ne $Script.CustomerID) -and
        ($Install.ChosenMethod.Value -eq $Script.CustomerID)
    )
    { $LastUpdate.ScriptSiteID = $Script.CustomerID }
    WriteXML $Agent.Path.History "Config" $LastUpdate
}

function CheckMSIService {
    ### Definitions
    ###############################
    # Function Info
    $Function.LineNumber = $MyInvocation.ScriptLineNumber
    $Function.Name = '{0}' -f $MyInvocation.MyCommand
    ### Function Body
    ###############################
    # Check if an Installation is in Progress
    for ($i = 0; $i -lt ($Config.InstallTimeoutPeriod * 6); $i++) {
        $MSI_IP = ((Get-Process -Name "msiexec" -ErrorAction SilentlyContinue).Count -gt 1)
        if ($MSI_IP -eq $false)
        { break } else { Start-Sleep 10 }
    }
    # Update Optional Counter if Timeout is Reached
    if ($i -ge ($Config.InstallTimeoutPeriod * 6)) {
        # Exit - Windows Installer Service Unavailable
        $Out = (
            "The Windows Installer Service has been unavailable for the timeout period of " +
            $Config.InstallTimeoutPeriod + " minutes.`n`n" +
            "This could be due to an Installer that is requesting user input to continue. "
        )
        $Out +=
        switch ($Script.Execution.ScriptMode) {
            $SC.ExecutionMode.A
            { "Run the Script again to re-attempt installation."; break }
            $SC.ExecutionMode.B
            { "Installation will be re-attempted at the next Device boot."; break }
        }
        $Out += " If the problem persists, consider rebooting the Device to clear any pending install operations."
        Log E 9 $Out
    }
}

function InstallNET {
    ### Definitions
    ###############################
    # Function Info
    $Function.LineNumber = $MyInvocation.ScriptLineNumber
    $Function.Name = '{0}' -f $MyInvocation.MyCommand
    # Execution Info
    $Script.Execution.ScriptAction = "Installing Prerequisite .NET Framework"
    WriteKey $Script.Results.ScriptKey $Script.Execution
    ### Function Body
    ###############################
    ### Retrieve the Chosen Installer for Local Install
    # Remove an Old Installer if it Exists
    ValidateItem $Install.ChosenNET.InstallPath -RemoveItem >$null
    # Transfer the Installer
    try
    { Copy-Item $Install.ChosenNET.Path $Install.ChosenNET.InstallPath -Force 2>&1 -ErrorAction Stop }
    catch {
        # ERROR - File Transfer Failed
        $ExceptionInfo = $_.Exception
        $InvocationInfo = $_.InvocationInfo
        CatchError 102 -Exit
    }
    # .NET Framework Install Properties
    $NET = New-Object System.Diagnostics.ProcessStartInfo ($env:windir + "\system32\cmd.exe")
    $NET.UseShellExecute = $false
    $NET.CreateNoWindow = $true
    $NET.Arguments = ('/C "' + $Install.ChosenNET.InstallPath + '" /q /norestart')
    # Check Availability of Windows Installer
    CheckMSIService
    # Install .NET Framework
    [System.Diagnostics.Process]::Start($NET).WaitForExit() >$null
    # Re-Check .NET Framework Version
    GetNETVersion
    $Out = (
        ".NET Framework Version " + (ValidateVersion $Config.NETVersion 2) +
        " is required prior to installation of " + $NC.Products.Agent.Name +
        " Version " + $Config.AgentVersion
    )
    if ($Device.NETProduct -lt (ValidateVersion $Config.NETVersion 2)) {
        # Exit - .NET Framework Installation Failed
        $Out += ". An error occurred during installation.`n`nReview the Event Log for relevant details."
        Log E 10 $Out -Exit
    }
    $Out += " and was installed successfully."
    Log I 0 $Out
}

function RemoveAgent {
    ### Definitions
    ###############################
    # Function Info
    $Function.LineNumber = $MyInvocation.ScriptLineNumber
    $Function.Name = '{0}' -f $MyInvocation.MyCommand
    ### Function Body
    ###############################
    # Agent Removal Properties
    $REM = New-Object System.Diagnostics.ProcessStartInfo ($env:windir + "\system32\cmd.exe")
    $REM.UseShellExecute = $false
    $REM.CreateNoWindow = $true
    $REM.Arguments = ('/C "' + $Agent.Registry.UninstallString + ' /QN /NORESTART"')
    # Check Availability of Windows Installer
    CheckMSIService
    # Remove the Existing Agent
    FixServices -Disable
    [System.Diagnostics.Process]::Start($REM).WaitForExit() >$null
    # Verify Removal was Successful
    DiagnoseAgent -NoLog -NoServerCheck
    if ($Agent.Health.Installed -eq $true) {

        #If the forced removal of the agent is enabled
        if ($Config.ForceAgentCleanup) {
            $FAC = New-Object System.Diagnostics.ProcessStartInfo ($env:windir + "\system32\cmd.exe")
            $FAC.UseShellExecute = $false
            $FAC.CreateNoWindow = $true
            $FAC.Arguments = ('/C "' + $Script.Path.AgentCleanup + '"')
            # Run the forced cleanup
            [System.Diagnostics.Process]::Start($FAC).WaitForExit() >$null

            # Verify Removal was Successful again
            DiagnoseAgent -NoLog -NoServerCheck

            if ($Agent.Health.Installed -eq $true) {
                # Exit - Agent Removal Failed
                FixServices -Restart
                $Out = (
                    "Forced and MSI Removal of the existing " + $NC.Products.Agent.Name + " failed. " +
                    "Manual forcible removal is required for the Script to continue."
                )
                Log E 11 $Out -Exit
            }
        }
        else {
            # Exit - Agent Removal Failed
            FixServices -Restart
            $Out = (
                "MSI Removal of the existing " + $NC.Products.Agent.Name + " failed. " +
                "Manual forcible removal is required for the Script to continue."
            )
            Log E 11 $Out -Exit
        }
        # If forced removal successful, flag existing agent removal as true
        $Install.ExistingAgentRemoved = $true
    }
    else
    { $Install.ExistingAgentRemoved = $true }
}

function VerifyPrerequisites {
    ### Definitions
    ###############################
    # Function Info
    $Function.LineNumber = $MyInvocation.ScriptLineNumber
    $Function.Name = '{0}' -f $MyInvocation.MyCommand
    # Execution Info
    $Script.Execution.ScriptAction = "Verifying Installation Requirements"
    WriteKey $Script.Results.ScriptKey $Script.Execution
    ### Function Body
    ###############################
    ### Check Connectivity to Partner Server
    if ($Install.NCServerAccess -eq $false) {
        # Exit - Installer will Fail to Authenticate with Server
        $Out =
        ("The Device is currently unable to reliably reach the " + $NC.Products.NCServer.Name + ". Installation attempts will fail authentication.`n"),
        "This may be caused by lack of Internet connectivity, a poor connection, or DNS is unavailable or unable to resolve the address.",
        "If this issue persists, verify the <NCServerAddress> value in the Partner Configuration is correct."
        Log E 6 $Out -Exit
    }
    ### Validate and Choose from Available Installers
    SelectInstallers
    ### Check if the Script has Sufficient Info to Install the Agent
    GetInstallMethods
    ### Before proceeding, run GetCustomInstallMethods, if a custom module is loaded it will override the empty function
    GetCustomInstallMethods
    # Verify at least one Method is Available for Installation
    $MethodsAvailable = (
        $Install.MethodData.Keys |
        ForEach-Object { $Install.MethodData.$_.Available }
    ) -contains $true
    if ($MethodsAvailable -ne $true) {
        # Exit - No Available Installation Methods
        $Out =
        if ($null -eq $CustomerID) {
            @("An " + $NC.Products.Agent.IDName + " was not provided to the Script and is required for Installation.`n")
            $ExitCode = 7
        }
        else {
            @("The " + $NC.Products.Agent.IDName + " provided to the Script [" + $CustomerID + "] is invalid. A valid Customer ID is required for Installation.`n")
            $ExitCode = 8
        }
        $Out +=
        switch ($Script.Execution.ScriptMode) {
            $SC.ExecutionMode.A
            { @("For On-Demand Deployment - Please specify a valid " + $NC.Products.Agent.IDName + " when running " + $SC.Names.LauncherFile + "."); break }
            $SC.ExecutionMode.B
            { @("For Group Policy Deployment - Verify the " + $NC.Products.Agent.IDName + " is free of typographical errors, and is the only item present in the Parameters field for the GPO."); break }
        }
        Log E $ExitCode $Out -Exit
    }
    ### Verify the Required Version of .NET Framework is Installed
    # Verify the Working Install Folder
    $DropFolderExists = ValidateItem $Script.Path.InstallDrop -Folder
    if ($DropFolderExists -eq $false) {
        # ERROR - Transfer Folder Creation Failed
        Quit 104
    }
    # Get the Currently Installed Product/Version
    GetNETVersion
    # Install .NET Framework if Required
    if ($Device.NETProduct -lt (ValidateVersion $Config.NETVersion 2))
    { InstallNET }
    ### Determine Required Installation Action
    $Install.RequiredAction =
    if ($Agent.Health.Installed -eq $true) {
        if (($Agent.Health.VersionCorrect -eq $true) -or ($Agent.Health.AssignedToPartnerServer -eq $false))
        { $SC.InstallActions.C } else { $SC.InstallActions.B }
    }
    else { $SC.InstallActions.A }
}

function RequestAzWebProxyToken {
    ### Definitions
    ###############################
    # Function Info
    $Function.LineNumber = $MyInvocation.ScriptLineNumber
    $Function.Name = '{0}' -f $MyInvocation.MyCommand
    # Execution Info
    $Script.Execution.ScriptAction = "Requesting AzWebproxyToken"
    WriteKey $Script.Results.ScriptKey $Script.Execution
    ### Function Body
    ###############################
    ### Attempt to connect to the AzNableProxy
    $Response = $null
    $Uri = "https://$($Config.AzNableProxyUri)/api/Get?Code=$($Config.AzNableAuthCode)&ID="
    try {
        $Uri += "$($Install.ChosenMethod.Value)"
        $Response = (Invoke-WebRequest -Method GET -Uri $Uri -UseBasicParsing).Content
    }
    catch {
        $Out = "Error retrieving token from $Uri using $($Install.ChosenMethod.Name)"
        Log E 15 $Out
    }

    ### Validate that the response is a GUID
    $Install.ChosenMethod.Token = if ($Response -match $SC.Validation.GUID) { $Response } else { $null }

    ### If the method is an Activation Key, populate the value correctly
    if ($null -ne $Install.ChosenMethod.Token -and $Install.ChosenMethod.Type -eq $SC.InstallMethods.InstallTypes.B) {
        $Install.ChosenMethod.Value = NewEncodedKey $Agent.Appliance.AssignedServer $Agent.Appliance.ID $Install.ChosenMethod.Token
    }
    else {
        $Install.ChosenMethod.Value = "$($Install.ChosenMethod.Value)|$($Install.ChosenMethod.Token)"
    }
    
}

function InstallAgent {
    ### Definitions
    ###############################
    # Function Info
    $Function.LineNumber = $MyInvocation.ScriptLineNumber
    $Function.Name = '{0}' -f $MyInvocation.MyCommand
    # Execution Info
    $Script.Execution.ScriptAction =
    switch ($Install.RequiredAction) {
        $SC.InstallActions.A
        { "Installing New Agent"; break }
        $SC.InstallActions.B
        { "Upgrading Existing Agent Installation"; break }
        $SC.InstallActions.C
        { "Replacing Existing Agent Installation"; break }
    }
    WriteKey $Script.Results.ScriptKey $Script.Execution
    ### Function Body
    ###############################
    ### Perform WSDL verfication before attempting any install or removal
    if ($Config.UseWSDLVerifcation) {
        $client = New-Object System.Net.WebClient
        try {
            $response = $client.DownloadString("https://$($Config.NCServerAddress)/dms2/services2/ServerEI2?wsdl")
            $xmlResponse = [xml]$response
            if ($xmlResponse.definitions.service.port.address.location -eq "https://$($Config.NCServerAddress)/dms2/services2/ServerEI2") {
                $Flag = "I"
                $Out = ("WSDL verification succeeded, proceeding with installation actions.")             
                Log $Flag 0 $Out
            }
            else {
                $Flag = "E"
                $Out = ("WSDL verification failed. Expected: https://$($Config.NCServerAddress)/dms2/services2/ServerEI2 Received:$($xmlResponse.definitions.service.port.address.location)")             
                Log $Flag 13 $Out
            }
        }
        catch {
            $Flag = "E"
            $Out = ("WSDL verification method for " + $NC.Products.NCServer.Name + "failed prior to install. Terminating install.")             
            Log $Flag 13 $Out -Exit  
        }
    }

    ### Attempt Agent Installation
    for (
        $Install.ChosenMethod.FailedAttempts = 0
        $true # SelectInstallMethod Function acts as the Loop Condition
        $Install.ChosenMethod.FailedAttempts++
    ) {
        ### Choose the Best Install Method
        SelectInstallMethod
        ### Build the Install String
        
        # Activation Key methods
        if ($Install.ChosenMethod.Type -eq $SC.InstallMethods.InstallTypes.A) {            
            $Install.AgentString = "/S /V`" /qn AGENTACTIVATIONKEY=$($Install.ChosenMethod.Value)"
        }
        elseif ($Install.ChosenMethod.Type -eq $SC.InstallMethods.InstallTypes.B) {
            ### Request a registration token using AzNableProxy
            RequestAzWebProxyToken
            $Install.AgentString = "/S /V`" /qn AGENTACTIVATIONKEY=$($Install.ChosenMethod.Value)"
        }

        ### Populate customer ID/String method
        else {
            $Install.AgentString = @(
                '/S /V" /qn',
                #Server address
                (@($NC.InstallParameters.D, $Config.NCServerAddress) -join '='),
                #Port
                (@($NC.InstallParameters.E, "443") -join '='),
                #Protocol
                (@($NC.InstallParameters.F, "HTTPS") -join '=')
            ) -join ' '

            # Gather the token from the AzWebproxy service if appropriate
            if ($Install.ChosenMethod.Type -eq $SC.InstallMethods.InstallTypes.D) {
                RequestAzWebProxyToken
            }
            $CustomerIDParam = $Install.ChosenMethod.Value.Split('|')[0]
            $TokenParam = $Install.ChosenMethod.Value.Split('|')[1]
            $Install.AgentString += (' ' + (@($NC.InstallParameters.B, $CustomerIDParam) -join '='))
            $Install.AgentString += (' ' + (@($NC.InstallParameters.H, $TokenParam) -join '='))
            # Customer specific flag
            $Install.AgentString += (' ' + (@($NC.InstallParameters.C, "1") -join '='))
            # Add Proxy String if it Exists
            if ($null -ne $Config.ProxyString)
            { $Install.AgentString += (' ' + (@($NC.InstallParameters.G, $Config.ProxyString) -join '=')) }
            # Complete the String
            
        }

        # Enclose install string with final quotation mark
        $Install.AgentString += '"'

        Log I 0 $Install.AgentString
        ### Set Agent Install Properties
        $INST = New-Object System.Diagnostics.ProcessStartInfo ($Install.ChosenAgent.InstallPath)
        $INST.UseShellExecute = $false
        $INST.CreateNoWindow = $true
        $INST.Arguments = $Install.AgentString
        ### Perform Required Installation Actions
        # Ensure MMC is not currently in use on the System (Prevents Service Deletion)
        foreach ($p in @("mmc", "taskmgr"))
        { Get-Process -Name $p 2>$null | Stop-Process -Force 2>$null }
        # Remove the Existing Agent if Required
        if (
            (@($SC.InstallActions.B, $SC.InstallActions.C) -contains $Install.RequiredAction) -and
            ($Agent.Health.Installed -eq $true) -and
            ($Install.ExistingAgentRemoved -ne $true)
        )
        { RemoveAgent }
        ### Retrieve the Chosen Installer for Local Install
        # Remove an Old Installer if it Exists
        ValidateItem $Install.ChosenAgent.InstallPath -RemoveItem >$null
        # Transfer the Installer
        try
        { Copy-Item $Install.ChosenAgent.Path $Install.ChosenAgent.InstallPath -Force 2>&1 -ErrorAction Stop }
        catch {
            $ExceptionInfo = $_.Exception
            $InvocationInfo = $_.InvocationInfo
            CatchError 102 -Exit
        }
        # Check Availability of Windows Installer
        CheckMSIService
        # Install the Required Agent
        $Proc = [System.Diagnostics.Process]::Start($INST)
        $Proc.WaitForExit()
        $Install.Results.InstallExitCode = $Proc.ExitCode
        ### Verify the Installation Status
        if ($Install.Results.InstallExitCode -eq 0) {
            # Wait for the Agent Services to Start
            for (
                $i = 0
                (
                    ($i -lt 12) -and
                    (
                        ($Agent.Health.ServicesExist -eq $false) -or
                        ($Agent.Health.ServicesRunning -eq $false)
                    )
                )
                $i++
            )
            { QueryServices; Start-Sleep 10 }
            # Run a Service Repair if the Agent Services Haven't Started After Install
            if ($i -ge 12)
            { $ServicesStarted = FixServices }
            if (
                (($i -ge 12) -and ($ServicesStarted -eq $true)) -or
                ($i -lt 12)
            ) {
                # Verify Services are Running Post-Install
                $Services = VerifyServices
                # Enforce Service Startup Type
                $Startup = FixStartupType
                # Enforce Service Behavior
                $Behavior = FixFailureBehavior
                $Install.Results.VerifiedServices = ($Services -eq $true) -and ($Startup -eq $true) -and ($Behavior -eq $true)
                # Re-Check Agent Health Post-Install
                DiagnoseAgent
                if (($Agent.Health.Installed -eq $true) -and ($Agent.Health.VersionCorrect -eq $true)) {
                    $Install.Results.VerifiedStatus = $true
                    $Install.MethodResults.$($Install.ChosenMethod.Method).MethodAttempts = $Install.ChosenMethod.Attempts
                    $Install.MethodResults.$($Install.ChosenMethod.Method).MethodSuccessful = $true
                    break
                }
            }
        }
    }
    ### Summarize Installation Results
    # Update Historical Configuration
    UpdateHistory
    # Summarize Methods/Attempts Taken
    MethodSummary
    ### Report Overall Installation Status
    if ($Agent.Health.AgentStatus -ne $SC.ApplianceStatus.A) {
        # Warn that Repairs May still be Needed
        $Out = @(
            $NC.Products.Agent.Name, "Version", $Config.AgentVersion,
            "was installed successfully, however, some items may still require Repair as indicated above. "
        ) -join ' '
        $Out +=
        switch ($Script.Execution.ScriptMode) {
            $SC.ExecutionMode.A
            { "Run the Script again to resolve these items."; break } 
            $SC.ExecutionMode.B
            { "These items will be resolved at the next Device boot."; break }
        }
        Log W 0 $Out
    }
    else {
        # Installation was a Complete Success
        $Out = @(
            $NC.Products.Agent.Name, "Version", $Config.AgentVersion,
            "was installed successfully! No outstanding issues were detected with the new installation."
        ) -join ' '
        Log I 0 $Out
    }
}