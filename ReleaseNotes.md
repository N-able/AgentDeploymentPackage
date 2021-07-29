# 2021-05-7 - 6.0.2
* Fixed bug with Invoke-Webrequest not working due to absence of -UseBasicParsing per [#36](https://github.com/AngryProgrammerInside/InstallAgent/issues/36)
* Added forced removal/cleanup when bad MSI uninstall information or MSI unable to remove old/rogue agent when needed. [#37](https://github.com/AngryProgrammerInside/InstallAgent/issues/37)
* Added WSDL based server verification for environments where outbound ICMP is disabled [#38](https://github.com/AngryProgrammerInside/InstallAgent/issues/38)
* Fixed bug with InstallAgent process not being spun off Async unless -Monitor flag used [#39](https://github.com/AngryProgrammerInside/InstallAgent/issues/39)
* Fixed up Partner Config file validation of True/False attributes

# 2021-04-12 - 6.0.1

## Fixes
* Fixed bug with 64-bit detection on languages other than english
* Fixed bug where agent services would be disabled on Windows 7 / 2008 R2 / PowerShell 2 rather than upgraded
* Removed service disablement during upgrade process
* Fixed registry null values on Windows 7 / 2008 R2 / PowerShell 2
* Fixed false positive error when script being run offline
* Fixed bug where `switch` type parameter was being tested for boolean values rather than the .IsPresent field
* Fixed bug where logging was being called incorrectly, leading to null values when writing to the event log
* Fixed a bug that it didn't detect all Group Policy installs as such (only detected if run from netlogon folder, not from within the sysvol folder)
* Fixed a but that it incorrected was detected as Group Policy install (now it takes not only the start location but also the user that runs it into account)

## New Features
* Added option to prevent change of service behavior
* Added Agent AD Status AMP to monitor the installer on a Domain Controller.

## Housekeeping
* Updated reference for SolarWinds MSP to N-able
* Added an extra registry cleanup for registry items created by version 5.x.x and version 6.0.0 (with the old SolarWinds MSP name)


# 2021-02-20 - 6.0.0
*   Registration token install method:
    *   Activation Key methods for upgrades
    *   Registration Key methods for new installs/repairs
*   Sources for the registration token can include:
    *   Script input parameters
    *   A configuration file located in the root of the script folder
    *   Kelvin Tegelaar's AzNableProxy via an Azure Cloud function also on GitHub under [KelvinTegelaar/AzNableProxy](https://github.com/KelvinTegelaar/AzNableProxy)
    *   Last successful install configuration saved to a local file
*   Functioning N-Central AMP scripts that support 2 methods for updating the configuration file used for installation
    *   Direct update of Customer ID/Registration Token and other values from N-Central Custom Property (CP) injected via N-Central API See: [How to N-Central API Automation](https://github.com/AngryProgrammerInside/NC-API-Documentation) for examples
    *   Automatic update of Customer ID/Registration token from values pulled from local Agent/Maintenance XML along with provided JWT (see above documentation)
*   Functioning N-Central AMP script to update/renew expired/expiring tokens
*   Legacy Support: If you still have old values within your GPO, you can use a flag within the LaunchInstaller.bat to ignore provided parameters and rely upon the configuration file
*   Custom installation method data
    *   Through additional modules you can use your own source for CustomerID/Registration Token enumeration
    *   A sample module is provided
*   Added a new LaunchInstaller.ps1 while still providing LaunchInstaller.bat, either can be used but those wanting to move away from batch files can.
*   Optional upload of installation telemetry to Azure Cloud, giving insight into success/failure to help track checkins against N-Central
    *   Example modules provided
*   Quality of Life for development and debugging:
    *   Added debugmode to the InstallAgent.ps1 to avoid self destruct and reload of modules
    *   Added debug function to provide Gridviews of common tables
    *   For more details on development debugging of this script, check out this page on GitHub

# 2019-08-26

## Fixes and Bug Control
* Fixed an issue with the Agent Version comparator, partly due to the bizarre Windows Version numbering method for the Agent Installer - e.g. Version 12.1.2008.0 (12.1 HF1) is "greater than" Version 12.1.10241.0 (12.1 SP1 HF1)
* Fixed an issue during Diagnosis phase where incorrect Service Startup Behavior was ALWAYS detected, even after Repairs complete successfully
* The following issues were identified, explored and reported by **Harvey** via N-Able MSP Slack (thank you!):
    * Removed references to the PowerShell 3.0 function **Get-CIMInstance** (from a previous optimization) to maintain PowerShell 2.0 Compatibility
    * Fixed a premature stop error in the Launcher when a Device has .NET 2.0 SP1 installed, but needs to install PowerShell 2.0

## New Features

* Added Script Instance Awareness:
    * The Agent Setup Script will first check to see if another Instance is already in progress, and if so, terminate the Script with an Event Log entry indicating so, in order to preserve Registry results of the pre-existing Instance
    * If the pre-existing Instance has been active for more than 30 minutes, the Script will proceed anyway, thus overwriting results

## Housekeeping and Nuance

* Added Detection Support for .NET Framework 4.8
* Updated some Messages written to the Event Log for clarity

## Tweaks and Optimizations

* None this time!