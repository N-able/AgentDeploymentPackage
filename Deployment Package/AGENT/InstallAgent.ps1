# Installation, Diagnostic and Repair Script for the N-Central Agent
# Original Script Created by Tim Wiser
# Maintained by the Solarwinds MSP Community

################################
########## Change Log ##########
################################

### 5.0.0 on 2018-11-08 - Ryan Crowther Jr
##################################################################
# OPTIMIZATION
# - Converted InstallAgent.vbs to PowerShell 2.0 Compatible Script
#   (InstallAgent.ps1) (SEE NOTES SECTION BELOW)
# - Converted InstallAgent.ini to XML file (PartnerConfig.xml) for direct
#   parsing and variable-typing in PowerShell 2.0
# FIXES/FEATURES
# - Reworked Windows Event Log Reporting
#   1 - Detailed Script Results are packaged in a single Event
#   2 - Missing/Invalid Items required by the Script are identified along
#       with provided resolutions
#   3 - Problems discovered with the Agent are listed in addition to Repair
#       actions taken and their results
#   4 - Details regarding Installers used and Install Methods attempted
# - Reworked Windows Registry Reporting
#   1 - Prerequisite Launcher now stores Execution values in the same root
#       key as the Setup Script
#   2 - Action and Sequence Updates are made to the Registry in real time
#       as the Script progresses
# - Added Local Agent Activation Info retention (Location specified in
#   Partner Configuration)
# - Added Activation Key Builder (based on Appliance Info)
# - Script prioritizes Activation Info as follows:
#   1 - Discovered Activation Key (currently installed Agent)
#   2 - Discovered Customer/Site ID (currently installed Agent)
#   3 - Historical Activation Key (Local History File)
#   4 - Historical Customer/Site ID (Local History File)
#   5 - Default Customer ID for New Devices (GPO/Command-Line Parameter)
#   6 - Historical Default Customer ID (Local History File, if no GPO/
#       Command-Line Parameter is Present/Valid)
# - Added Repair for Invalid Appliance ID in ApplianceConfig.xml,
#   typically -1, which causes the N-Central Server to be unable to map
#   the Agent to a Device (results in an Agent that either never Imports
#   or spontaneously dies)
# - Added Legacy Agent parameters to Partner Configuration to support
#   installation/repair of an older Agent on Windows XP/Server 2003
#   (provided Agent copy is 11.0.0.1114 aka 11.0 HF3)
# - Added Takeover Action for Rogue/Competitor-Controlled Agents (if the
#   configured Server in the current installation does not match the
#   N-Central Server Address in the Partner Configuration, the Agent will
#   be reinstalled using the Script Customer ID - this also fixes an Agent
#   configured with "localhost" N-Central Server Address)
# HOUSEKEEPING
# - Re-published Change Log with most recent developments up top and some
#   basic Categories for updates
# - Moved Script Execution Registry Key to HKLM:SOFTWARE\Solarwinds MSP Community
# - Added a Legacy Version Cleanup section which will automatically remove
#   values/files created by older versions of the Script (Huge thanks to
#   Tim and Jon for their contributions!)
#
### NOTES ON POWERSHELL 2.0 CONVERSION IN 5.0.0
##################################################################
# The intent of the conversion is to:
# 1 - Maintain currency of the Scripting Platform and key features
# 2 - Remove the need to pass Configuration variables between Scripts
# 3 - Remove lesser-used/deprecated features of the original VBScript
# 4 - Categorize Script actions by Sequence for better reporting clarity
# 5 - Simplify and organize Script body by making use of PowerShell Modules

### 4.25 on 2018-01-28 - Jon Czerwinski
##################################################################
# FIXES/FEATURES
# - Detect whether .ini file is saved with ASCII encoding (Log error and
#   exit if not)

### 4.24 on 2017-10-16 - Jon Czerwinski
##################################################################
# FIXES/FEATURES
# - Rebased on .NET 4.5.2
# - Reorganized prerequisite checks

