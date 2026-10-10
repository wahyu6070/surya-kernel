# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Custom Android kernel "Zix Gaming Kernel by wahyu6070" for the Xiaomi POCO X3 NFC (codename: **surya**), based on Linux 4.14.357 for the Qualcomm sdmmagpie (SM7150) SoC. Key additions over stock: KernelSU with SUSFS patches, WireGuard, and performance-oriented scheduler/memory tuning. Kernel release string: `4.14.357-ZIX-Gaming-by-wahyu6070` (`CONFIG_LOCALVERSION`).

## Branches

Only three branches exist. Each one is a separate kernel variant and is developed on its own:

- `gaming` — gaming variant (default branch)
- `main` — main variant
- `daily` — daily variant with a conservative config for battery life

The root manager app matching this kernel is **KernelSU Next v3.4.1 (33333)**. The manager checks the kernel's UAPI version, not the version number: the in-tree `v3.4.0-legacy-susfs` reports `KERNEL_SU_UAPI_VERSION` **5** (shown as `33306-5`), which matches v3.4.1. The v3.4.0 manager (UAPI 4) shows "manager version is too low". All official KernelSU Next APKs share the signing certificate in `drivers/kernelsu/Kbuild` (`KSU_NEXT_MANAGER_SIZE`/`HASH`). SUSFS is managed from userspace with the [sidex15/susfs4ksu-module](https://github.com/sidex15/susfs4ksu-module) KernelSU module.

Never sync one variant onto another (merge, fast-forward or push) unless the user asks for that specific sync. Don't create extra feature or test branches unless the user asks.

On 2026-09-23 a KernelSU Next/SUSFS update and Docker-in-chroot config options caused a bootloop. `main` and `gaming` were reset to `d77a27a79`, and the Docker work was dropped. Don't re-add the Docker changes unless the user asks. On 2026-10-07 the user asked for the KernelSU Next/SUSFS update again, and it was redone on `gaming` (see KernelSU + SUSFS below).

## Git Workflow

Commit and push directly to the working branch. Do not open pull requests; the user does not want to merge anything manually.

## Build Commands

### Full kernel build
```bash
./build.sh
```
Uses Google's official Android kernel toolchain `clang-r522817` (clang 18.0.1, the version the AOSP prebuilts README lists for the Android Linux Kernel). If `tc/clang-r522817` is missing, it is downloaded from `android.googlesource.com/platform/prebuilts/clang/host/linux-x86` (about 3 GB unpacked). Don't switch to third-party clang mirrors, GCC or the NDK unless the user asks. Produces a flashable AnyKernel3 zip `zix-gaming-kernel-by-wahyu6070-surya-<YYYYMMDD-HHMM>-<hash8>.zip` (all lowercase) in the repo root; `build.sh` also sets the installer banner (`kernel.string`) to `Zix Gaming Kernel by wahyu6070 | POCO X3/NFC`.

AnyKernel3: `android/AnyKernel3` is a gitlink (to `surya-aosp/AnyKernel3` branch `shinigami`, commit `1eb28870`) with **no `.gitmodules`**, so in a fresh clone it is an empty directory. `build.sh` uses the local template only if `android/AnyKernel3/anykernel.sh` exists; otherwise it clones `https://github.com/surya-aosp/AnyKernel3` (branch `shinigami`). The template's own banner says "Shinigami Kernel"; `build.sh` rewrites it in the staged copy only.

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
export PATH="$PWD/tc/clang-r522817/bin:$PATH"
make O=out ARCH=arm64 surya_defconfig
make -j$(nproc) O=out ARCH=arm64 CC=clang LD=ld.lld AS=llvm-as AR=llvm-ar NM=llvm-nm \
  OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip LLVM=1 LLVM_IAS=1 \
  CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_COMPAT=arm-linux-gnueabi- \
  Image.gz dtb.img dtbo.img
