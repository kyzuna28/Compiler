#!/bin/bash
# ==========================================================================
# Patch ReKernel for Kernel (Direct Install Version)
# ==========================================================================

echo "[*] ========================================"
echo "[*] Memulai Patch ReKernel"
echo "[*] ========================================"

# Validasi Variabel Environment Wajib
for var in GITHUB_WORKSPACE KERNEL_ARCH DEFCONFIG_NAME; do
    if [[ -z "${!var}" ]]; then
        echo "[!] Error: Variabel environment \$${var} belum diatur!"
        exit 1
    fi
done

# Clone / Sinkronisasi Repository
REPO_URL="https://github.com/kyzuna28/Compiler.git"
REPO_DIR="/tmp/Compiler_Repo"

if [[ ! -d "$REPO_DIR" ]]; then
    git clone --depth=1 "$REPO_URL" "$REPO_DIR" -q || exit 1
fi

# Pindah ke direktori kernel
TARGET_DIR="${GITHUB_WORKSPACE}/device_kernel"
cd "$TARGET_DIR" || exit 1

# Auto-mencari file ReKernel di Repo
echo "[*] Auto-mencari file sumber di repository..."
REKERNEL_SH=$(find "$REPO_DIR" -type f -name "rekernel_patches.sh" | head -n 1)
REKERNEL_PATCH=$(find "$REPO_DIR" -type f -name "rekernel_extra.patch" | head -n 1)

DEFCONFIG_PATH="./arch/${KERNEL_ARCH}/configs/${DEFCONFIG_NAME}"

# Mencegah Double Patching
if grep -q "^CONFIG_REKERNEL=y" "$DEFCONFIG_PATH"; then
    echo "  -> [SKIP] CONFIG_REKERNEL=y sudah ada di defconfig."
    echo "[+] Done: Patch ReKernel selesai (Sudah terpasang)."
    exit 0
fi

# Eksekusi rekernel_patches.sh
if [[ -n "$REKERNEL_SH" && -f "$REKERNEL_SH" ]]; then
    echo "[*] Mengeksekusi $(basename "$REKERNEL_SH")..."
    cp "$REKERNEL_SH" ./
    bash "./$(basename "$REKERNEL_SH")" || echo "  [-] Warning: Eksekusi script tidak sempurna."
    rm -f "./$(basename "$REKERNEL_SH")"
else
    echo "[!] Error: Script rekernel_patches.sh tidak ditemukan!"
    exit 1
fi

# Eksekusi rekernel_extra.patch
if [[ -n "$REKERNEL_PATCH" && -f "$REKERNEL_PATCH" ]]; then
    echo "[*] Menerapkan patch $(basename "$REKERNEL_PATCH")..."
    mkdir -p drivers/rekernel
    cp "$REKERNEL_PATCH" ./
    patch -p1 < "./$(basename "$REKERNEL_PATCH")" > /dev/null 2>&1 || true
    rm -f "./$(basename "$REKERNEL_PATCH")"
fi

# Tambahkan CONFIG ke defconfig
echo "CONFIG_REKERNEL=y" >> "$DEFCONFIG_PATH"
echo "  -> [OK] Added: CONFIG_REKERNEL=y"

echo "[+] Done: Patch ReKernel terpasang."
echo "========================================"
