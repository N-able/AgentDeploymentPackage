function RequestAzWebProxyToken {
    <#
    Example function override for RequestAzWebProxyToken
    
    The the Azure function we can take more than one parameter in the GET function.
    while the $Install.ChosenMethod.Value contains the one parameter used to retrieve the token
    the rest of the parameters passed can be taken and added inserted to a table inside the function
    that data from the table can be later used to generate a HTML report
    or opened in an Excel spreadsheet etc. 
    
    #>

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
        
        ### ... And here is the change ...
        ###  |||||||||||||||||||||||||||||||
        ### VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV
        ### We add our own custom params to get custom data on devices using the AzNableProxy service
        $Uri += "&HostName=$($device.HostName)&OSName=$($device.OSName)"
        $Uri += "&ApplianceID=$($agent.Appliance.ID)"
        $Response = Invoke-RestMethod -Method GET -Uri $Uri
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
<# This Quit function is copied from the orginal InstallAgent-Core.psm1 but modifed slightly
    By declaring the function in a module loaded after the original one, the 
#>
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
        $Script.Results.Details += @("`Name== Error Details ==")
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
    $Script.Results.EventMessage += @("Overall Script Result:  " + $SC.Exit.$LCode.ExitType + "`Name")
    # Add the Completion Status of Each Sequence
    $Script.Sequence.Order |
    ForEach-Object {
        $Script.Results.EventMessage += @(
            $_,
            $Script.Sequence.Status[([Array]::IndexOf($Script.Sequence.Order, $_))]
        ) -join ' - '
    }
    # Add the Detailed Messages for Each Sequence
    $Script.Results.EventMessage += @("`Name" + ($Script.Results.Details -join "`Name"))
    # For Typical Errors, Add the Branded Error Contact Message from Partner Configuration
    if (
        ($Code -ne 999) -and
        ($Code -ne 0) -and
        ($null -ne $Config.ErrorContactInfo)
    ) {
        $Script.Results.EventMessage +=
        "`Name--=========================--",
        "`nTo report this documented issue, please submit this Event Log entry to:`Name",
        $Config.ErrorContactInfo
    }
    # Combine All Message Items
    $Script.Results.EventMessage = ($Script.Results.EventMessage -join "`Name").TrimEnd('')
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

    ### ... And here is the change ...
    ###  |||||||||||||||||||||||||||||||
    ### VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV
    ### We gather together important variables and results into a hashtable
    
    $POST = @{}
    $POST.Appliance = $Agent.Appliance
    $POST.EventMsg = $Script.Results.EventMessage
    $POST.$Config = $Config
    $POST.InstallMethodData = $Install.MethodData
    $POST.ResultCode = $Code

    # We convert it to JSON
    $POST = $POST | ConvertTo-Json -Depth 5 -Compress

    # Assemble the URL
    $Uri = "https://$($Config.AzNableProxyUri)/api/Post?Code=$($Config.AzNableAuthCode)"
    try {
        # Then POST the JSON body to our Azure service.       
        Invoke-RestMethod -Method POST -Uri $Uri -Body $POST
    } catch {
        Write-Host "Error uploading telemetry to Azure"
    }

    exit $Code
}