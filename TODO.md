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

## Controller Optical Tracking

Current blocker: the controller cameras deliver frames, but the blob detector
finds no LED constellation.

Findings from driver logs (`xrforge-monado.log`):

-   both controllers initialize cleanly; firmware config reads succeed
-   status and IMU report enable commands are both sent, with no errors
-   camera frames arrive from both controller cameras
-   frames are saturated: `max=255` with up to ~44,500 pixels above threshold
    out of 1280x480, in a dark room

`WMR_AUTOEXPOSURE` defaults to true. Auto exposure targets SLAM imaging, which
brightens the whole frame, while LED constellation tracking needs short exposure
and low gain so only the IR LEDs register.

-   [ ] Test `WMR_AUTOEXPOSURE=false`
-   [ ] If still saturated, set exposure/gain manually (exposure range ~60-6000,
    gain range ~16-255; see `wmr_camera.c`)
-   [ ] Confirm bright pixel counts drop to small blob-sized clusters
-   [ ] Verify constellation samples appear in the driver log

## Controller Input

-   [ ] Buttons stopped working after switching to Index controller emulation
    (`STEAMVR_EMULATE_INDEX_CONTROLLER=true`). Check whether the emulated device
    profile expects input bindings the WMR driver does not publish.

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

## Cleanup at 0.3.0

-   [ ] Remove `runonce.sh` compatibility wrapper

`runonce.sh` only prints a rename notice and forwards to `start.sh`. Nothing in
the project depends on it; it exists so older published instructions still work.
Removing it is a breaking change for anyone following those instructions, so it
waits for the next major version. Removal also means dropping the wrapper
paragraph from `README.md`; the historical `CHANGELOG.md` entry stays.

# Current State

The foundation is working:

-   headset support
-   Monado integration
-   SteamVR compatibility
-   controller connectivity

The remaining immediate task is controller pose correction.
