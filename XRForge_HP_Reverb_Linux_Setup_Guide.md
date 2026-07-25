# XRForge - HP Reverb Linux Setup Guide

XRForge version: `0.2.1`

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
-   X11 desktop session with the headset display marked `non-desktop`
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

On X11, the headset display must be marked `non-desktop` before SteamVR
starts. Without this, X11 can expose the headset as a normal desktop
output, SteamVR can power the panels, and the headset may remain lit with
no rendered picture.

The validated manual fix was:

``` bash
xrandr --output DP-0 --set non-desktop 1
```

`start.sh` now detects the connected headset-like RandR output and sets
that property automatically instead of assuming a static `DP-0` output.

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

## Controller Optical 6DoF Position Tracking

Current state:

Working:

-   Bluetooth controller connections
-   buttons
-   triggers
-   IMU orientation
-   fallback controller pose

Problem:

True WMR camera/LED controller position tracking is not yet producing usable
constellation samples. When this fails, XRForge uses a simulated fallback
controller pose that follows the HMD position but does not rotate around the
HMD when the wearer turns their head.

Observed behavior:

-   laser appears
-   trigger activates
-   fallback controllers can appear statically anchored relative to the playspace
-   fallback laser direction may require aim-yaw tuning
-   optical LED blob detection may report zero blobs

This indicates:

-   controller camera frames may not be detecting LED blobs
-   controller LEDs may not be active in the expected tracking mode
-   WMR camera coordinate transforms may still need correction
-   constellation tracker matching may need WMR-specific LED visibility/timing

------------------------------------------------------------------------

# Code Investigation Location

Primary files:

    monado-source/src/xrt/drivers/wmr/wmr_controller_base.c
    monado-source/src/xrt/drivers/wmr/wmr_hmd.c
    monado-source/src/xrt/drivers/wmr/wmr_source.c
    monado-source/src/xrt/drivers/wmr/wmr_camera.c

Important functions:

``` c
wmr_controller_base_get_tracked_pose()
wmr_hmd_setup_controller_tracking()
wmr_hmd_register_controller_for_tracking()
```

Current investigation:

-   WMR controller camera frames are split from SLAM frames
-   controller frames are routed to a blob detector
-   WMR controller LED calibration is registered with Monado's constellation tracker
-   fallback pose remains available when no optical sample exists
-   grip pose, IMU fusion, button mappings, and trigger input should not be broken

Fallback defaults:

``` bash
WMR_CONTROLLER_FALLBACK_X=0.14
WMR_CONTROLLER_FALLBACK_Y=-0.28
WMR_CONTROLLER_FALLBACK_Z=-0.10
WMR_CONTROLLER_AIM_YAW_DEGREES=65
STEAMVR_EMULATE_INDEX_CONTROLLER=true
```

Lower `WMR_CONTROLLER_AIM_YAW_DEGREES` values rotate the fallback laser
clockwise/right. Higher values rotate it counterclockwise/left. Use
`WMR_CONTROLLER_AIM_YAW_DEGREES_LEFT` or
`WMR_CONTROLLER_AIM_YAW_DEGREES_RIGHT` when only one controller needs aim
correction.

XRForge defaults `STEAMVR_EMULATE_INDEX_CONTROLLER=true` so SteamVR uses known
Index controller render models and legacy bindings instead of a generic
locator-style visualization.

Optical LED blob detection defaults:

``` bash
WMR_CONTROLLER_BLOB_PIXEL_THRESHOLD=220
WMR_CONTROLLER_BLOB_REQUIRED_THRESHOLD=240
WMR_CONTROLLER_BLOB_MAX_WIDTH=12
WMR_CONTROLLER_BLOB_ALLOW_SINGLE_PIXEL=false
WMR_CONTROLLER_USE_SLAM_FRAMES=true
WMR_CONTROLLER_MAX_BRIGHT_FRACTION=0.08
WMR_CONTROLLER_MIN_BRIGHT_PIXELS=0
WMR_CONTROLLER_MAX_BRIGHT_PIXELS=0
```

If one controller LED ring turns off when XRForge initializes the controllers,
test without controller init/write commands. XRForge now defaults these off for
HP Reverb controller testing:

``` bash
WMR_CONTROLLER_ZERO_COMMAND=false \
WMR_CONTROLLER_TASK_RESTART=false \
WMR_CONTROLLER_ENABLE_REPORT_COMMANDS=false ./start.sh
```

SteamVR chaperone/play-area defaults:

``` bash
XRFORGE_STEAMVR_CHAPERONE=true
XRFORGE_STEAMVR_PLAY_AREA=3.0
XRFORGE_STEAMVR_STANDING_X/Y/Z/YAW=preserve-existing
```

XRForge writes a centered SteamVR chaperone before launch and backs up the first
existing file to
`~/.local/share/Steam/config/chaperone_info.vrchap.xrforge-backup`. This avoids
room-scale apps getting stuck on an old or tiny play-area center while Monado's
WMR tracking origin is still experimental. XRForge preserves the standing
transform from the backup by default and only expands the play-area bounds. Set
`XRFORGE_STEAMVR_CHAPERONE=false` to leave SteamVR's room setup untouched.

Optical controller pose sample quality gates:

``` bash
WMR_CONTROLLER_MIN_MATCHED_BLOBS=4
WMR_CONTROLLER_MAX_REPROJECTION_ERROR=35
WMR_CONTROLLER_MAX_POSITION_JUMP=0.18
WMR_CONTROLLER_OPTICAL_POSITION_ALPHA=0.25
WMR_CONTROLLER_REACQUIRE_AFTER_REJECTS=8
```

Raw controller camera frame dumps:

``` bash
WMR_CONTROLLER_DUMP_FRAMES=12 ./start.sh
```

This writes up to twelve bright frames per controller camera to
`/tmp/xrforge-wmr-controller-cam*.pgm` after skipping startup frames. Use
`WMR_CONTROLLER_DUMP_SKIP_FRAMES` and `WMR_CONTROLLER_DUMP_INTERVAL` to change
when frames are captured. These dumps are useful when blob counts appear but
constellation samples are rare, because they show whether the tracker is seeing
controller LEDs, room noise, or incorrectly extracted frame data.

Current stabilization rule:

-   optical constellation samples provide controller position only
-   controller orientation remains IMU-driven
-   accepted optical positions are smoothed and pushed without linear velocity
    estimation
-   optical orientation is ignored until WMR camera/controller coordinate
    transforms are stable enough to avoid roll-axis drift

Capture controller-tracking diagnostics:

``` bash
./start.sh 2>&1 | tee xrforge-wmr-controller-tracking.log
```

SteamVR may detach the driver process after startup. For Monado driver output,
also inspect `~/.local/share/Steam/logs/vrstartup-linux.txt`.

Useful log lines:

``` text
controller cam0 frame #... max=... above_pixel=... above_required=...
controller cam0 blobs #...: N
WMR optical controller sample #...
Rejected WMR optical controller sample #...
```

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
-   [x] Controller IMU orientation fallback
-   [x] Controller optical tracking frame/blob diagnostics

Remaining:

-   [ ] Produce usable WMR optical controller constellation samples
-   [ ] Correct WMR optical camera/controller coordinate transforms
-   [ ] Finalize fallback AIM_POSE orientation transform
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