### 4.23 on 2017-10-02 - Jon Czerwinski
##################################################################
# FIXES/FEATURES
# - Bug fix on checking executable path (Special Thanks to Rod Clark!)

### 4.22 on 2017-06-21 - Jon Czerwinski
##################################################################
# FIXES/FEATURES
# - Close case where service is registered but executable is missing

### 4.21 on 2017-01-26 - Jon Czerwinski
##################################################################
# FIXES/FEATURES
# - Error checking for missing or empty configuration file

### 4.20 on 2017-01-19 - Jon Czerwinski
##################################################################
# FIXES/FEATURES
# - Moved partner-configured parameters out to AgentInstall.ini
# - Removed Windows 2000 checks
# - Cleaned up agent checks to eliminate redundant calls to StripAgent
# - Remove STARTUP|SHUTDOWN mode

### 4.10 on 2015-11-15 - Jon Czerwinski
##################################################################
# FIXES/FEATURES
# - Aligned XP < SP3 exit code with documentation (was 3, should be 1)
# - Added localhost zombie checking
# HOUSEKEEPING
# - Changed registry location to HKLM:Software\N-Central
# OPTIMIZATION
# - Refactored code (SEE NOTES SECTION BELOW)
# - Moved mainline code to subroutines, replaced literals with CONSTs
#
### NOTES ON REFACTORING IN 4.10
##################################################################
# The intent of the refactoring is:
# 1 - Shorten and simplify the mainline of code by moving larger sections of
#     mainline code to subroutines
# 2 - Replace areas where the code quit from subroutines and functions with
#     updates to runState variable and flow control in the mainline. The
#     script will quit the mainline with its final runState.
# 3 - Remove the duplication of code
# 4 - Remove inaccessible code

### 4.01 on 2015-11-09 - Jon Czerwinski
##################################################################
# FIXES/FEATURES
# - Corrected agent version zombie check

### 4.00 on 2015-02-11 - Tim Wiser
##################################################################
# FIXES/FEATURES
# - Formatting changes and more friendly startup message
# - Dirty exit now shows error message and contact information on console
# - Added 'Checking files' bit to remove confusing delay at that stage
#   (No spinner though, unfortunately)
# HOUSEKEEPING
# - Final Release by Tim Wiser :o(
# - Committed to github by Jon Czerwinski

##########################################
########## Constant Definitions ##########
##########################################

### Command-Line/Group Policy Parameters
##################################################################
param (
 [Parameter(Mandatory=$true)]
 $LauncherPath,
 [Parameter(Mandatory=$false)]
 $CustomerID
)

### N-Central Constants
##################################################################
### Current Values
# Execution Constants
$NC = @{}
# Install Constants
$NC.InstallParameters = @{
 "A" = "AGENTACTIVATIONKEY"
 "B" = "CUSTOMERID"
 "C" = "CUSTOMERSPECIFIC"
 "D" = "SERVERADDRESS"
 "E" = "SERVERPORT"
 "F" = "SERVERPROTOCOL"
 "G" = "AGENTPROXY"
}
# Path Constants
$NC.Paths = @{
 "BinFolder" = "N-Able Technologies\Windows Agent\bin"
 "ConfigFolder" = "N-Able Technologies\Windows Agent\config"
 "UninstallKey32" = "HKLM:SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
 "UninstallKey64" = "HKLM:SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
}
# Product Constants
$NC.Products = @{
 "Agent" = @{
  "ApplianceConfig" = "ApplianceConfig.xml"
  "ApplianceConfigBackup" = "ApplianceConfig.xml.backup"
  "InstallLog" = "Checker.log"
  "InstallLogFields" = @(    
   "Activation Key",
   "Appliance ID",
   "Customer ID",
   "Install Time",
   "Package Version",
   "Server Endpoint"
  )
  "InstallerName" = "Windows Agent Installer"
  "MaintenanceProcess" = "AgentMaint.exe"
  "MaintenanceService" = "Windows Agent Maintenance Service"
  "Name" = "N-Central Agent"  
  "Process" = "agent.exe"
  "ServerConfig" = "ServerConfig.xml"
  "ServerConfigBackup" = "ServerConfig.xml.backup"
  "ServerDefaultValue" = "localhost"
  "Service" = "Windows Agent Service"
  "WindowsName" = "Windows Agent"
 }
}
# Validation Constants
$NC.Validation = @{
 "ActivationKey" = @{ "Encoded" = '^[a-zA-Z0-9+/]{25,}={0,2}$' }
 "ApplianceID" = '^[0-9]{5,}$'
 "CustomerID" = '^[0-9]{3,4}$'
 "ServerAddress" = @{
  "Accepted" = '^[a-zA-Z]{3,}://[a-zA-Z_0-9\.\-]+$'
  "Valid" = '^[a-zA-Z_0-9\.\-]+$'
 }
}

