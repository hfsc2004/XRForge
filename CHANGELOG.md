# Changelog

## 0.2.1

- Added WMR controller optical frame gating to skip dark/no-signal frames and flooded frames before blob tracking.
- Added `WMR_CONTROLLER_MIN_BRIGHT_PIXELS` and `WMR_CONTROLLER_MAX_BRIGHT_PIXELS` launcher controls.
- Disabled hard bright-pixel count gating by default after testing showed it could make startup re-acquisition worse.
- Added optical re-acquisition after repeated valid-looking position-jump rejects.
- Defaulted the WMR controller zero/reinit startup command off to avoid dropping controller LED rings during SteamVR startup.
- Defaulted remaining WMR controller startup report-enable commands off while isolating LED ring shutdowns.
- Added explicit WMR controller firmware command/response logging for LED power-state debugging.
- Added XRForge-managed centered SteamVR chaperone generation before launch for room-scale app startup.
- Preserved the existing SteamVR standing transform when generating a larger XRForge play area.
- Defaulted SteamVR controller presentation to Index emulation to avoid generic locator-axis render models.
- Added per-hand WMR aim yaw overrides for asymmetric controller pointer correction.
- Split the XRForge launcher into focused `scripts/` modules and removed the stale Monado patch artifact.
- Replaced the unreachable patched Monado submodule pointer with an upstream-fetchable submodule plus a split XRForge patch queue.
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
