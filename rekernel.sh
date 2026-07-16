#!/bin/bash
# ==========================================================================
# Patch ReKernel for Kernel (Final Pro Version - Auto Search GitHub)
# ==========================================================================

echo "[*] ========================================"
echo "[*] Memulai Patch ReKernel"
echo "[*] ========================================"

# 1. Cek status aktivasi
if [[ "${REKERNEL_ENABLE}" != "true" ]]; then
    echo "[-] Skip: REKERNEL_ENABLE tidak diatur ke 'true'."
    exit 0
fi

# 2. Validasi Variabel Environment Wajib
for var in GITHUB_WORKSPACE KERNEL_ARCH DEFCONFIG_NAME; do
    if [[ -z "${!var}" ]]; then
        echo "[!] Error: Variabel environment \$${var} belum diatur!"
        exit 1
    fi
done

# 3. Clone / Sinkronisasi Repository Compiler
REPO_URL="https://github.com/kyzuna28/Compiler.git"
REPO_DIR="/tmp/Compiler_Repo"

echo "[*] Menyiapkan repository sumber patch dari kyzuna28/Compiler..."
if [[ ! -d "$REPO_DIR" ]]; then
    if ! git clone --depth=1 "$REPO_URL" "$REPO_DIR" -q; then
        echo "[!] Error: Gagal melakukan clone repository $REPO_URL"
        exit 1
    fi
else
    echo "  -> [OK] Menggunakan cache repository di $REPO_DIR"
fi

# 4. Pindah dan cek direktori kernel
TARGET_DIR="${GITHUB_WORKSPACE}/device_kernel"
if [[ ! -d "$TARGET_DIR" ]]; then
    echo "[!] Error: Direktori kernel $TARGET_DIR tidak ditemukan."
    exit 1
fi

cd "$TARGET_DIR" || exit 1

# 5. Auto-mencari file ReKernel di Repo
echo "[*] Auto-mencari file ReKernel di repository..."
REKERNEL_SH=$(find "$REPO_DIR" -type f -name "rekernel_patches.sh" | head -n 1)
REKERNEL_PATCH=$(find "$REPO_DIR" -type f -name "rekernel_extra.patch" | head -n 1)

DEFCONFIG_PATH="./arch/${KERNEL_ARCH}/configs/${DEFCONFIG_NAME}"
if [[ ! -f "$DEFCONFIG_PATH" ]]; then
    echo "[!] Error: Defconfig aktif ($DEFCONFIG_PATH) tidak ditemukan."
    exit 1
fi

# 6. Mencegah Double Patching
if grep -q "^CONFIG_REKERNEL=y" "$DEFCONFIG_PATH"; then
    echo "  -> [SKIP] CONFIG_REKERNEL=y sudah ada di defconfig."
    echo "[+] Done: Patch ReKernel selesai (Skipped)."
    echo "========================================"
    exit 0
fi

# ==========================================================================
# PROSES EKSEKUSI PATCH
# ==========================================================================

# 7. Eksekusi rekernel_patches.sh
if [[ -n "$REKERNEL_SH" && -f "$REKERNEL_SH" ]]; then
    echo "[*] Mengeksekusi $(basename "$REKERNEL_SH")..."
    cp "$REKERNEL_SH" ./
    
    if bash "./$(basename "$REKERNEL_SH")"; then
        echo "  -> [OK] rekernel_patches.sh berhasil dieksekusi."
    else
        echo "  [-] Error: Gagal mengeksekusi rekernel_patches.sh secara sempurna."
    fi
    
    rm -f "./$(basename "$REKERNEL_SH")"
else
    echo "[!] Error: File rekernel_patches.sh tidak ditemukan di repository."
    exit 1
fi

# 8. Eksekusi rekernel_extra.patch
if [[ -n "$REKERNEL_PATCH" && -f "$REKERNEL_PATCH" ]]; then
    echo "[*] Menerapkan patch $(basename "$REKERNEL_PATCH")..."
    mkdir -p drivers/rekernel
    cp "$REKERNEL_PATCH" ./
    
    if patch -p1 < "./$(basename "$REKERNEL_PATCH")" > /dev/null 2>&1; then
        echo "  -> [OK] rekernel_extra.patch berhasil diterapkan secara bersih."
    else
        echo "  [-] Warning: rekernel_extra.patch mengembalikan peringatan, diabaikan (|| true)."
    fi
    
    rm -f "./$(basename "$REKERNEL_PATCH")"
else
    echo "  -> [SKIP] File rekernel_extra.patch tidak ditemukan di repository."
fi

# 9. Tambahkan CONFIG ke defconfig
echo "CONFIG_REKERNEL=y" >> "$DEFCONFIG_PATH"
echo "  -> [OK] Added: CONFIG_REKERNEL=y ke $DEFCONFIG_PATH"

echo "[+] Done: Patch ReKernel selesai dieksekusi dengan sukses."
echo "========================================"
