#!/bin/bash
# ==========================================================================
# Patch ReKernel for Kernel
# Pro Version - Auto Detect Config & Workflow Optimized
# ==========================================================================

echo "[*] ========================================"
echo "[*] Memulai Patch ReKernel"
echo "[*] ========================================"

# 1. Cari defconfig yang sedang digunakan secara otomatis (Jika kosong)
if [ -z "$TARGET_CONFIG" ]; then
    TARGET_CONFIG=$(grep -Rsl "^CONFIG_KSU=y" arch/*/configs 2>/dev/null | head -n1)
fi

# Validasi akhir TARGET_CONFIG
if [ -z "$TARGET_CONFIG" ] || [ ! -f "$TARGET_CONFIG" ]; then
    echo "Skip/Error: Defconfig aktif tidak ditemukan."
    exit 1
fi

echo "[*] Using config: $TARGET_CONFIG"

# 2. Cek apakah sudah ter-patch sebelumnya
if grep -q "^CONFIG_REKERNEL=y" "$TARGET_CONFIG"; then
    echo "  -> Skip: CONFIG_REKERNEL=y sudah ada di defconfig."
    echo "[+] Done. Patch ReKernel selesai."
    exit 0
fi

echo "[*] Syarat terpenuhi, mengambil file patch..."

# 3. Persiapkan Repositori Patch
REPO_URL="https://github.com/kyzuna28/Compiler.git"
REPO_DIR="/tmp/Compiler_Repo"

if [ ! -d "$REPO_DIR" ]; then
    git clone --depth=1 "$REPO_URL" "$REPO_DIR" -q || { echo "[!] Error: Gagal clone repo patch."; exit 1; }
fi

REKERNEL_SH=$(find "$REPO_DIR" -type f -name "rekernel_patches.sh" | head -n 1)
REKERNEL_PATCH=$(find "$REPO_DIR" -type f -name "rekernel_extra.patch" | head -n 1)

# 4. Eksekusi Script ReKernel
if [ -n "$REKERNEL_SH" ] && [ -f "$REKERNEL_SH" ]; then
    echo "[*] Mengeksekusi $(basename "$REKERNEL_SH")..."
    cp "$REKERNEL_SH" ./
    bash "./$(basename "$REKERNEL_SH")" || echo "  [-] Warning: Eksekusi script tidak sempurna."
    rm -f "./$(basename "$REKERNEL_SH")"
else
    echo "[!] Error: Script rekernel_patches.sh tidak ditemukan!"
    exit 1
fi

# 5. Terapkan Patch Ekstra ReKernel
if [ -n "$REKERNEL_PATCH" ] && [ -f "$REKERNEL_PATCH" ]; then
    echo "[*] Menerapkan patch $(basename "$REKERNEL_PATCH")..."
    mkdir -p drivers/rekernel
    cp "$REKERNEL_PATCH" ./
    patch -p1 < "./$(basename "$REKERNEL_PATCH")" > /dev/null 2>&1 || true
    rm -f "./$(basename "$REKERNEL_PATCH")"
fi

# 6. Update Defconfig
echo "CONFIG_REKERNEL=y" >> "$TARGET_CONFIG"
echo "  -> Patched: Ditambahkan CONFIG_REKERNEL=y ke config"

echo "[+] Done. Patch ReKernel selesai dieksekusi."
