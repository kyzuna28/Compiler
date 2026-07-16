#!/bin/bash
# ==========================================================================
# Patch ReKernel for Kernel
# Pro Version - Workflow Optimized (Uses $TARGET_CONFIG)
# ==========================================================================

echo "[*] ========================================"
echo "[*] Memulai Patch ReKernel"
echo "[*] ========================================"

if [ -z "$TARGET_CONFIG" ] || [ ! -f "$TARGET_CONFIG" ]; then
    echo "[!] Error: Variabel TARGET_CONFIG tidak valid!"
    exit 1
fi

if grep -q "^CONFIG_REKERNEL=y" "$TARGET_CONFIG"; then
    echo "  -> [SKIP] CONFIG_REKERNEL=y sudah ada di defconfig."
    echo "[+] Done: Patch ReKernel selesai."
    exit 0
fi

REPO_URL="https://github.com/kyzuna28/Compiler.git"
REPO_DIR="/tmp/Compiler_Repo"

if [ ! -d "$REPO_DIR" ]; then
    git clone --depth=1 "$REPO_URL" "$REPO_DIR" -q || { echo "[!] Error: Gagal clone repo patch."; exit 1; }
fi

REKERNEL_SH=$(find "$REPO_DIR" -type f -name "rekernel_patches.sh" | head -n 1)
REKERNEL_PATCH=$(find "$REPO_DIR" -type f -name "rekernel_extra.patch" | head -n 1)

if [ -n "$REKERNEL_SH" ] && [ -f "$REKERNEL_SH" ]; then
    echo "[*] Mengeksekusi $(basename "$REKERNEL_SH")..."
    cp "$REKERNEL_SH" ./
    bash "./$(basename "$REKERNEL_SH")" || echo "  [-] Warning: Eksekusi script tidak sempurna."
    rm -f "./$(basename "$REKERNEL_SH")"
else
    echo "[!] Error: Script rekernel_patches.sh tidak ditemukan!"
    exit 1
fi

if [ -n "$REKERNEL_PATCH" ] && [ -f "$REKERNEL_PATCH" ]; then
    echo "[*] Menerapkan patch $(basename "$REKERNEL_PATCH")..."
    mkdir -p drivers/rekernel
    cp "$REKERNEL_PATCH" ./
    patch -p1 < "./$(basename "$REKERNEL_PATCH")" > /dev/null 2>&1 || true
    rm -f "./$(basename "$REKERNEL_PATCH")"
fi

echo "CONFIG_REKERNEL=y" >> "$TARGET_CONFIG"
echo "  -> [OK] Added: CONFIG_REKERNEL=y"

echo "[+] Done: Patch ReKernel terpasang."
