# Changelog

## 0.2.1

- Added WMR controller optical frame gating to skip dark/no-signal frames and flooded frames before blob tracking.
- Added `WMR_CONTROLLER_MIN_BRIGHT_PIXELS` and `WMR_CONTROLLER_MAX_BRIGHT_PIXELS` launcher controls.
- Fixed WMR controller calibration cache lookup to use Monado's existing `controller_<serial>.json` filenames.
- Defaulted `WMR_CONTROLLER_TASK_RESTART` off inside the Monado WMR driver path to match XRForge startup behavior.
- Updated HP Reverb controller tracking documentation.

## 0.2.0

- Added the XRForge WMR/SteamVR startup workflow.
- Added automatic X11 headset direct-mode preparation using RandR `non-desktop=1` and output disable.
- Added Bluetooth controller connection checks and reconnect attempts.
- Added experimental WMR controller optical tracking patch packaging for the local Monado SteamVR build.
- Added fallback HMD-relative controller poses and tuning variables for fallback position and aim yaw.
- Added WMR controller LED blob debug logging and optional raw camera frame dumps.

## Earlier

- Added the initial XRForge project setup.
- Added HP Reverb Linux setup notes and generic `runonce.sh` compatibility workflow.
