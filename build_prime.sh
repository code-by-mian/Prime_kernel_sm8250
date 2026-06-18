#!/bin/sh

KERNEL_DIR=$(pwd)
DEVICE="$1"

# --- Functions ---
build_kernel() {
    echo "-----------------------------------------------"
    echo "Beginning kernel compilation for $DEVICE..."
    echo "-----------------------------------------------"

    export ARCH=arm64
    mkdir -p out

    export PATH=$(pwd)/llvm-21/bin:$PATH

    BUILD_VAR="-j$(nproc) -C $(pwd) O=$(pwd)/out ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- LLVM=1 LLVM_IAS=1"

    echo ">>> Building kernel for $DEVICE"

    cat arch/arm64/configs/vendor/kona-sec-perf_defconfig \
        arch/arm64/configs/vendor/samsung/${DEVICE}.config \
        arch/arm64/configs/vendor/not/no_werror.config \
        arch/arm64/configs/ksu.config \
        arch/arm64/configs/vendor/debugfs.config > arch/arm64/configs/temp_defconfig

    cat >> arch/arm64/configs/temp_defconfig <<EOF
# Enable ThinLTO for performance
CONFIG_THINLTO=y
CONFIG_LTO_CLANG=y
# CONFIG_LTO_NONE is not set

CONFIG_LOCALVERSION="-AstroKernel"
EOF

    make $BUILD_VAR temp_defconfig
    rm arch/arm64/configs/temp_defconfig
}

build_dtb() {
    echo ">>> Building dtb"
    make $BUILD_VAR
    make $BUILD_VAR dtbs

    cat out/arch/arm64/boot/dts/vendor/qcom/kona*.dtb > out/arch/arm64/boot/dts/dtb
}

build_dtbo() {
    echo ">>> Building dtbo.img"
    DTBO_FILES=$(find out/arch/arm64/boot/dts/samsung/$DEVICE -name "kona-sec-$DEVICE-*.dtbo")
    tools/mkdtimg create out/dtbo.img --page_size=4096 ${DTBO_FILES}
}

prepare_ak3() {
    echo ">>> Packaging AnyKernel3"
    cd AnyKernel3/ || exit 1

    cp "$KERNEL_DIR/out/dtbo.img" dtbo.img
    cp "$KERNEL_DIR/out/arch/arm64/boot/Image" Image
    cp "$KERNEL_DIR/out/arch/arm64/boot/dts/dtb" dtb

    sed -i "s/^device\.name1=.*/device.name1=${DEVICE}/" anykernel.sh

    DATESTAMP=$(date +%Y%m%d)
    ZIP_NAME="AstroKernel-${DEVICE}-${DATESTAMP}.zip"
    zip -r "../${ZIP_NAME}" *
    cd "$KERNEL_DIR"
}

# --- Execution ---
build_kernel
build_dtb
build_dtbo
prepare_ak3

echo ">>> Build complete: AstroKernel-${DEVICE}-$(date +%Y%m%d-%H%M).zip"
