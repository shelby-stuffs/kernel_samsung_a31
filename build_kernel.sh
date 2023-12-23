
SECONDS=0 # builtin bash timer
ZIPNAME="/tmp/output/SunriseKernel-A315F_$(date +%Y%m%d-%H%M).zip"
AK3_DIR="$HOME/android/AnyKernel3"

mkdir -p /tmp/output

env() {
export TELEGRAM_BOT_TOKEN=""
export TELEGRAM_CHAT_ID="@SunriseCI"

TRIGGER_SHA="$(git rev-parse HEAD)"
LATEST_COMMIT="$(git log --pretty=format:'%s' -1)"
COMMIT_BY="$(git log --pretty=format:'by %an' -1)"
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
KERNEL_VERSION=$(cat out/.config | grep Linux/arm64 | cut -d " " -f3)

export FILE_CAPTION="
🏚️ Linux version: $KERNEL_VERSION
🌿 Branch: $BRANCH
🎁 Top commit: $LATEST_COMMIT
👩‍💻 Commit author: $COMMIT_BY"
}

# Default defconfig to use for builds.
export CONFIG=a31_defconfig

# Default directory where kernel is located in.
KDIR=$(pwd)
export KDIR

# Default linker to use for builds.
export LINKER="ld.lld"

# Compiler to use for builds.
export COMPILER=clang


if [[ ${COMPILER} == gcc ]]; then
	if [ ! -d "${KDIR}/gcc64" ]; then
		curl -sL https://github.com/mvaisakh/gcc-arm64/archive/refs/heads/gcc-master.tar.gz | tar -xzf -
		mv "${KDIR}"/gcc-arm64-gcc-master "${KDIR}"/gcc64
	fi

	if [ ! -d "${KDIR}/gcc32" ]; then
		curl -sL https://github.com/cyberknight777/gcc-arm/archive/refs/heads/gcc-master.tar.gz | tar -xzf -
		mv "${KDIR}"/gcc-arm-gcc-master "${KDIR}"/gcc32
	fi

    KBUILD_COMPILER_STRING=$("${KDIR}"/gcc64/bin/aarch64-elf-gcc --version | head -n 1)
    export KBUILD_COMPILER_STRING
    export PATH="${KDIR}"/gcc32/bin:"${KDIR}"/gcc64/bin:/usr/bin/:${PATH}
    MAKE+=(
        ARCH=arm64
                O=out
		CROSS_COMPILE=aarch64-elf-
		CROSS_COMPILE_ARM32=arm-eabi-
		LD="${KDIR}"/gcc64/bin/aarch64-elf-"${LINKER}"
		AR=aarch64-elf-ar
		AS=aarch64-elf-as
		NM=aarch64-elf-nm
		OBJDUMP=aarch64-elf-objdump
		OBJCOPY=aarch64-elf-objcopy
		CC=aarch64-elf-gcc
    )

elif [[ "${COMPILER}" == clang ]]; then
    if [ ! -d "${KDIR}/clang" ]; then
        wget https://github.com/kdrag0n/proton-clang/archive/refs/heads/master.zip
        unzip "${KDIR}"/master.zip
        mv "${KDIR}"/proton-clang-master "${KDIR}"/clang
    fi

    KBUILD_COMPILER_STRING=$("${KDIR}"/clang/bin/clang -v 2>&1 | head -n 1 | sed 's/(https..*//' | sed 's/ version//')
    export KBUILD_COMPILER_STRING
    export PATH=$KDIR/clang/bin/:/usr/bin/:${PATH}
    MAKE+=(
        ARCH=arm64
        O=out
        CC=clang \
        LD=ld.lld \
        AR=llvm-ar \
        AS=llvm-as \
        NM=llvm-nm \
        OBJCOPY=llvm-objcopy \
        OBJDUMP=llvm-objdump \
        STRIP=llvm-strip \
        CROSS_COMPILE=aarch64-linux-android- \
        CROSS_COMPILE_ARM32=arm-linux-androideabi- \
        CLANG_TRIPLE=aarch64-linux-gnu-
    )
fi


make "${MAKE[@]}" $CONFIG
time make -j16 "${MAKE[@]}" Image 2>&1 | tee log.txt

env

if [ -f "out/arch/arm64/boot/Image" ]; then
echo -e "\nKernel compiled succesfully! Zipping up...\n"
if [ -d "$AK3_DIR" ]; then
cp -r $AK3_DIR AnyKernel3
elif ! git clone -q https://github.com/ShelbyHell/AnyKernel3 -b a31; then
echo -e "\nAnyKernel3 repo not found locally and cloning failed! Aborting..."
exit 1
fi
cp out/arch/arm64/boot/Image AnyKernel3
rm -f *zip
cd AnyKernel3
git checkout a31 &> /dev/null
zip -r9 "$ZIPNAME" * -x '*.git*' README.md *placeholder
cd ..
rm -rf AnyKernel3
rm -rf out/arch/arm64/boot
echo -e "\nCompleted in $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s) !"
echo "Zip: $ZIPNAME"
if ! [[ $HOSTNAME = "enprytna" && $USER = "endi" ]]; then
curl -F document=@"${ZIPNAME}" -F "caption=${FILE_CAPTION}" "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendDocument?chat_id=${TELEGRAM_CHAT_ID}&parse_mode=html"
fi
else
echo -e "\nCompilation failed!"
exit 1
fi