@ECHO OFF
SETLOCAL EnableDelayedExpansion
SET NL=^


REM = ### ABOUT
REM - Agent Setup Launcher
REM   Updated by David B, PTS. Robby S, b-inside. 2021-02-21
REM   by Ryan Crowther Jr, RADCOMP Technologies - 2019-08-26
REM - Original Script (InstallAgent.vbs) by Tim Wiser, GCI Managed IT - 2015-03

REM = ### USAGE
REM - This Launcher should ideally be called by a Group Policy with the
REM   client's Customer-Level N-Central ID as the only Parameter, but may
REM   also be run On-Demand from another local or network location, using
REM   the same argument. See the README.md for detailed Deployment Steps.

REM = ### KNOWN ISSUES
REM - WIC Installation Method not yet implemented, this affects:
REM   -- Confirmed - Windows XP 64-bit (WIC must be installed manually after Service Pack 2 is installed)
REM   -- Untested - Windows Server 2003 (same behavior expected, since XP-64 was based on this Build)

REM = ### USER DEFINITIONS - Feel free to change these
REM - Working Folder
SET TempFolder=C:\Windows\Temp\AGPO
REM - Maximum Download Attempts (per File)
SET DLThreshold=3
REM - Don't use the arguments. This way, CustomerID and Registration Token aren't taken from the arguments. This to support older GPO's, that had CustomerID and Domainname as arguments
SET NoArgs=0
REM = ### DEFINITIONS
@ECHO OFF
set ArgCount=0
IF %NoArgs% EQU 0 (
  FOR %%x in (%*) do (
    set /A ArgCount+=1
  )
)
ECHO Number of arguments: %ArgCount%
REM - Launcher Script Name
SET "LauncherScript=Agent Setup Launcher"
ECHO %LauncherScript%
REM - Setup Script Name
SET "SetupScript=Agent Setup Script"
REM - Default Customer ID
SET CustomerID=%1%
REM - Activation token
SET RegistrationToken=%2%
REM - Working Library Folder
SET LibFolder=%TempFolder%\Lib
REM - Deployment Folder
SET DeployFolder=%~dp0
echo %DeployFolder%
SET DeployLib=%DeployFolder%Lib
REM - OS Display Name
FOR /F "DELIMS=|" %%A IN ('WMIC OS GET NAME ^| FIND "Windows"') DO SET OSCaption=%%A
ECHO "%OSCaption%" | FIND "Server" >NUL
REM - Server OS Type - Next line is Legacy
REM IF %ERRORLEVEL% EQU 0 (SET OSType=Server)
REM - OS Build Number
FOR /F "TOKENS=2 DELIMS=[]" %%A IN ('VER') DO SET OSBuild=%%A
SET OSBuild=%OSBuild:~8%
REM - OS Architecture - Next 2 lines are obsolete
REM ECHO %PROCESSOR_ARCHITECTURE% | FIND "64" >NUL
REM IF %ERRORLEVEL% EQU 0 (SET OSArch=x64) ELSE (SET OSArch=x86)
REM - Program Files Folder - Next 2 lines are obsolete
REM IF "%OSArch%" EQU "x64" (SET "PF32=%SYSTEMDRIVE%\Program Files (x86)")
REM IF "%OSArch%" EQU "x86" (SET "PF32=%SYSTEMDRIVE%\Program Files")

REM = ### BODY
ECHO == Launcher Started ==

:CheckOSRequirements
REM = Check for OS that may Require PowerShell 2.0 Installation
REM - Windows 10
IF "%OSBuild:~0,3%" EQU "10." (
  IF %OSBuild:~3,1% EQU 0 (GOTO LaunchScript)
)
REM - Windows 7/8/8.1 and Server 2008 R2/2012/2012 R2
IF "%OSBuild:~0,2%" EQU "6." (
  IF %OSBuild:~2,1% GTR 0 (GOTO LaunchScript)
)
REM - Windows Vista and Server 2008
SET LegacyWait=0
IF "%OSBuild:~0,3%" EQU "6.0" (SET LegacyWait=1)
REM - Windows XP x64 and Server 2003
IF "%OSBuild:~0,3%" EQU "5.2" (GOTO QuitIncompatible)
REM - Windows XP
IF "%OSBuild:~0,3%" EQU "5.1" (GOTO QuitIncompatible)
REM - Older Versions (NT and Below)
IF "%OSBuild:~0,3%" EQU "5.0" (GOTO QuitIncompatible)
IF %OSBuild:~0,1% LSS 5 (GOTO QuitIncompatible)