```

### Host requirements
`build-essential`, `bison`, `flex`, `libssl-dev`, `libelf-dev`, `binutils-aarch64-linux-gnu`, `binutils-arm-linux-gnueabi`, `zip`, `bc`. A clean build takes about 7–8 minutes on the dev machine; a ThinLTO link adds a few minutes.

### Build artifacts
- `out/arch/arm64/boot/Image.gz` — compressed kernel image
- `out/arch/arm64/boot/dtb.img` — device tree blob
- `out/arch/arm64/boot/dtbo.img` — device tree overlay
- `log.txt` — stderr from the most recent build

`build.sh` deletes `out/arch/arm64/boot` after zipping, so copy the images first if you need them afterwards. To confirm the config inside a built image, run `scripts/extract-ikconfig out/arch/arm64/boot/Image.gz` (`CONFIG_IKCONFIG` is enabled).

## GitHub Releases

Publish every successful build as a GitHub Release on `wahyu6070/surya-kernel` with `gh`. The user downloads the ZIP from there. Do this after each build without asking again:

1. Build only from a committed, clean tree, and push the branch first so the tag points at a commit that exists on GitHub.
2. Tag = ZIP name without `.zip`; title = `Zix Gaming Kernel by wahyu6070 — <YYYY-MM-DD> (<branch>)`.
3. Upload the ZIP plus a `SHA256SUMS` file.
4. Publish with `--prerelease`, because the build has not been boot-tested yet. Once the user confirms it boots, promote it with `gh release edit <tag> --prerelease=false --latest`.
5. Write the release notes in **English**: branch, full commit hash, changes since the previous release, SHA-256, and **"Not boot-tested yet"** until the user confirms that the build boots. (Chat replies to the user stay in Indonesian; only the GitHub release text is English.)
6. Give the user the direct download link. A prerelease does not show on the repo front page.
7. Always include a `### KernelSU Next` section (in English): the in-kernel version (`v3.4.0-legacy` + SUSFS v2.3.0, shown as `33306` in the manager), the matching manager **v3.4.1 (33333)** with direct APK links (regular `KernelSU_Next_v3.4.1_33333-release.apk` and spoofed `KernelSU_Next_v3.4.1-spoofed_33333-release.apk` from `github.com/KernelSU-Next/KernelSU-Next/releases/download/v3.4.1/`), a note that older managers (v3.4.0 = UAPI 4, v3.2.0) show "manager version is too low" with this kernel (UAPI 5), and a link to the [sidex15/susfs4ksu-module](https://github.com/sidex15/susfs4ksu-module) for SUSFS. Update this if the in-tree KernelSU version changes. Pick the manager release whose `uapi/supercall.h` has the same `KERNEL_SU_UAPI_VERSION` as `drivers/kernelsu/include/uapi/supercall.h`.
8. After publishing a new build, delete every older **prerelease** (builds that were never confirmed to boot) together with its tag (`gh release delete <tag> --yes --cleanup-tag`), plus any tag left without a release. **Never delete a stable release** (one the user confirmed boots and that was promoted with `--prerelease=false`), so a known-good build always stays available.

```bash
zip=$(ls -t zix-gaming-kernel-by-wahyu6070-surya-*.zip | head -1)
tag=${zip%.zip}
sha256sum "$zip" > SHA256SUMS
gh release create "$tag" "$zip" SHA256SUMS --repo wahyu6070/surya-kernel \
  --target "$(git rev-parse HEAD)" \
  --title "Zix Gaming Kernel by wahyu6070 — $(date +%F) ($(git branch --show-current))" \
  --notes-file notes.md --prerelease
```

## Defconfig

`arch/arm64/configs/surya_defconfig` is the only defconfig for this device. After changing any `Kconfig` option, regenerate it with `./build.sh -r` so it stays minimal. After an edit, confirm that each new symbol resolves to `=y` in `out/.config`. Kconfig silently drops a symbol whose dependencies are not met.

Known constraint: `CONFIG_ANDROID_SIMPLE_LMK` depends on `!MEMCG` and `PSI_DEFAULT_DISABLED`. Enabling `MEMCG` silently disables Simple LMK.

## Architecture & Key Directories

### SoC platform (sdmmagpie)
- `arch/arm64/boot/dts/qcom/sdmmagpie*` — device tree sources for the SM7150/sdmmagpie platform

### Qualcomm techpack
- `techpack/audio/` — ALSA ASoC machine/codec/DSP drivers
- `techpack/data/` — RMNET and data-path drivers