### Script Constants
##################################################################
### Current Values
# Execution Constants
$SC = @{
 "DateFormat" = @{
  "FullMessageOnly" = "%Y-%m-%d at %r"
  "Full" = "%Y-%m-%d %r"
  "Short" = "%Y-%m-%d"
 }
 "ExecutionMode" = @{
  "A" = "On-Demand"
  "B" = "Group Policy"
 }
 "ErrorScriptResult" = "Script Terminated Unexpectedly"
 "InitialScriptAction" = "Importing Function Library"
 "InitialScriptResult" = "Script In Progress"
 "InstallKit" = @{
  "A" = "None Eligible"
  "B" = "Group Policy"
  "C" = "On-Demand"
 }
 "ScriptEventLog" = "Application"
 "ScriptVersion" = "5.0.0"
 "SuccessScriptAction" = "Graceful Exit"
 "SuccessScriptResult" = "Script Completed Successfully"
}
# Appliance Status Constants
$SC.ApplianceStatus = @{
 "A" = "Optimal"
 "B" = "Marginal"
 "C" = "Orphaned"
 "D" = "Disabled"
 "E" = "Rogue / Competitor-Controlled"
 "F" = "Corrupt"
 "G" = "Missing"
}
# Exit Code Constants
$SC.ExitTypes = @{
 "A" = "Successful"
 "B" = "Check Configuration"
 "C" = "Server Unavailable"
 "D" = "Unsuccessful"
 "E" = "Report This Error"
}
$SC.Exit = @{
 "Error" = @{
  "ExitResult" = "Undocumented Error (See Event Log)"
  "ExitType" = $SC.ExitTypes.E
 }
 "A" = @{
  "ExitResult" = $SC.SuccessScriptResult
  "ExitType" = $SC.ExitTypes.A
 }
 "B" = @{
  "ExitResult" = "Partner Configuration File is Missing"
  "ExitType" = $SC.ExitTypes.B
 }
 "C" = @{
  "ExitResult" = "Partner Configuration is Invalid"
  "ExitType" = $SC.ExitTypes.B
 }
 "D" = @{
  "ExitResult" = "No Installation Sources Available"
  "ExitType" = $SC.ExitTypes.B
 }
 "E" = @{
  "ExitResult" = "Installer File is Missing"
  "ExitType" = $SC.ExitTypes.B
 }
 "F" = @{
  "ExitResult" = "Installer Version Mismatch"
  "ExitType" = $SC.ExitTypes.B
 }
 "G" = @{
  "ExitResult" = "Unable to Reach Partner N-Central Server"
  "ExitType" = $SC.ExitTypes.C
 }
 "H" = @{
  "ExitResult" = "Customer ID Parameter Required"
  "ExitType" = $SC.ExitTypes.B
 }
 "I" = @{
  "ExitResult" = "Customer ID Parameter Invalid"
  "ExitType" = $SC.ExitTypes.B
 }
 "J" = @{
  "ExitResult" = "Windows Installer Service Unavailable"
  "ExitType" = $SC.ExitTypes.D
 }
 "K" = @{
  "ExitResult" = ".NET Framework Installation Failed"
  "ExitType" = $SC.ExitTypes.D
 }
 "L" = @{
  "ExitResult" = "Agent Removal Failed"
  "ExitType" = $SC.ExitTypes.D
 }
 "M" = @{
  "ExitResult" = "No Installation Methods Remaining"
  "ExitType" = $SC.ExitTypes.D
 }
 "AA" = @{
  "ExitMessage" = "An invalid Parameter value or type was provided to a Script Function."
  "ExitResult" = "Invalid Parameter"
  "ExitType" = $SC.ExitTypes.E
 }
 "AB" = @{
  "ExitMessage" = ("The current " + $NC.Products.Agent.Name + " installation requires repair, but no Repairs were selected to be applied.")
  "ExitResult" = "No Repairs Selected"
  "ExitType" = $SC.ExitTypes.E
 }
 "AC" = @{
  "ExitMessage" = "An error occurred during a file transfer and the Script cannot proceed."
  "ExitResult" = "File Transfer Failed"
  "ExitType" = $SC.ExitTypes.E
 }
 "AD" = @{
  "ExitMessage" = "The file at the specified path does not exist."
  "ExitResult" = "File Not Found"
  "ExitType" = $SC.ExitTypes.E
 }
 "AE" = @{
  "ExitMessage" = "An error occurred during item creation and the Script cannot proceed."
  "ExitResult" = "File/Folder Creation Failed"
  "ExitType" = $SC.ExitTypes.E
 }
}
# Install Constants
$SC.InstallActions = @{
 "A" = "Install New"
 "B" = "Upgrade Existing"
 "C" = "Replace Existing"
}
$SC.InstallMethods = @{
 "Attempts" = @{
  "A" = 1
  "B" = 2
  "C" = 1
  "D" = 2
  "E" = 3
  "F" = 3
 }
 "Names" = @{
  "A" = "Activation Key (Existing Installation)"
  "B" = "Customer/Site ID (Existing Installation)"
  "C" = "Activation Key (Historical Installation)"
  "D" = "Customer/Site ID (Historical Installation)"
  "E" = "Customer/Site ID (Current Script)"
  "F" = "Customer/Site ID (Last Successful Script)"
 }
}
# Name Constants
$SC.Names = @{
 "HistoryFile" = "AgentHistory.xml"
 "Launcher" = "LaunchInstaller"
 "LauncherFile" = "LaunchInstaller.bat"
 "LauncherProduct" = "Agent Setup Launcher"
 "LibraryFiles" = @("InstallAgent-Core.psm1")
 "PartnerConfig" = "PartnerConfig.xml"
 "Script" = "InstallAgent"
 "ScriptProduct" = "Agent Setup Script"
}
# Path Constants
$SC.Paths = @{
 "ExecutionKey" = "HKLM:SOFTWARE\Solarwinds MSP Community"
 "ServiceKey" = "HKLM:SYSTEM\CurrentControlSet\Services"
 "TempFolder" = Split-Path $MyInvocation.MyCommand.Path -Parent
}
$SC.Paths.EventServiceKey = @($SC.Paths.ServiceKey, "EventLog") -join '\'
# Repair Constants
$SC.RepairActions = @{
 "A" = "Install"
 "B" = "RestartServices"
}
$SC.Repairs = @{
 "PostRepair" = @{
  "Name" = "Post-Repair Actions"
 }
 "Recovery" = @{
  "Name" = "Recovery Actions"
 }
 "A" = @{
  "Name" = "Fix - Orphaned Appliance"
  "PostRepairAction" = $SC.RepairActions.B
  "RecoveryAction" = $null
 }
 "B" = @{
  "Name" = "Fix - Incorrect Service Startup Type"
  "PostRepairAction" = $null
  "RecoveryAction" = $SC.RepairActions.A
 }
 "C" = @{
  "Name" = "Fix - Incorrect Service Behavior"
  "PostRepairAction" = $null
  "RecoveryAction" = $SC.RepairActions.A
 }
 "D" = @{
  "Name" = "Fix - Process/Service Not Running"
  "PostRepairAction" = $null
  "RecoveryAction" = $SC.RepairActions.A
 }
 "E" = @{
  "Name" = "Fix - Insufficient History Data"
  "PostRepairAction" = $null
  "RecoveryAction" = $null
 }
}
# Sequence Constants
$SC.SequenceMessages = @{
 "A" = $null
 "B" = "Validating execution requirements..."
 "C" = "Diagnosing existing Agent Installation..."
 "D" = "Selecting and performing applicable repairs..."
 "E" = "Checking installation requirements..."
}
$SC.SequenceNames = @{
 "A" = "Launcher"
 "B" = "Validation"
 "C" = "Diagnosis"
 "D" = "Repair"
 "E" = "Installation"
}
$SC.SequenceStatus = @{
 "A" = "COMPLETE"
 "B" = "EXITED"
 "C" = "IN PROGRESS"
 "D" = "SKIPPED"
 "E" = "ABORTED"
 "F" = "FAILED"
}
# Validation Constants
$SC.Validation = @{
 "Docs" = @{
  $NC.Products.Agent.ApplianceConfig = "Appliance"
  $NC.Products.Agent.InstallLog = "Appliance"
  $NC.Products.Agent.ServerConfig = "Appliance"
  $SC.Names.HistoryFile = "History"
  "Registry" = "Registry"
 }
 "FileNameEXE" = '^((?![<>:"/\\|?*]).)+\.[Ee][Xx][Ee]$'
 "FileNameXML" = '^((?![<>:"/\\|?*]).)+\.[Xx][Mm][Ll]$'
 "FolderName" = '^((?![<>:"/\\|?*]).)+$'
 "InternalErrorCode" = '^1[0-9]{2}$'
 "LocalFilePathXML" = '^[a-zA-Z]:\\([^ <>:"/\\|?*]((?![<>:"/\\|?*]).)+((?<![ .])\\)?)*\.[Xx][Mm][Ll]$'
 "LocalFolderPath" = '^[a-zA-Z]:\\([^ <>:"/\\|?*]((?![<>:"/\\|?*]).)+((?<![ .])\\)?)*$'
 "TypicalErrorCode" = '^[0-9]{1,2}$'
 "VersionNumber" = @{
  "Accepted" = '^[0-9]+(\.[0-9]+){1,3}$'
  "Valid" = '^[0-9]+(\.[0-9]+){3}$' 
 }
 "VersionNumberDigits" = '^[2-4]$'
 "WholeNumberUpto2Digit" = '^[0-9]{1,2}$'
 "WholeNumberUpto3Digit" = '^[0-9]{1,3}$'
 "WholeNumberUpto4Digit" = '^[0-9]{1,4}$'
 "WholeNumberUpto5Digit" = '^[0-9]{1,5}$'
 "XMLElementName" = '^[a-zA-Z][a-zA-Z0-9_-]+$'
 "XMLElementPath" = '^/([a-zA-Z][a-zA-Z0-9_-]+/)+\*$'
}
### Retired Values - PLACE RETIRED VALUES HERE TO CLEANUP OLD SCRIPT ENTRIES
$SC.Paths.Old = @{
 "ExecutionKeyTim" = "HKLM:SOFTWARE\Tim Wiser"
 "ExecutionKey" = "HKLM:SOFTWARE\N-Central"
 "EventKey" = "HKLM:SYSTEM\CurrentControlSet\Services\EventLog\InstallAgent"
}

