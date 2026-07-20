# XRForge / VR Hardware Compatibility Handoff

## Purpose

Technical handoff for continuing open-source VR hardware support work.

The goal is to create an open compatibility layer that brings VR
headsets and controllers to Linux through open standards such as OpenXR
and Monado, with future cross-platform potential.

Project root:

``` text
/media/user/Third_4TB/PSF/XRDForge
```

Monado source tree:

``` text
/media/user/Third_4TB/PSF/XRDForge/monado-source
```

## Current Focus

Initial development target:

-   Windows Mixed Reality compatible VR hardware
-   HP Reverb headset
-   WMR motion controllers

The headset is the first validated device, not the limit of the project.

## Working Components

-   [x] VR headset display
-   [x] USB device communication
-   [x] Head tracking
-   [x] SteamVR startup
-   [x] Monado SteamVR integration
-   [x] WMR controller Bluetooth pairing
-   [x] Dual controller connection
-   [x] Controller buttons
-   [x] Controller triggers
-   [x] Controller tracking

## Bluetooth Discovery

The original inexpensive Bluetooth adapter caused unreliable
multi-controller connections.

Resolution:

-   replaced adapter with ASUS Bluetooth adapter
-   paired both controllers
-   verified simultaneous operation

## Remaining Issue

Controller AIM_POSE orientation requires correction.

Current behavior:

-   controller tracking works
-   trigger works
-   laser pointer exists
-   aim direction is incorrect

The controller must be pointed unnaturally upward to aim correctly.

This indicates a coordinate transform / quaternion correction issue.

## Relevant Code

Primary investigation area:

``` text
/media/user/Third_4TB/PSF/XRDForge/monado-source/src/xrt/drivers/wmr/wmr_controller_base.c
```

Function:

``` c
wmr_controller_base_get_tracked_pose()
```

Goal:

Correct AIM_POSE orientation without affecting:

-   grip pose
-   tracking fusion
-   button mappings
-   trigger input

## Current Status

The project is close to functional WMR support through Monado/OpenXR.

Remaining work is controller pose correction and expanding hardware
compatibility.
