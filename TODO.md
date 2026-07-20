# TODO.md - XRForge VR Hardware Compatibility Project

## Project Goal

Build an open-source VR hardware compatibility layer for Linux using
open standards such as OpenXR and Monado, with future cross-platform
goals.

Project root:

``` text
/media/user/Third_4TB/PSF/XRDForge
```

Repository:

``` text
/media/user/Third_4TB/PSF/XRDForge/monado-source
```

# Completed

## VR Platform Bring-Up

-   [x] Connected VR headset on Linux
-   [x] Verified USB communication
-   [x] Verified headset sensors
-   [x] Verified display output
-   [x] Verified SteamVR startup
-   [x] Verified Monado integration
-   [x] Verified head tracking

## Controller Support

-   [x] Identified Bluetooth instability
-   [x] Replaced unreliable adapter
-   [x] Paired controllers
-   [x] Trusted controllers
-   [x] Connected both controllers simultaneously
-   [x] Verified HID operation
-   [x] Verified buttons
-   [x] Verified triggers
-   [x] Verified tracking

# Remaining

## Controller Aim Correction

-   [ ] Determine correct WMR controller coordinate transform
-   [ ] Correct AIM_POSE orientation
-   [ ] Verify left controller
-   [ ] Verify right controller
-   [ ] Confirm grip pose remains unchanged

## Future Expansion

-   [ ] Document supported hardware
-   [ ] Separate hardware-specific logic from common VR support
-   [ ] Improve portability across platforms
-   [ ] Expand beyond initial WMR hardware targets

# Current State

The foundation is working:

-   headset support
-   Monado integration
-   SteamVR compatibility
-   controller connectivity

The remaining immediate task is controller pose correction.