######################################
########## Main Script Body ##########
######################################

### INITIALIZATION SEQUENCE
##################################################################
### Create Variable Tables Required by Script
# Script Table
$Script = @{
 "Execution" = @{
  "ScriptAction" = $SC.InitialScriptAction
  "ScriptLastRan" = Get-Date -UFormat $SC.DateFormat.Full
  "ScriptResult" = $SC.InitialScriptResult
  "ScriptVersion" = [Version] $SC.ScriptVersion
 } 
 "Invocation" = $MyInvocation.MyCommand.Definition
 "Parameters" = $PSBoundParameters
 "Path" = @{
  "InstallDrop" = @($SC.Paths.TempFolder, "Fetch") -join '\'
  "Library" = @($SC.Paths.TempFolder, "Lib") -join '\'
  "PartnerFile" = @($SC.Paths.TempFolder, $SC.Names.PartnerConfig) -join '\'
  "TempFolder" = $SC.Paths.TempFolder
 }
 "Results" = @{
  "EventLog" = $SC.ScriptEventLog
  "LauncherKey" = @($SC.Paths.ExecutionKey, $SC.Names.Launcher) -join '\'
  "LauncherSource" = $SC.Names.LauncherProduct
  "ScriptEventKey" = @($SC.Paths.EventServiceKey, $SC.ScriptEventLog, $SC.Names.ScriptProduct) -join '\'
  "ScriptDiagnosisKey" = @($SC.Paths.ExecutionKey, $SC.Names.Script, "Diagnosis") -join '\'
  "ScriptInstallKey" = @($SC.Paths.ExecutionKey, $SC.Names.Script, "Installation") -join '\'
  "ScriptKey" = @($SC.Paths.ExecutionKey, $SC.Names.Script) -join '\'
  "ScriptRepairKey" = @($SC.Paths.ExecutionKey, $SC.Names.Script, "Repair") -join '\'
  "ScriptSource" = $SC.Names.ScriptProduct
 }
 "Sequence" = @{
  "Order" = @($SC.SequenceNames.A)
  "Status" = @($SC.SequenceStatus.A)
 }
}
$Script.CustomerID =
 if ($CustomerID -match $NC.Validation.CustomerID)
 { $CustomerID }
