# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Custom Android kernel ("Zix Gaming Kernel by wahyu6070") for the Xiaomi POCO X3 NFC (codename: **surya**), based on Linux 4.14.357 for the Qualcomm SDM (sdmmagpie / SM7150) SoC. Key additions over stock: KernelSU with SUSFS patches, WireGuard, and various scheduler/memory tuning.

## Branches

Each branch is a separate kernel variant; they are developed independently and are **not** kept in sync automatically:

- `main` — main (standard) kernel version, kept at the pre-2026-09-23 state (`d77a27a79`) without the Zix Gaming packaging/docs changes
- `gaming` — gaming kernel version ("Zix Gaming Kernel by wahyu6070")
- `docker` — `gaming` plus kernel options for running Docker inside a chroot on the phone (namespaces, cgroups, netfilter/bridge). `MEMCG` stays off because it disables Simple LMK.
- `test/*` — boot-diagnosis branches

Commit a change only to the branch whose variant it belongs to. Do not fast-forward, merge or push one variant branch onto another unless the user asks for that specific sync.

## Build Commands

### Full kernel build
```bash
./build.sh
```
Requires AOSP clang toolchain (auto-cloned to `tc/clang-498229` if missing) and AnyKernel3 (auto-cloned from `surya-aosp/AnyKernel3` branch `shinigami` when `android/AnyKernel3` is empty). Produces a flashable zip `Zix-Gaming-Kernel-by-wahyu6070-surya-<date>-<hash>.zip`.

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

## GitHub Releases

Every successful build is published as a GitHub Release on `wahyu6070/surya-kernel` with `gh`; the user downloads the flashable ZIP from there. Do this after each build without asking again:

1. Build only from a committed, clean tree, and push that branch first (`git push origin <branch>`) so the release tag points at a commit that exists on GitHub.
2. Tag = ZIP name without `.zip`; title = `Zix Gaming Kernel by wahyu6070 — <YYYY-MM-DD> (<branch>)`.
3. Upload the ZIP plus a `SHA256SUMS` file.
4. Publish every build with `--prerelease` (it has not been boot-tested yet) and put the branch in the title. Once the user confirms it boots, promote it with `gh release edit <tag> --prerelease=false --latest`.
5. Write the notes in Indonesian: branch, full commit hash, what changed since the previous release, SHA-256, and **"Belum diuji boot"** until the user confirms the build boots on the phone.

```bash
zip=$(ls -t Zix-Gaming-Kernel-by-wahyu6070-surya-*.zip | head -1)
tag=${zip%.zip}
sha256sum "$zip" > SHA256SUMS
gh release create "$tag" "$zip" SHA256SUMS --repo wahyu6070/surya-kernel \
  --target "$(git rev-parse HEAD)" \
  --title "Zix Gaming Kernel by wahyu6070 — $(date +%F) ($(git branch --show-current))" \
  --notes-file notes.md --prerelease
```

## Defconfig

`arch/arm64/configs/surya_defconfig` — the single defconfig for this device. After changing any `Kconfig` option, always regenerate with `./build.sh -r` so the defconfig stays minimal.

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
- SUSFS features (sus_path, sus_mount, sus_kstat, spoof_uname, open_redirect, sus_map, etc.) are individually toggleable in Kconfig

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
