@ECHO OFF
SETLOCAL EnableDelayedExpansion
SET NL=^


REM = ### ABOUT
REM - Agent Setup Launcher
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

REM = ### DOWNLOAD SOURCES - May require updating as Links change/break
REM - # Service Packs
REM - Windows Vista and Server 2008 SP1
SET "SP1_Vista-x86=http://www.download.windowsupdate.com/msdownload/update/software/svpk/2008/04/windows6.0-kb936330-x86_b8a3fa8f819269e37d8acde799e7a9aea3dd4529.exe"
SET "SP1_Vista-x64=http://www.download.windowsupdate.com/msdownload/update/software/svpk/2008/04/windows6.0-kb936330-x64_12eed6cf0a842ce2a609c622b843afc289a8f4b9.exe"
REM - Windows XP 64-bit and Server 2003 SP2
SET "SP2_2003-x86=http://www.download.windowsupdate.com/msdownload/update/software/dflt/2008/02/windowsserver2003-kb914961-sp2-x86-enu_51e1759a1fda6cd588660324abaed59dd3bbe86b.exe"
SET "SP2_2003-x64=http://www.download.windowsupdate.com/msdownload/update/v3-19990518/cabpool/windowsserver2003.windowsxp-kb914961-sp2-x64-enu_7f8e909c52d23ac8b5dbfd73f1f12d3ee0fe794c.exe"
REM - Windows XP SP3
SET "SP3_XP-x86=http://www.download.windowsupdate.com/msdownload/update/software/dflt/2008/04/windowsxp-kb936929-sp3-x86-enu_c81472f7eeea2eca421e116cd4c03e2300ebfde4.exe"
REM - # .NET Framework 2.0 SP1
SET "NET2SP1=http://www.download.windowsupdate.com/msdownload/update/software/svpk/2008/01/netfx20sp1_x86_eef5a36924cdf0c02598ccf96aa4f60887a49840.exe"
REM - # PowerShell 2.0
REM - Windows Vista and Server 2008
SET "PS2_Vista_x86=http://download.windowsupdate.com/msdownload/update/software/updt/2011/02/windows6.0-kb968930-x86_16fd2e93be2e7265821191119ddfc0cdaa6f4243.msu"
SET "PS2_Vista-x64=http://download.windowsupdate.com/msdownload/update/software/updt/2011/02/windows6.0-kb968930-x64_4de013d593181a2a04217ce3b0e7536ab56995aa.msu"
REM - Windows XP 64-bit and Server 2003
SET "PS2_2003-x86=http://download.windowsupdate.com/msdownload/update/software/updt/2009/11/windowsserver2003-kb968930-x86-eng_843dca5f32b47a3bc36cb4d7f3a92dfd2fcdddb3.exe"
SET "PS2_2003-x64=http://download.windowsupdate.com/msdownload/update/software/updt/2009/11/windowsserver2003-kb968930-x64-eng_8ba702aa016e4c5aed581814647f4d55635eff5c.exe"
REM - Windows XP SP3
SET "PS2_XP-x86=http://download.windowsupdate.com/msdownload/update/software/updt/2009/11/windowsxp-kb968930-x86-eng_540d661066953d76a6907b6ee0d1cd4531c1e1c6.exe"

REM = ### DEFINITIONS
REM - Launcher Script Name
SET LauncherScript=Agent Setup Launcher
REM - Setup Script Name
SET SetupScript=Agent Setup Script
REM - Default Customer ID
SET CustomerID=%1%
REM - Working Library Folder
SET LibFolder=%TempFolder%\Lib
REM - Deployment Folder
SET DeployFolder=%~dp0
SET DeployLib=%DeployFolder%Lib
REM - OS Display Name
FOR /F "DELIMS=|" %%A IN ('WMIC OS GET NAME ^| FIND "Windows"') DO SET OSCaption=%%A
ECHO "%OSCaption%" | FIND "Server" >NUL
REM - Server OS Type
IF %ERRORLEVEL% EQU 0 (SET OSType=Server)
REM - OS Build Number
FOR /F "TOKENS=2 DELIMS=[]" %%A IN ('VER') DO SET OSBuild=%%A
SET OSBuild=%OSBuild:~8%
REM - OS Architecture
ECHO %PROCESSOR_ARCHITECTURE% | FIND "64" >NUL
IF %ERRORLEVEL% EQU 0 (SET OSArch=x64) ELSE (SET OSArch=x86)
REM - Program Files Folder
IF "%OSArch%" EQU "x64" (SET "PF32=%SYSTEMDRIVE%\Program Files (x86)")
IF "%OSArch%" EQU "x86" (SET "PF32=%SYSTEMDRIVE%\Program Files")

