# 2019-08-26 by Ryan Crowther Jr

## Fixes and Bug Control
* Fixed an issue with the Agent Version comparator, partly due to the bizarre Windows Version numbering method for the Agent Installer (e.g. Version 12.1.2008.0 (12.1 HF1) is "greater than" Version 12.1.10241.0 (12.1 SP1 HF1))
* Fixed an issue during Diagnosis phase where incorrect Service Startup Behavior was ALWAYS detected, even after Repairs complete successfully
The following issues were identified and reported by @Harvey via SolarWinds MSP Slack (thank you!):
* Removed references to the PS 3.0 function Get-CIMInstance (from a previous optimization) to maintain PS 2.0 Compatibility
* Fixed a premature stop error in the Launcher when a Device has .NET 2.0 SP1 installed, but needs to install PowerShell 2.0

## Tweaks and Optimizations

* None this time!

## New Features

* Added Detection Support for .NET Framework 4.8
* Added Script Instance Awareness
    * The Script will first check to see if another Instance is already in progress, and if so, terminate the Script with an Event Log entry indicating this, in order to preserve Registry results of the pre-existing Instance
    * If the pre-existing Instance has been active for more than 30 minutes, the Script will proceed anyway, thus overwriting results

## Housekeeping and Nuance

* Updated some Messages written to the Event Log for clarity