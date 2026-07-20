<p align="center">
  <img src="assets/images/XRForge_Logo.png" alt="XRForge logo" width="220">
</p>

# XRForge

XRForge is an open-source VR hardware compatibility project focused on bringing
VR headsets and controllers to Linux through open standards such as OpenXR and
Monado, with future cross-platform potential.

The current development target is Windows Mixed Reality compatible hardware,
including the HP Reverb headset and WMR motion controllers. The headset is the
first validated device, not the limit of the project.

## Current Workflow

The manual HP Reverb Linux bring-up process is documented in
`XRForge_HP_Reverb_Linux_Setup_Guide.md`. The working flow uses a local Monado
build as a SteamVR driver:

```text
HP Reverb / WMR controllers
        |
Monado SteamVR driver
        |
SteamVR
        |
VR applications
```

For the current one-shot session helper, run:

```bash
./runonce.sh
```

Useful options:

```bash
./runonce.sh --register-steamvr
./runonce.sh --launch-steamvr
./runonce.sh --skip-build
./runonce.sh --no-bluetooth
```

`runonce.sh` builds/checks the local Monado SteamVR target, reports the local
OpenXR runtime manifest, verifies obvious HP Reverb USB visibility, checks WMR
controller Bluetooth state, and can optionally register the local SteamVR driver
or launch SteamVR.

For this SteamVR driver workflow, Monado is normally loaded through
`driver_monado.so` inside SteamVR, typically under `vrserver`. A separate
long-running `monado-service` process is not expected.

## Current Status

The project foundation is working:

- VR headset display
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
- `runonce.sh` - one-shot HP Reverb/WMR SteamVR session helper.
- `XRForge_HP_Reverb_Linux_Setup_Guide.md` - documented manual HP Reverb Linux
  setup process.
- `XRForge_Monado_Handoff.md` - technical handoff and current investigation notes.
- `TODO.md` - project checklist and near-term work items.
- `assets/images/` - XRForge project image assets.

## Upstream Runtime

XRForge builds on Monado, an open-source XR runtime and OpenXR implementation.
See `monado-source/README.md` and `monado-source/CONTRIBUTING.md` for upstream
build, contribution, and licensing guidance.

<p align="center">
  <img src="assets/images/XRForge.png" alt="XRForge" width="160">
</p>

<p align="center">
  Copyright 2026 Pseudo Science Fiction
</p>
