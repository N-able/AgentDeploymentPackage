# 2020-10-15

## New Features

* Created a RegistrationToken option for the PartnerConfig.xml

# 2020-06-17

## New Features

* Created a CustomerID option for the PartnerConfig.xml

# 2019-08-26

## Fixes and Bug Control
* Fixed an issue with the Agent Version comparator, partly due to the bizarre Windows Version numbering method for the Agent Installer - e.g. Version 12.1.2008.0 (12.1 HF1) is "greater than" Version 12.1.10241.0 (12.1 SP1 HF1)
* Fixed an issue during Diagnosis phase where incorrect Service Startup Behavior was ALWAYS detected, even after Repairs complete successfully
* The following issues were identified, explored and reported by **Harvey** via SolarWinds MSP Slack (thank you!):
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