### Create Variable Tables Required by Functions
# Agent Info Table
$Agent = @{
 "Appliance" = @{}
 "Docs" = @{
  $NC.Products.Agent.ApplianceConfig = @{}
  $NC.Products.Agent.InstallLog = @{}
  $SC.Names.HistoryFile = @{}
  "Registry" = @{}
 }
 "Health" = @{}
 "HealthOptional" = @{}
 "History" = @{}
 "Path" = @{}
 "Processes" = @{}
 "Registry" = @{}
 "Services" = @{
  "Data" = @{
   $NC.Products.Agent.Service = $null
   $NC.Products.Agent.MaintenanceService = $null
  }
  "Failure" = @{}
 }
}
# Device Info Table
$Device = @{}
# Function Info Table
$Function = @{
 "Action" = $null
 "LineNumber" = $MyInvocation.ScriptLineNumber
 "Name" = '{0}' -f $MyInvocation.MyCommand
}
# Install Info Table
$Install = @{
 "ChosenMethod" = @{}
 "MethodData" = @{}
 "MethodResults" = @{}
 "Results" = @{}
}
# Partner Configuration Table
$Config = @{}
# Repair Info Table
$Repair = @{
 "Required" = @()
 "Results" = @{}
}
### Write Registry Values for Script Startup
# Create Script Execution Key if Required
if ((Test-Path $Script.Results.ScriptKey) -eq $false)
{ New-Item $Script.Results.ScriptKey -Force >$null }
else
{ # Remove Sequence Data from Previous Run
  Get-ChildItem $Script.Results.ScriptKey | Remove-Item -Force
  # Remove Transient Properties from Previous Run
  Get-ItemProperty $Script.Results.ScriptKey |
  Get-Member -MemberType NoteProperty |
  Where-Object { $_.Name -match '^Script' } |
  ForEach-Object { Remove-ItemProperty "HKLM:SOFTWARE\Solarwinds MSP Community\InstallAgent" -Name $_.Name -Force }
}
# Update Execution Properties
$Script.Execution.Keys |
ForEach-Object { New-ItemProperty -Path $Script.Results.ScriptKey -Name $_ -Value $Script.Execution.$_ -Force >$null }
### Import Library Items
$SC.Names.LibraryFiles |
ForEach-Object {
  $ModuleName = $_
  try
  { Import-Module $(@($Script.Path.Library, $ModuleName) -join '\') -ErrorAction Stop }
  catch
  { # Get the Exception Info
    $ExceptionInfo = $_.Exception
    # Create a New Key for the Event Source if Required
    $Script.Execution.LastResult = $SC.ErrorScriptResult
    if ((Test-Path $Script.Results.ScriptEventKey) -eq $false)
    { New-EventLog -Source $Script.Results.ScriptSource -LogName $Script.Results.EventLog }
    # Write the Event
    $Message = (
      "The Function Library for the Agent Setup Script is either missing or corrupt. Please verify " +
      $ModuleName +
      " exists in the [" +
      $Script.Path.Library + "] folder, or restore the file to its original state.`n"
    )
    Write-EventLog -LogName $Script.Results.EventLog -Source $Script.Results.ScriptSource -EventID 9999 -EntryType "Error" -Message $Message -Category 0
    # Cleanup Working Folder
    Remove-Item $Script.Path.TempFolder -Force -Recurse 2>$null
    exit
  }
}
### Import Partner Configuration
try
{ [Xml] $Partner = Get-Content $Script.Path.PartnerFile 2>&1 -ErrorAction Stop }
catch
{
  $ExceptionInfo = $_.Exception
  $InvocationInfo = $_.InvocationInfo
  CatchError 1 ("Unable to read Partner Configuration at [" + $Script.Path.PartnerFile + "]") -Exit
}
### Get Local Device Info
GetDeviceInfo
### Populate Agent Log Paths using Discovered Device Info
$Agent.Path = @{
 "Checker" = @($Device.PF32, $NC.Paths.BinFolder, $NC.Products.Agent.InstallLog) -join '\'
 "ApplianceConfig" = @($Device.PF32, $NC.Paths.ConfigFolder, $NC.Products.Agent.ApplianceConfig) -join '\'
 "ApplianceConfigBackup" = @($Device.PF32, $NC.Paths.ConfigFolder, $NC.Products.Agent.ApplianceConfigBackup) -join '\'
 "ServerConfig" = @($Device.PF32, $NC.Paths.ConfigFolder, $NC.Products.Agent.ServerConfig) -join '\'
 "ServerConfigBackup" = @($Device.PF32, $NC.Paths.ConfigFolder, $NC.Products.Agent.ServerConfigBackup) -join '\'
}
### Elevate Privilege and Re-Run if Required
SelfElevate

#########################################
########## Main Execution Body ##########
#########################################

try
{ ### VALIDATION SEQUENCE
  ##################################################################
  Log -BeginSequence -Message $SC.SequenceMessages.B -Sequence $SC.SequenceNames.B
  # Validate Partner Configuration Values
  ValidatePartnerConfig
  # Validate Execution Mode
  ValidateExecution
  Log -EndSequence
  ##################################################################
  ###

  ### DIAGNOSIS SEQUENCE
  ##################################################################
  Log -BeginSequence -Message $SC.SequenceMessages.C -Sequence $SC.SequenceNames.C
  # Diagnose Current Installation Status
  DiagnoseAgent
  Log -EndSequence
  ##################################################################
  ###

  ### REPAIR SEQUENCE
  ##################################################################
  Log -BeginSequence -Message $SC.SequenceMessages.D -Sequence $SC.SequenceNames.D
  # Repair the Current Installation
  RepairAgent
  Log -EndSequence
  ##################################################################
  ###

  ### INSTALL SEQUENCE
  ##################################################################
  Log -BeginSequence -Message $SC.SequenceMessages.E -Sequence $SC.SequenceNames.E
  # Verify Install Prerequisites
  VerifyPrerequisites
  # Replace/Upgrade or Install a New Agent
  InstallAgent
  Log -EndSequence
  ##################################################################
  ###
}
catch
{ # Terminate Abnormally (Undocumented Error Occurred)
  $ExceptionInfo = $_.Exception
  $InvocationInfo = $_.InvocationInfo
  CatchError -Exit
}

# Terminate Successfully
Quit 0