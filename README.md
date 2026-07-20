<p align="center">
  <img src="assets/images/XRForge_Logo.png" alt="XRForge logo" width="220">
</p>

# XRForge

XRForge is an open-source XR hardware compatibility project focused on bringing
VR, AR, and MR headsets and controllers to Linux through open standards such as
OpenXR and Monado, with future cross-platform potential.

The current development target is Windows Mixed Reality compatible XR hardware.
The HP Reverb and WMR motion controllers are the first validated devices, not
the limit of the project.

## Install / Run

To install and run the current WMR-compatible XR device SteamVR workflow, run:

```bash
./runonce.sh
```

That is the normal path. The script will:

- verify required command-line tools are available
- build the local Monado SteamVR target with `ninja`
- confirm the local OpenXR runtime manifest exists
- confirm the SteamVR Monado driver exists
- export `XR_RUNTIME_JSON` for OpenXR clients launched from that shell
- print the local SteamVR driver path
- check whether WMR-compatible XR USB devices are visible
- check the configured controller Bluetooth pairing/connection state
- show active Bluetooth controller links when `hcitool` is available
- register the local Monado SteamVR driver with SteamVR
- launch SteamVR
- report the expected Monado process model

The working stack is:

```text
WMR-compatible XR headset/controllers
        |
Monado SteamVR driver
        |
SteamVR
        |
VR applications
```

For this SteamVR driver workflow, Monado is normally loaded through
`driver_monado.so` inside SteamVR, typically under `vrserver`. A separate
long-running `monado-service` process is not expected.

The full manual setup process for the first validated device is documented in
`XRForge_HP_Reverb_Linux_Setup_Guide.md`.

## Current Status

The project foundation is working:

- XR headset display
- USB device communication
- Head tracking
- SteamVR startup
- Monado SteamVR integration
- WMR controller Bluetooth pairing
- Dual controller connection
- Controller buttons and triggers
- Controller tracking

## Immediate Focus

The remaining high-priority issue is WMR controller `AIM_POSE` orientation.
Controller tracking, trigger input, and laser pointer output are present, but
the aim direction currently requires the controller to be pointed unnaturally
upward.

Primary investigation area:

```text
monado-source/src/xrt/drivers/wmr/wmr_controller_base.c
```

Function:

```c
wmr_controller_base_get_tracked_pose()
```

The goal is to correct `AIM_POSE` orientation without affecting grip pose,
tracking fusion, button mappings, or trigger input.

## Repository Layout

- `monado-source/` - Monado source tree used for XR runtime development.
- `runonce.sh` - one-shot WMR-compatible XR SteamVR session helper.
- `XRForge_HP_Reverb_Linux_Setup_Guide.md` - documented manual setup process
  for the first validated WMR-compatible XR device.
- `XRForge_Monado_Handoff.md` - technical handoff and current investigation notes.
- `TODO.md` - project checklist and near-term work items.
- `assets/images/` - XRForge project image assets.

## Upstream Runtime

XRForge builds on Monado, an open-source XR runtime and OpenXR implementation.
See `monado-source/README.md` and `monado-source/CONTRIBUTING.md` for upstream
build, contribution, and licensing guidance.

## Optional Controls

These options are for debugging, automation, or LLM-assisted workflows. Most
users should just run `./runonce.sh`.

```bash
./runonce.sh --check-only
./runonce.sh --skip-build
./runonce.sh --no-register-steamvr
./runonce.sh --no-launch-steamvr
./runonce.sh --no-bluetooth
```

The explicit positive forms are also accepted for scripted use:

```bash
./runonce.sh --register-steamvr
./runonce.sh --launch-steamvr
```

<p align="center">
  <img src="assets/images/XRForge.png" alt="XRForge" width="160">
</p>

<p align="center">
  Copyright 2026 Pseudo Science Fiction
</p>