### KernelSU + SUSFS
- `drivers/kernelsu/` — KernelSU source, wired into `drivers/Kconfig` and `drivers/Makefile`
- `CONFIG_KSU=y` (built-in), hook mode `CONFIG_KSU_MANUAL_HOOK=y` (non-GKI, no kprobes)
- Version: KernelSU-Next `legacy` branch at `8869bd76` (`v3.4.0-legacy-12`, 3017 commits). `drivers/kernelsu` is a plain copy, not a git repo, so `Kbuild` pins `KSU_GIT_VERSION := 3017` (reported as 30000 + 3017 + 289 = `33306`) and `KSU_GIT_TAG := v3.4.0-legacy-susfs`. Update both when syncing upstream. `include/uapi` is a symlink to `../../uapi` upstream; here it holds real copies of the headers.
- SUSFS **v2.3.0** (`fs/susfs.c`, `include/linux/susfs*.h`). Upstream SUSFS only supports GKI (5.10+), and its `kernel-4.14` branch stopped at v1.5.5, so the `fs/`, `mm/`, `kernel/` and `security/` hooks follow sidex15's 4.14 port (`sidex15/android_kernel_lge_sm8150`, branch `OpenELA-4.14.y-Stock`). The KernelSU-side glue (`supercall.c`, `setuid_hook.c`, `kernel_umount.c`, `selinux.c`, `rules.c`, `dispatch.c`, `init.c`) follows `sidex15/KernelSU-Next` branch `legacy-susfs-v2`. Upstream KernelSU Next dropped SUSFS ("purge SuSFS remnants"), so every upstream sync has to keep this glue.
- SUSFS userspace talks to the kernel through `reboot(KSU_INSTALL_MAGIC1, SUSFS_MAGIC /* 0xFAFAFAFA */, cmd, arg)`. `try_umount` runs the SUSFS list first and then KernelSU's own umount list, in the same `ksu_cred` task_work (`feature/kernel_umount.c`).
- Upstream removed `ksu_handle_devpts` (pts now goes through a proxy file), so `fs/devpts/inode.c` has no KernelSU hook.
- SUSFS (`CONFIG_KSU_SUSFS*`): sus_path, sus_mount, sus_kstat, try_umount, spoof_uname, spoof_cmdline, open_redirect, sus_map, hide symbols (all default y), and sus_memfd (default n). Each one can be toggled separately in Kconfig.

### WireGuard
Built-in via `CONFIG_WIREGUARD=y` (backported into this 4.14 tree).

### GPU / Display
- `drivers/gpu/drm/msm/` — DRM/KMS driver (DSI display)
- `drivers/gpu/msm/` — Adreno KGSL driver

### Scheduler / Performance (gaming tuning)
- WALT + EAS: `CONFIG_SCHED_WALT=y`, `CONFIG_SCHED_TUNE=y`, `CONFIG_DEFAULT_USE_ENERGY_AWARE=y`
- CPUFreq: default governor **schedutil** (`CONFIG_CPU_FREQ_DEFAULT_GOV_SCHEDUTIL=y`). Performance is still built in but is not the default, because pinning max clocks triggers thermal throttling.
- `CONFIG_CPU_BOOST=y`: `drivers/cpufreq/cpu-boost.c` enables input boost by default (`0:1324800 6:1209600`, 100 ms) with `sched_boost_on_input=2` (CONSERVATIVE_BOOST). The ROM can override these module params.
- `CONFIG_DEVFREQ_BOOST=y`
- Codegen: `arch/arm64/Makefile` adds `-mcpu=cortex-a55 -mtune=cortex-a76` (SD732G: 6x A55 + 2x A76; clang rejects the GCC-style `cortex-a76.cortex-a55`)
- Clang ThinLTO: `CONFIG_LTO_CLANG=y`, `CONFIG_THINLTO=y`. `scripts/Makefile.build` passes the LTO symversions prerequisite list through a file; the original inline loop overflowed the shell argument limit on qcacld's `wlan.o`.
- Preemption: `CONFIG_PREEMPT=y`, **HZ=1000**
- PELT half-life 16ms (`CONFIG_PELT_UTIL_HALFLIFE_16=y`)
- I/O scheduler: deadline (default); TCP congestion control: BBR (default)

### Memory
- Low memory killer: Simple LMK (`CONFIG_ANDROID_SIMPLE_LMK=y`); `MEMCG` is off
- ZRAM with writeback (`CONFIG_ZRAM=y`, `CONFIG_ZRAM_WRITEBACK=y`); the default compressor is `lz4` (set in `drivers/block/zram/zram_drv.c`)
- Slab hardening: `CONFIG_SLAB_FREELIST_RANDOM=y`, `CONFIG_SLAB_FREELIST_HARDENED=y`

## Coding Conventions

This is a Linux 4.14 kernel tree. Follow the kernel coding style (`Documentation/process/coding-style.rst`): tabs for indentation, 80-column soft limit, C89-style declarations. Run `checkpatch.pl` before committing C changes:

```bash
scripts/checkpatch.pl --no-tree -f <file>         # check a file
scripts/checkpatch.pl <patch-file>                 # check a patch
```

## Android Integration

- `AndroidKernel.mk` — integration point for the AOSP build system (`make bootimage`)
- `build.config.surya` / `build.config.common` — GKI-style build configs for the AOSP `build/build.sh` flow (separate from the standalone `./build.sh`)
- `disable_dbgfs.sh` — strips debugfs for user builds in the AOSP build flow
