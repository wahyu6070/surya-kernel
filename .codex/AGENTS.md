# Codex project instructions

Guidance for Codex when working in this repository.

## Project Overview

Custom Android kernel ("Zix Gaming Kernel") for the Xiaomi POCO X3 NFC (codename: **surya**), based on Linux 4.14.357 for the Qualcomm SDM (sdmmagpie / SM7150) SoC. The release kernel string is `4.14.357-ZIX-Gaming-by-wahyu6070`. Key additions include KernelSU Next legacy with SUSFS, WireGuard, Docker-related kernel options, and scheduler/memory tuning.

## Build Commands

### Full kernel build
```bash
./build.sh
```
Requires a Clang toolchain (auto-cloned to `tc/clang-498229` if missing). `build.sh` builds `Image.gz`, `dtb.img`, and `dtbo.img`, then packages them into `zix-gaming-kernel-surya-<YYYYMMDD-HHMMSS>-<commit>.zip` in the repository root. `TC_DIR`, `AK3_DIR`, `OUT_DIR`, and `JOBS` can override the defaults; `HOSTCC`, `HOSTCFLAGS`, and `HOSTLDFLAGS` are passed through to the kernel build when set.

`android/AnyKernel3` is a gitlink without a `.gitmodules` mapping and may be empty after checkout. The script validates the local template and otherwise clones the `shinigami` branch of `surya-aosp/AnyKernel3`. It sets the installer label to Zix Gaming Kernel. Do not treat a directory's existence alone as proof that the template is usable.

To package existing images without recompiling, run `./build.sh --package-only`. Rebuild the images after source or config changes before packaging a release.

### Clean build
```bash
./build.sh -c    # or --clean — removes out/ before building
```

### Regenerate defconfig
```bash
./build.sh -r       # savedefconfig (minimal)
./build.sh -rf      # full .config copy
```

### Manual build (without build.sh wrapper)
```bash
make O=out ARCH=arm64 surya_defconfig
make -j$(nproc) O=out ARCH=arm64 CC=clang LD=ld.lld LLVM=1 LLVM_IAS=1 \
  CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_COMPAT=arm-linux-gnueabi- \
  Image.gz dtb.img dtbo.img
```

### Build artifacts
- `out/arch/arm64/boot/Image.gz` — compressed kernel image
- `out/arch/arm64/boot/dtb.img` — device tree blob
- `out/arch/arm64/boot/dtbo.img` — device tree overlay
- `log.txt` — stderr from the most recent build

## Defconfig

`arch/arm64/configs/surya_defconfig` is the device defconfig. After changing a `Kconfig` option, resolve it with `make O=out ARCH=arm64 surya_defconfig` and check the resulting `out/.config`. `./build.sh -r` rewrites the source defconfig, so use it when intentionally regenerating that file.

## Architecture & Key Directories

### SoC platform (sdmmagpie)
- `arch/arm64/boot/dts/qcom/sdmmagpie*` — device tree sources for the SM7150/sdmmagpie platform
- Clock drivers: `CONFIG_MSM_CAMCC_SDMMAGPIE`, `CONFIG_MSM_DISPCC_SDMMAGPIE`, `CONFIG_MSM_GCC_SDMMAGPIE`, etc.

### Qualcomm techpack (out-of-tree-style subsystems)
- `techpack/audio/` — ALSA ASoC machine/codec/DSP drivers for this platform
- `techpack/data/` — RMNET and data-path drivers

### KernelSU + SUSFS
- `drivers/kernelsu/` — KernelSU source, wired into `drivers/Kconfig` and `drivers/Makefile`
- Controlled by `CONFIG_KSU=y` (built-in) and the `CONFIG_KSU_SUSFS*` family
- Hook mode: `CONFIG_KSU_MANUAL_HOOK=y` (non-GKI kernel, no kprobes hook)
- Embedded source tracks KernelSU Next `legacy` commit `dd074bc6` with local SUSFS integration (`v1.5.9`); reported build code is `33280`. This is not the upstream v3.4.0 kernel driver, whose syscall hook implementation does not directly build on Linux 4.14.
- SUSFS features (sus_path, sus_mount, sus_kstat, spoof_uname, open_redirect, sus_map, etc.) are individually toggleable in Kconfig

### Docker
- The defconfig enables rootful Docker prerequisites including PID/IPC namespaces, pids/device cgroups, veth/bridge networking, and netfilter options.
- `CONFIG_MEMCG` is disabled to preserve `ANDROID_SIMPLE_LMK`; Docker memory limits are unavailable. Runtime operation on the device has not been verified.

### WireGuard
Built-in via `CONFIG_WIREGUARD=y` (backported into this 4.14 tree).

### GPU / Display
- `drivers/gpu/drm/msm/` — DRM/KMS driver (Adreno GPU, DSI display)
- `drivers/gpu/msm/` — Adreno userspace GPU driver (KGSL)

### Scheduler / Performance
- Energy-aware scheduling: `CONFIG_DEFAULT_USE_ENERGY_AWARE=y`, `CONFIG_SCHED_TUNE=y`
- CPUFreq governor: schedutil (`CONFIG_CPU_FREQ_GOV_SCHEDUTIL=y`)
- Preemption: `CONFIG_PREEMPT=y`, HZ=300
- PELT half-life tuned to 16ms (`CONFIG_PELT_UTIL_HALFLIFE_16=y`)

### Memory
- ZRAM with writeback enabled (`CONFIG_ZRAM=y`, `CONFIG_ZRAM_WRITEBACK=y`)
- Slab hardening: `CONFIG_SLAB_FREELIST_RANDOM=y`, `CONFIG_SLAB_FREELIST_HARDENED=y`

## Coding Conventions

This is a Linux 4.14 kernel tree — follow the kernel coding style (`Documentation/process/coding-style.rst`): tabs for indentation, 80-column soft limit, C89-style declarations. Use `checkpatch.pl` before submitting patches:

```bash
scripts/checkpatch.pl --no-tree -f <file>         # check a file
scripts/checkpatch.pl <patch-file>                 # check a patch
```

## Android Integration

- `AndroidKernel.mk` — integration point for AOSP build system (`make bootimage`)
- `build.config.surya` / `build.config.common` — GKI-style build configs (used by `build/build.sh` in the AOSP kernel build flow, separate from the standalone `./build.sh`)
- `disable_dbgfs.sh` — strips debugfs for user builds when invoked via the AOSP build flow

## GitHub Releases

- `gaming` is the default branch; `main` also exists. Check the remote branch state before pushing.
- A release ZIP should be built after the final source commit so its filename contains the matching commit hash. Verify the ZIP with `zip -T`, check that it contains `anykernel.sh`, `META-INF/com/google/android/update-binary`, `tools/ak3-core.sh`, and the three kernel images, then record its SHA-256.
- The 2026-09-23 GitHub release is a regular release. Build and ZIP integrity were verified, but boot and flashing on a device were not.
