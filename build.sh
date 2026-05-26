#!/bin/bash
# ===================================================
# 🛡️ STERILISASI & ISOLASI DEBIAN TOTAL (ANTI-BOCOR)
# ===================================================
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
unset TERMUX_VERSION
unset TERMUX_MAIN_PACKAGE_FORMAT
unset LD_PRELOAD
unset PREFIX

# ===================================================
# Konfigurasi Identitas & Arsitektur
# ===================================================
export KBUILD_BUILD_USER="selea×kyy"
export KBUILD_BUILD_HOST="project_build"
export ARCH=arm64
export SUBARCH=arm64
export O=out
export CLANG_TRIPLE="aarch64-linux-gnu-"

DEFCONFIG="beryllium_defconfig"
KERNEL_IMAGE="${O}/arch/arm64/boot/Image.gz-dtb"
LOG_MENTAH="build_raw.log"

echo "==================================================="
echo "🔨 Memulai Kompilasi Kernel di DEBIAN (Anti-Bocor)"
echo "==================================================="
START_TIME=$(date +"%s")

# Persiapan Folder Bersih
rm -f "$LOG_MENTAH"
rm -rf "$O"
mkdir -p "$O"

# Proteksi Ganda (Menyaring kode yang dibenci Clang)
echo "⚙️  Merapikan kompatibilitas arsitektur CPU..."
find . -type f \( -name "Makefile*" -o -name "*.mk" -o -name "Kconfig*" \) -exec sed -i 's/cortex-a55+crypto/cortex-a55/g' {} + 2>/dev/null
find . -type f \( -name "Makefile*" -o -name "*.mk" -o -name "Kconfig*" \) -exec sed -i 's/cortex-a75+crypto/cortex-a75/g' {} + 2>/dev/null

echo "[1/2] Membuat konfigurasi .config..."
make O=$O ARCH=$ARCH HOSTCC=gcc CLANG_TRIPLE="$CLANG_TRIPLE" $DEFCONFIG >> "$LOG_MENTAH" 2>&1

echo "[2/2] Proses compiling sedang berjalan..."
echo "ℹ️  Layar bersih dari log. Mohon tunggu..."

# Kompilasi Utama (Dilengkapi injeksi Crypto ARMv8.2-A)
make -j$(nproc) O=$O ARCH=$ARCH \
    HOSTCC="gcc" \
    HOSTCFLAGS="-D_GNU_SOURCE" \
    CLANG_TRIPLE="$CLANG_TRIPLE" \
    CC="clang" \
    LD="ld.lld -m aarch64elf" \
    AR="llvm-ar" \
    NM="llvm-nm" \
    OBJCOPY="llvm-objcopy" \
    OBJDUMP="llvm-objdump" \
    STRIP="llvm-strip" \
    CROSS_COMPILE="aarch64-linux-gnu-" \
    CROSS_COMPILE_ARM32="arm-linux-gnueabi-" \
    KCFLAGS="-march=armv8.2-a+crypto" \
    KAFLAGS="-march=armv8.2-a+crypto" \
    Image.gz-dtb >> "$LOG_MENTAH" 2>&1
    
END_TIME=$(date +"%s")
DIFF=$(($END_TIME - $START_TIME))
echo "==================================================="

if [ -f "$KERNEL_IMAGE" ]; then
    echo "✅ BUILD 100% SUKSES!"
    echo "📦 File kernel Anda: $KERNEL_IMAGE"
    echo "⏱️  Waktu: $(($DIFF / 60)) menit $(($DIFF % 60)) detik."
    echo "==================================================="
    rm -f "$LOG_MENTAH"
else
    echo "❌ BUILD GAGAL!"
    echo "==================================================="
    echo "📄 RINGKASAN EROR DEBIAN:"
    echo "==================================================="
    grep -E -i "error:|failed:|stop\.|detected" "$LOG_MENTAH" | uniq | tail -n 25
    echo "==================================================="
    echo "💡 Tips: Detail lengkap ada di file: $LOG_MENTAH"
    echo "==================================================="
    exit 1
fi