:CheckPSVersion
REM - Verify PowerShell Installation
REG QUERY "HKLM\SOFTWARE\Microsoft\PowerShell\1" /v Install 2>NUL | FIND "Install" >NUL
IF %ERRORLEVEL% EQU 0 (
  FOR /F "TOKENS=3" %%A IN ('REG QUERY "HKLM\SOFTWARE\Microsoft\PowerShell\1" /v Install ^| FIND "Install"') DO SET PSInstalled=%%A
)
IF "%PSInstalled%" EQU "0x1" (
  REM - Get PowerShell Version
  FOR /F "TOKENS=3" %%A IN ('REG QUERY "HKLM\SOFTWARE\Microsoft\PowerShell\1\PowerShellEngine" /v PowerShellVersion ^| FIND "PowerShellVersion"') DO SET PSVersion=%%A
)
IF "%PSVersion%" EQU "2.0" (GOTO LaunchScript)

:LaunchScript
REM - Create Local Working Folder
IF EXIST "%TempFolder%\*" (SET PathType=Directory)
IF EXIST "%TempFolder%" (
  IF "%PathType%" NEQ "Directory" (
REM    DEL /Q "%TempFolder%"
    MKDIR "%TempFolder%"
  )
) ELSE (MKDIR "%TempFolder%")
SET PathType=
IF EXIST "%LibFolder%\*" (SET PathType=Directory)
IF EXIST "%LibFolder%" (
  IF "%PathType%" NEQ "Directory" (
    DEL /Q "%LibFolder%"
    MKDIR "%LibFolder%"
  )
) ELSE (MKDIR "%LibFolder%")
SET PathType=
REM - Fetch Script Items
COPY /Y "%DeployFolder%*" "%TempFolder%" >NUL
COPY /Y "%DeployLib%\*" "%LibFolder%" >NUL
IF %ERRORLEVEL% EQU 0 (
  REM - Launch Agent Setup Script
  IF %ArgCount% EQU 0 (
      GOTO PARTNERCONFIG
  )
  IF %ArgCount% EQU 1 (
       GOTO CUSTOMERIDONLY 
  )
  IF %ArgCount% EQU 2 (
      GOTO CUSTOMERANDTOKEN
  )
) ELSE (
  SET "Message=%SetupScript% was missing or not found after transfer."
  GOTO QuitFailure
)

:CUSTOMERANDTOKEN
ECHO Running with customer and token
START "" %WINDIR%\System32\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -NoLogo -NoProfile -WindowStyle Hidden -File "%TempFolder%\InstallAgent.ps1" -CustomerID %CustomerID% -RegistrationToken %RegistrationToken% -LauncherPath "%DeployFolder%
IF %ERRORLEVEL% EQU 0 (
  GOTO QuitSuccess
) ELSE (
  GOTO QuitFailure
)

:CUSTOMERIDONLY
ECHO Running with Customer ID Only
START "" %WINDIR%\System32\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -NoLogo -NoProfile -WindowStyle Hidden -File "%TempFolder%\InstallAgent.ps1" -CustomerID %CustomerID% -LauncherPath "%DeployFolder%
IF %ERRORLEVEL% EQU 0 (
  GOTO QuitSuccess
) ELSE (
  GOTO QuitFailure
)

:PARTNERCONFIG
ECHO Using Partner config
START "" %WINDIR%\System32\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -NoLogo -NoProfile -WindowStyle Hidden -File "%TempFolder%\InstallAgent.ps1" -LauncherPath "%DeployFolder%
IF %ERRORLEVEL% EQU 0 (
  GOTO QuitSuccess
) ELSE (
  GOTO QuitFailure
)

:QuitIncompatible
ECHO X  OS Not Compatible with either the Agent or the %SetupScript%
EVENTCREATE /T ERROR /ID 13 /L APPLICATION /SO "%LauncherScript%" /D "The OS is not compatible with the N-Central Agent or the %SetupScript%." >NUL
SET LegacyWait=1
GOTO Done

:QuitFailure
ECHO X  Execution Failed - %SetupScript% Not Started (See Application Event Log for Details)
EVENTCREATE /T ERROR /ID 11 /L APPLICATION /SO "%LauncherScript%" /D "!Message!" >NUL
GOTO Cleanup

:QuitSuccess
ECHO O  %SetupScript% Launched Successfully
EVENTCREATE /T INFORMATION /ID 10 /L APPLICATION /SO "%LauncherScript%" /D "Agent Setup Launcher successful" >NUL
GOTO Done

:Cleanup
RD /S /Q "%TempFolder%" 2>NUL

:Done
ECHO == Launcher Finished ==
ECHO Exiting...

PING 192.0.2.1 -n 10 -w 1000 >NUL