REM = ### BODY
ECHO == Launcher Started ==

:CheckOSRequirements
REM = Check for OS that may Require PowerShell 2.0 Installation
REM - Windows 10
IF "%OSBuild:~0,3%" EQU "10." (
  IF "%OSBuild:~3,1%" EQU 0 (GOTO LaunchScript)
)
REM - Windows 7/8/8.1 and Server 2008 R2/2012/2012 R2
IF "%OSBuild:~0,2%" EQU "6." (
  IF "%OSBuild:~2,1%" GTR 0 (GOTO LaunchScript)
)
REM - Windows Vista and Server 2008
IF "%OSBuild:~0,3%" EQU "6.0" (SET OSLevel=Vista)
REM - Windows XP x64 and Server 2003
IF "%OSBuild:~0,3%" EQU "5.2" (SET OSLevel=2003)
REM - Windows XP
IF "%OSBuild:~0,3%" EQU "5.1" (SET OSLevel=XP)
REM - Older Versions (NT and Below)
IF "%OSBuild:~0,3%" EQU "5.0" (GOTO QuitIncompatible)
IF "%OSBuild:~0,1%" LSS 5 (GOTO QuitIncompatible)

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

:CheckServicePack
REM - Create Local Working Folder
IF EXIST "%TempFolder%\*" (SET PathType=Directory)
IF EXIST "%TempFolder%" (
  IF "%PathType%" NEQ "Directory" (
    DEL /Q "%TempFolder%"
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
REM - Verify Windows Update Service is Enabled
SC CONFIG wuauserv start= delayed-auto >NUL
REM - Get Current Service Pack
SET ServicePack=0
REG QUERY "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v CSDVersion >NUL 2>NUL
IF %ERRORLEVEL% EQU 0 (
  FOR /F "TOKENS=5" %%A IN ('REG QUERY "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v CSDVersion ^| FIND "Service Pack"') DO SET ServicePack=%%A
)

:SetDownloadInfo
REM - Set Required Service Packs and Download URLs
SET "NETurl=%NET2SP1%"
REM - Windows Vista and Server 2008
IF "%OSLevel%" EQU "Vista" (
  IF "%OSArch%" EQU "x64" (
    SET "SPurl=%SP1_Vista-x64%"
    SET "PSurl=%PS2_Vista-x64%"
  ) ELSE (
    SET "SPurl=%SP1_Vista-x86%"
    SET "PSurl=%PS2_Vista-x86%"
  )
  SET RequiredPack=1
)
REM - Windows XP 64-bit and Server 2003
IF "%OSLevel%" EQU "2003" (
  IF "%OSArch%" EQU "x64" (
    SET "SPurl=%SP2_2003-x64%"
    SET "PSurl=%PS2_2003-x64%"
  ) ELSE (
    SET "SPurl=%SP2_2003-x86%"
    SET "PSurl=%PS2_2003-x86%"
  )
  SET RequiredPack=2
)
REM - Windows XP
IF "%OSLevel%" EQU "XP" (
  SET "SPurl=%SP3_XP-x86%"
  SET "PSurl=%PS2_XP-x86%"
  SET RequiredPack=3
)
IF %ServicePack% GEQ %RequiredPack% (GOTO CheckNETFramework)

:CheckSupportTools
REM - Verify Service Pack 1 for XP 64-bit and Server 2003
IF "%OSBuild:~0,3%" EQU "5.2" (
  IF %ServicePack% LSS 1 (
    SET "Message=Service Pack 1 for %OSCaption% is missing and must be installed manually in order for the Launcher to continue."
    GOTO QuitFailure
  )
)
REM - Verify Service Pack 2 for XP
IF "%OSBuild:~0,3%" EQU "5.1" (
  IF %ServicePack% LSS 2 (
    SET "Message=Service Pack 2 for %OSCaption% is missing and must be installed manually in order for the Launcher to continue."
    GOTO QuitFailure
  )
)

:InstallSupportTools
REM - Verify Tools aren't Already Present
SET "BITS=%PF32%\Support Tools\BITSADMIN.EXE"
SET "ToolsPath=%DeployFolder%PS2Install\XPTools\%OSLevel%\*"
SET ToolsFile=suptools.msi
IF NOT EXIST "%BITS%" (
  REM - Fetch Support Tools Installer
  COPY /Y "%ToolsPath%" "%TempFolder%" >NUL
  REM - Install Windows Support Tools
  IF %ERRORLEVEL% EQU 0 (
    ECHO -  Installing Windows Support Tools for %OSCaption%...
    START "" /WAIT "%WINDIR%\SYSTEM32\MSIEXEC.EXE" /I "%TempFolder%\%ToolsFile%" /QN
  ) ELSE (
    SET "Message=The Windows Support Tools installer was missing or not found after transfer."
    GOTO QuitFailure
  )
  IF %ERRORLEVEL% NEQ 0 (
    SET "Message=Support Tools Installation Failed - Error %ERRORLEVEL%"
    GOTO QuitFailure
  )
)

:GetServicePack
REM - Get Appropriate Service Pack for Install
SET "SPFile=SP%RequiredPack%_%OSLevel%-%OSArch%.exe"
REM - Fetch Service Pack Installer
IF EXIST "%DeployFolder%PS2Install\Cache\ServicePacks\%SPFile%" (
  REM - Copy from Deployment Folder
  COPY /Y "%DeployFolder%PS2Install\Cache\ServicePacks\%SPFile%" "%TempFolder%" >NUL
  GOTO InstallServicePack
)
SET Attempts=1
GOTO DownloadServicePack

:RetryDownloadServicePack
REM - Cancel the Download Job
"%BITS%" /CANCEL "SPFetch" >NUL
SET /A "Attempts = Attempts + 1"
REM - Wait Between Each Attempt
PING 192.0.2.1 -n 1 -w 30000 >NUL

:DownloadServicePack
REM - Download from the Web
START "" "%BITS%" /TRANSFER "SPFetch" "%SPurl%" "%TempFolder%\%SPFile%"

:whileServicePackDownloading
REM - Exit After too many Unsuccessful Attempts
IF %Attempts% GEQ %DLThreshold% (
  SET "Message=Multiple attempts to download Service Pack %RequiredPack% for %OSCaption% have failed. Consider installing the Package manually to proceed."
  GOTO QuitFailure
)
REM - Retrieve the Download Status
"%BITS%" /RAWRETURN /GETSTATE "SPFetch" >NUL 2>NUL
IF %ERRORLEVEL% EQU 0 (
  FOR /F %%A IN ('CALL "%BITS%" /RAWRETURN /GETSTATE "SPFetch"') DO SET DLStatus=%%A
  REM - Wait Between Each Check
  PING 192.0.2.1 -n 1 -w 10000 >NUL
) ELSE (
  REM - Download has Completed
  GOTO InstallServicePack
)
REM - Cancel and Retry Download if an Error Occurs
IF "%DLStatus%" EQU "ERROR" (GOTO RetryDownloadServicePack)
IF "%DLStatus%" EQU "TRANSIENT_ERROR" (GOTO RetryDownloadServicePack)
GOTO whileServicePackDownloading

:InstallServicePack
SET Attempts=
SET DLStatus=
REM - Install Service Pack
IF EXIST "%TempFolder%\%SPFile%" (
  ECHO -  Installing Service Pack %RequiredPack% for %OSCaption%...
  START "" /WAIT "%TempFolder%\%SPFile%" /quiet /norestart
) ELSE (
  SET "Message=Required Service Pack installer was missing or not found after transfer. (SP%RequiredPack% for %OSCaption%)"
  GOTO QuitFailure
)
IF %ERRORLEVEL% NEQ 0 (
  IF %ERRORLEVEL% EQU 3010 (
    SET "Installed=Service Pack %RequiredPack% for %OSCaption%"
    GOTO QuitRestart
  )
  SET "Message=Service Pack Installation Failed - Error %ERRORLEVEL%"
  GOTO QuitFailure
) ELSE (
  SET "Installed=Service Pack %RequiredPack% for %OSCaption%"
  GOTO QuitRestart
)

:CheckNETFramework
REM - Check Current .NET Framework
REG QUERY "HKLM\SOFTWARE\Microsoft\NET Framework Setup\NDP\v2.0.50727" /v SP 2>NUL | FIND "SP" >NUL
IF %ERRORLEVEL% EQU 0 (
  FOR /F "TOKENS=3" %%A IN ('REG QUERY "HKLM\SOFTWARE\Microsoft\NET Framework Setup\NDP\v2.0.50727" /v SP ^| FIND "SP"') DO SET NETInstalled=%%A
)
IF "%NETInstalled:~2,1%" GTR 0 (GOTO InstallPS2)

:GetNET2SP1
REM - Get Appropriate Service Pack for Install
SET "NETFile=NetFx20SP1_x86.exe"
REM - Fetch .NET Framework Installer
IF EXIST "%DeployFolder%PS2Install\Cache\NET\%NETFile%" (
  REM - Copy from Deployment Folder
  COPY /Y "%DeployFolder%PS2Install\Cache\NET\%NETFile%" "%TempFolder%" >NUL
  GOTO InstallNET2SP1
)
SET Attempts=1
GOTO DownloadNET2SP1

:RetryDownloadNET2SP1
REM - Cancel the Download Job
"%BITS%" /CANCEL "NETFetch" >NUL
SET /A "Attempts = Attempts + 1"
REM - Wait Between Each Attempt
PING 192.0.2.1 -n 1 -w 30000 >NUL

:DownloadNET2SP1
REM - Download from the Web
START "%BITS%" /TRANSFER "NETFetch" "%NETurl%" "%TempFolder%\%NETFile%"

:whileNETDownloading
REM - Exit After too many Unsuccessful Attempts
IF %Attempts% GEQ %DLThreshold% (
  SET "Message=Multiple attempts to download .NET Framework 2.0 SP1 have failed. Consider installing the Package manually to proceed."
  GOTO QuitFailure
)
REM - Retrieve the Download Status
"%BITS%" /RAWRETURN /GETSTATE "NETFetch" >NUL 2>NUL
IF %ERRORLEVEL% EQU 0 (
  FOR /F %%A IN ('CALL "%BITS%" /RAWRETURN /GETSTATE "NETFetch"') DO SET DLStatus=%%A
  REM - Wait Between Each Check
  PING 192.0.2.1 -n 1 -w 10000 >NUL
) ELSE (
  REM - Download has Completed
  GOTO InstallNET2SP1
)
REM - Cancel and Retry Download if an Error Occurs
IF "%DLStatus%" EQU "ERROR" (GOTO RetryDownloadNET2SP1)
IF "%DLStatus%" EQU "TRANSIENT_ERROR" (GOTO RetryDownloadNET2SP1)
GOTO whileNETDownloading

:InstallNET2SP1
SET Attempts=
SET DLStatus=
REM - Install .NET Framework
IF EXIST "%TempFolder%\%NETFile%" (
  ECHO -  Installing .NET Framework 2.0 SP1...
  START "" /WAIT "%TempFolder%\%NETFile%" /q /norestart
) ELSE (
  SET "Message=.NET Framework 2.0 SP1 Installer was missing or not found after transfer."
  GOTO QuitFailure
)
IF %ERRORLEVEL% NEQ 0 (
  SET "Message=.NET Framework 2.0 SP1 Installation Failed - Error %ERRORLEVEL%"
  GOTO QuitFailure
)

:GetPS2
REM - Set Appropriate Update Package Extension for Install
IF "%OSLevel%" EQU "Vista" (
  SET "PSFile=PS2_%OSLevel%-%OSArch%.msu"
) ELSE (
  SET "PSFile=PS2_%OSLevel%-%OSArch%.exe"
)
REM - Fetch PowerShell 2.0 Installer
IF EXIST "%DeployFolder%PS2Install\Cache\PowerShell\%PSFile%" (
  REM - Copy from Deployment Folder
  COPY /Y "%DeployFolder%PS2Install\Cache\PowerShell\%PSFile%" "%TempFolder%" >NUL
  GOTO InstallPS2
)
SET Attempts=1
GOTO DownloadPS2

:RetryDownloadPS2
REM - Cancel the Download Job
"%BITS%" /CANCEL "PSFetch" >NUL
SET /A "Attempts = Attempts + 1"
REM - Wait Between Each Attempt
PING 192.0.2.1 -n 1 -w 30000 >NUL

:DownloadPS2
REM - Download from the Web
START "" "%BITS%" /TRANSFER "PSFetch" "%PSurl%" "%TempFolder%\%PSFile%"

:whilePS2Downloading
REM - Exit After too many Unsuccessful Attempts
IF %Attempts% GEQ %DLThreshold% (
  SET "Message=Multiple attempts to download PowerShell 2.0 have failed. Consider installing the Package manually to proceed."
  GOTO QuitFailure
)
REM - Retrieve the Download Status
"%BITS%" /RAWRETURN /GETSTATE "PSFetch" >NUL 2>NUL
IF %ERRORLEVEL% EQU 0 (
  FOR /F %%A IN ('CALL "%BITS%" /RAWRETURN /GETSTATE "PSFetch"') DO SET DLStatus=%%A
  REM - Wait Between Each Check
  PING 192.0.2.1 -n 1 -w 10000 >NUL
) ELSE (
  REM - Download has Completed
  GOTO InstallPS2
)
REM - Cancel and Retry Download if an Error Occurs
IF "%DLStatus%" EQU "ERROR" (GOTO RetryDownloadPS2)
IF "%DLStatus%" EQU "TRANSIENT_ERROR" (GOTO RetryDownloadPS2)
REM - Continue Monitoring the Download
GOTO whilePS2Downloading

:InstallPS2
SET Attempts=
SET DLStatus=
REM - Install PowerShell 2.0
IF EXIST "%TempFolder%\%PSFile%" (
  ECHO -  Installing PowerShell 2.0 for %OSCaption%...
  START "" /WAIT "%TempFolder%\%PSFile%" /quiet /norestart
) ELSE (
  SET "Message=PowerShell 2.0 Installer was missing or not found after transfer. (%OSCaption%)"
  GOTO QuitFailure
)
IF %ERRORLEVEL% NEQ 0 (
  IF %ERRORLEVEL% EQU 3010 (
    SET Installed=PowerShell 2.0
    GOTO QuitRestart
  )
  SET "Message=PowerShell 2.0 Installation Failed - Error %ERRORLEVEL%"
  GOTO QuitFailure
) ELSE (
  SET Installed=PowerShell 2.0
  GOTO QuitRestart
)

:LaunchScript
REM - Create Local Working Folder
IF EXIST "%TempFolder%\*" (SET PathType=Directory)
IF EXIST "%TempFolder%" (
  IF "%PathType%" NEQ "Directory" (
    DEL /Q "%TempFolder%"
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
  IF "%CustomerID%" NEQ "" (
    START "" %WINDIR%\System32\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -NoLogo -NoProfile -WindowStyle Hidden -File "%TempFolder%\InstallAgent.ps1" -CustomerID %CustomerID% -LauncherPath "%DeployFolder%
    GOTO QuitSuccess
  ) ELSE (
    START "" %WINDIR%\System32\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -NoLogo -NoProfile -WindowStyle Hidden -File "%TempFolder%\InstallAgent.ps1" -LauncherPath "%DeployFolder%
    GOTO QuitSuccess
  )
) ELSE (
  SET "Message=%SetupScript% was missing or not found after transfer."
  GOTO QuitFailure
)

:QuitIncompatible
ECHO X  OS Not Compatible with either the Agent or the %SetupScript%
EVENTCREATE /T INFORMATION /ID 13 /L APPLICATION /SO "%LauncherScript%" /D "The OS is not compatible with the N-Central Agent or the %SetupScript%." >NUL
GOTO Done

:QuitFailure
ECHO X  Execution Failed - %SetupScript% Not Started (See Application Event Log for Details)
EVENTCREATE /T ERROR /ID 11 /L APPLICATION /SO "%LauncherScript%" /D "!Message!" >NUL
GOTO Cleanup

:QuitRestart
ECHO !  Reboot Required for Prerequisite Installation - Please Re-run this Script after a Reboot
EVENTCREATE /T WARNING /ID 12 /L APPLICATION /SO "%LauncherScript%" /D "The system requires a reboot for %Installed%.!NL!!NL!For Group Policy Deployments - The %LauncherScript% will start at next Domain boot.!NL!For On-Demand Deployments - Reboot the Device and re-run the %LauncherScript% to continue." >NUL
GOTO Cleanup

:QuitSuccess
ECHO O  %SetupScript% Launched Successfully
GOTO Done

:Cleanup
RD /S /Q "%TempFolder%" 2>NUL

:Done
ECHO == Launcher Finished ==
ECHO Exiting...
PING 192.0.2.1 -n 1 -w 10000 >NUL