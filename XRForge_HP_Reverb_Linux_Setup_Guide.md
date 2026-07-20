# XRForge - HP Reverb Linux Setup Guide

## Purpose

This document records the complete process used to bring an HP Reverb
Windows Mixed Reality headset and controllers into a working Linux VR
environment using SteamVR and Monado.

The goal is not only to document the final commands, but to preserve the
troubleshooting process, failures, discoveries, and hardware decisions
that led to a working configuration.

XRForge uses this as a reference for future VR hardware compatibility
work.

------------------------------------------------------------------------

# Hardware Tested

## Headset

-   HP Reverb Windows Mixed Reality headset

Detected devices:

-   Quanta Inc. QHMD A85V
-   Microsoft HoloLens Sensors
-   Generic USB Audio

## Controllers

HP WMR Motion Controllers.

Bluetooth addresses observed:

Left:

    D8:C4:97:C9:12:38

Right:

    D8:C4:97:C9:18:94

------------------------------------------------------------------------

# Final Working Environment

Host:

-   Ubuntu MATE 24.04
-   SteamVR Linux
-   Monado
-   OpenXR stack

Project:

    /media/user/Third_4TB/PSF/XRDForge

Monado source:

    /media/user/Third_4TB/PSF/XRDForge/monado-source

------------------------------------------------------------------------

# Phase 1 - Connect and Verify Headset

Connect:

-   DisplayPort cable
-   USB cable
-   headset power

Verify USB detection:

``` bash
lsusb
```

Verify kernel detection:

``` bash
dmesg | grep -iE 'usb|hid|hmd|hololens'
```

Expected devices:

    Quanta Inc. QHMD A85V
    Microsoft HoloLens Sensors

The headset should expose:

-   display output
-   sensor USB interface
-   audio interface

------------------------------------------------------------------------

# Phase 2 - Prepare Linux VR Environment

Required components:

-   Steam
-   SteamVR
-   Monado
-   Vulkan support
-   USB libraries
-   Bluetooth stack

The objective is:

    VR Applications
            |
    SteamVR / OpenXR
            |
    Monado
            |
    WMR hardware support
            |
    Headset + Controllers

------------------------------------------------------------------------

# Phase 3 - Build Monado

Source location:

``` bash
cd /media/user/Third_4TB/PSF/XRDForge/monado-source
```

Build process:

``` bash
ninja -C build-steamvr-minimal
```

The SteamVR driver is produced at:

    build-steamvr-minimal/steamvr-monado/bin/linux64/driver_monado.so

------------------------------------------------------------------------

# Phase 4 - SteamVR Integration

SteamVR logs were used for verification:

``` bash
grep -iE 'monado|wmr|reverb|hmd|unable|failed|error' \
~/.local/share/Steam/logs/vrserver.txt
```

Successful signs:

-   Monado driver loads
-   SteamVR detects HMD
-   SteamVR Home starts

------------------------------------------------------------------------

# Phase 5 - Initial Controller Bluetooth Investigation

Initial symptoms:

-   Controllers appeared in Bluetooth scan.
-   Pairing succeeded.
-   One controller would connect.
-   Connecting the second controller disconnected the first.

Example failure:

    org.bluez.Error.Failed br-connection-create-socket

Investigation showed:

-   Bluetooth stack was functioning.
-   Controllers were detected.
-   HID support loaded.
-   The issue followed controller connection attempts.

------------------------------------------------------------------------

# Phase 6 - Bluetooth Adapter Replacement

Root cause discovered:

The inexpensive Bluetooth adapter could not reliably maintain both WMR
controller connections.

Solution:

Replace with a higher quality ASUS Bluetooth adapter.

After replacement:

-   both controllers paired
-   both controllers trusted
-   both controllers connected simultaneously

This was the major breakthrough.

------------------------------------------------------------------------

# Phase 7 - Pair Controllers

Launch:

``` bash
bluetoothctl
```

Enable Bluetooth:

    power on
    agent on
    default-agent

Scan:

    scan on

Pair:

Left:

    pair D8:C4:97:C9:12:38

Right:

    pair D8:C4:97:C9:18:94

Trust:

    trust MAC_ADDRESS

Connect:

    connect MAC_ADDRESS

------------------------------------------------------------------------

# Phase 8 - Verify Controller Connections

Check controller information:

``` bash
bluetoothctl
```

Then:

    info MAC_ADDRESS

Expected:

    Paired: yes
    Bonded: yes
    Trusted: yes
    Connected: yes

Check active Bluetooth links:

``` bash
hcitool con
```

Expected:

    ACL <controller MAC>

------------------------------------------------------------------------

# Phase 9 - SteamVR Controller Validation

Working:

-   SteamVR Home loads
-   controllers appear
-   Windows/menu button works
-   trigger works
-   tracking works

The controllers are functional.

------------------------------------------------------------------------

# Troubleshooting Lessons

## Lesson 1 - Bluetooth Hardware Matters

A Bluetooth adapter can appear functional while failing under multiple
HID devices.

A cheap adapter caused hours of false debugging.

Always validate:

-   multiple HID connections
-   sustained ACL links
-   simultaneous controller operation

------------------------------------------------------------------------

## Lesson 2 - Headset Detection Is Not Controller Detection

The headset and controllers are separate systems.

Headset:

-   USB
-   sensors
-   display

Controllers:

-   Bluetooth
-   HID
-   IMU data

A working headset does not imply working controllers.

------------------------------------------------------------------------

# Remaining Issue

## Controller AIM_POSE Orientation

Current state:

Working:

-   tracking
-   buttons
-   triggers
-   IMU

Problem:

The controller laser direction does not match physical controller
orientation.

Observed behavior:

-   laser appears
-   trigger activates
-   controller must be pointed unnaturally upward
-   rotation compensation may also be required

This indicates:

-   coordinate transform issue
-   quaternion orientation issue
-   AIM_POSE correction required

------------------------------------------------------------------------

# Code Investigation Location

Primary files:

    monado-source/src/xrt/drivers/wmr/wmr_controller_base.c

Function:

``` c
wmr_controller_base_get_tracked_pose()
```

Current investigation:

-   grip pose should remain unchanged
-   AIM_POSE likely requires correction
-   IMU fusion should not be modified

------------------------------------------------------------------------

# Final Status

Completed:

-   [x] Linux VR environment
-   [x] HP Reverb headset
-   [x] Monado integration
-   [x] SteamVR integration
-   [x] WMR controller pairing
-   [x] Dual controller Bluetooth operation
-   [x] Controller input
-   [x] Controller tracking

Remaining:

-   [ ] Correct AIM_POSE orientation transform
-   [ ] Generalize support for additional VR hardware

------------------------------------------------------------------------

# Summary

The difficult part of bringing WMR hardware to Linux was not the
headset.

The major challenges were:

1.  Building the Monado environment.
2.  Integrating SteamVR.
3.  Debugging Bluetooth controller reliability.
4.  Identifying that the Bluetooth adapter was the limiting factor.
5.  Isolating the remaining issue to controller pose transformation.

The foundation is now working. XRForge begins from a functional VR
hardware stack and can continue toward broader open VR support.
