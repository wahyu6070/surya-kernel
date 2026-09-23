#!/bin/bash
#
# Build the surya kernel and package it with AnyKernel3.
# Copyright (C) 2020-2021 Adithya R.

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

ZIPNAME="zix-gaming-kernel-surya-$(date '+%Y%m%d-%H%M%S')"
TC_DIR="${TC_DIR:-$PWD/tc/clang-498229}"
AK3_DIR="${AK3_DIR:-$PWD/android/AnyKernel3}"
OUT_DIR="${OUT_DIR:-$PWD/out}"
DEFCONFIG="surya_defconfig"
JOBS="${JOBS:-$(nproc)}"
MAKE_COMMON=(O="$OUT_DIR" ARCH=arm64)
for host_var in HOSTCC HOSTCFLAGS HOSTLDFLAGS; do
	if [[ -n "${!host_var:-}" ]]; then
		MAKE_COMMON+=("$host_var=${!host_var}")
	fi
done

if head=$(git rev-parse --short=8 HEAD 2>/dev/null); then
	ZIPNAME="${ZIPNAME}-${head}"
fi
ZIPNAME="${ZIPNAME}.zip"

case "${1:-}" in
	-r|--regen)
		make "${MAKE_COMMON[@]}" "$DEFCONFIG" savedefconfig
		cp "$OUT_DIR/defconfig" "arch/arm64/configs/$DEFCONFIG"
		echo "Successfully regenerated defconfig at $DEFCONFIG"
		exit 0
		;;
	-rf|--regen-full)
		make "${MAKE_COMMON[@]}" "$DEFCONFIG"
		cp "$OUT_DIR/.config" "arch/arm64/configs/$DEFCONFIG"
		echo "Successfully regenerated full defconfig at $DEFCONFIG"
		exit 0
		;;
	-c|--clean)
		if [[ "$OUT_DIR" != "$PWD/out" ]]; then
			echo "Clean only supports the default out directory" >&2
			exit 2
		fi
		rm -rf "$OUT_DIR"
		;;
	-p|--package-only)
		;;
	"")
		;;
	*)
		echo "Usage: $0 [-c|--clean|-r|--regen|-rf|--regen-full|-p|--package-only]" >&2
		exit 2
		;;
esac

if [[ "${1:-}" != -p && "${1:-}" != --package-only ]]; then
	if [[ ! -x "$TC_DIR/bin/clang" ]]; then
		if [[ -e "$TC_DIR" ]]; then
			echo "Clang toolchain is incomplete: $TC_DIR" >&2
			exit 1
		fi
		echo "AOSP clang not found! Cloning to $TC_DIR..."
		mkdir -p "$(dirname "$TC_DIR")"
		git clone --depth=1 -b 17 \
			https://gitlab.com/ThankYouMario/android_prebuilts_clang-standalone \
			"$TC_DIR"
	fi

	export PATH="$TC_DIR/bin:$PATH"
	mkdir -p "$OUT_DIR"
	make "${MAKE_COMMON[@]}" "$DEFCONFIG"

	echo "Starting compilation..."
	make -j"$JOBS" "${MAKE_COMMON[@]}" \
		CC=clang LD=ld.lld AS=llvm-as AR=llvm-ar NM=llvm-nm \
		OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip \
		CLANG_TRIPLE=aarch64-linux-gnu- \
		CROSS_COMPILE=aarch64-linux-gnu- \
		CROSS_COMPILE_COMPAT=arm-linux-gnueabi- \
		LLVM=1 LLVM_IAS=1 Image.gz dtb.img dtbo.img \
		2> >(tee log.txt >&2)
fi

kernel="$OUT_DIR/arch/arm64/boot/Image.gz"
dtb="$OUT_DIR/arch/arm64/boot/dtb.img"
dtbo="$OUT_DIR/arch/arm64/boot/dtbo.img"

for image in "$kernel" "$dtb" "$dtbo"; do
	if [[ ! -s "$image" ]]; then
		echo "Missing or empty build artifact: $image" >&2
		exit 1
	fi
done

echo "Kernel images ready. Packaging AnyKernel3..."
stage_dir=$(mktemp -d "${TMPDIR:-/tmp}/surya-anykernel.XXXXXXXX")
trap 'rm -rf "$stage_dir"' EXIT
template_dir="$stage_dir/AnyKernel3"

if [[ -s "$AK3_DIR/anykernel.sh" && \
	  -s "$AK3_DIR/tools/ak3-core.sh" && \
	  -s "$AK3_DIR/META-INF/com/google/android/update-binary" ]]; then
	mkdir "$template_dir"
	cp -a "$AK3_DIR"/. "$template_dir"/
else
	git clone --depth=1 -b shinigami \
		https://github.com/surya-aosp/AnyKernel3 "$template_dir"
fi

for required in anykernel.sh tools/ak3-core.sh \
	META-INF/com/google/android/update-binary; do
	if [[ ! -s "$template_dir/$required" ]]; then
		echo "Incomplete AnyKernel3 template: $required is missing" >&2
		exit 1
	fi
done

if ! grep -q '^kernel.string=' "$template_dir/anykernel.sh"; then
	echo "AnyKernel3 template has no kernel.string property" >&2
	exit 1
fi
sed -i 's#^kernel.string=.*#kernel.string=Zix Gaming Kernel | POCO X3/NFC#' \
	"$template_dir/anykernel.sh"

cp "$kernel" "$dtb" "$dtbo" "$template_dir"/
zip_tmp="$stage_dir/$ZIPNAME"
(
	cd "$template_dir"
	zip -qr9 "$zip_tmp" * -x README.md '*placeholder'
)

zip -T "$zip_tmp" >/dev/null
if [[ -e "$PWD/$ZIPNAME" ]]; then
	echo "ZIP already exists: $ZIPNAME" >&2
	exit 1
fi
mv "$zip_tmp" "$PWD/$ZIPNAME"
echo "Flashable ZIP: $ZIPNAME"
