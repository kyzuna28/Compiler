#!/bin/bash
# ==========================================================================
# Patch ReKernel for Kernel (Pure Bash Script)
# Merged and cleaned script - No Env Checking
# ==========================================================================

echo "[*] ========================================"
echo "[*] Memulai Patch ReKernel"
echo "[*] ========================================"

# 1. Clone / Sinkronisasi Repository
REPO_URL="https://github.com/kyzuna28/Compiler.git"
REPO_DIR="/tmp/Compiler_Repo"

if [ ! -d "$REPO_DIR" ]; then
    echo "[*] Mengunduh repository patch..."
    git clone --depth=1 "$REPO_URL" "$REPO_DIR" -q || { echo "[!] Error: Gagal clone repo."; exit 1; }
fi

# 2. Auto-mencari file ReKernel di Repo
echo "[*] Auto-mencari file sumber di repository..."
REKERNEL_SH=$(find "$REPO_DIR" -type f -name "rekernel_patches.sh" | head -n 1)
REKERNEL_PATCH=$(find "$REPO_DIR" -type f -name "rekernel_extra.patch" | head -n 1)

# 3. Cari defconfig yang sedang digunakan (Otomatis tanpa KERNEL_ARCH & DEFCONFIG_NAME)
TARGET_CONFIG=$(grep -Rsl "^CONFIG_KSU=y" arch/*/configs 2>/dev/null | head -n1)

if [ -z "$TARGET_CONFIG" ]; then
    echo "Skip: Defconfig aktif tidak ditemukan (Pastikan dijalankan di dalam root folder kernel)."
    exit 0
fi

echo "[*] Using config: $TARGET_CONFIG"

# 4. Mencegah Double Patching
if grep -q "^CONFIG_REKERNEL=y" "$TARGET_CONFIG"; then
    echo "  -> [SKIP] CONFIG_REKERNEL=y sudah ada di defconfig."
    echo "[+] Done: Patch ReKernel selesai (Sudah terpasang)."
    exit 0
fi

# 5. Eksekusi rekernel_patches.sh
if [ -n "$REKERNEL_SH" ] && [ -f "$REKERNEL_SH" ]; then
    echo "[*] Mengeksekusi $(basename "$REKERNEL_SH")..."
    cp "$REKERNEL_SH" ./
    bash "./$(basename "$REKERNEL_SH")" || echo "  [-] Warning: Eksekusi script tidak sempurna."
    rm -f "./$(basename "$REKERNEL_SH")"
else
    echo "[!] Error: Script rekernel_patches.sh tidak ditemukan!"
    exit 1
fi

# 6. Eksekusi rekernel_extra.patch
if [ -n "$REKERNEL_PATCH" ] && [ -f "$REKERNEL_PATCH" ]; then
    echo "[*] Menerapkan patch $(basename "$REKERNEL_PATCH")..."
    mkdir -p drivers/rekernel
    cp "$REKERNEL_PATCH" ./
    patch -p1 < "./$(basename "$REKERNEL_PATCH")" > /dev/null 2>&1 || true
    rm -f "./$(basename "$REKERNEL_PATCH")"
fi

# 7. Tambahkan CONFIG ke defconfig
echo "CONFIG_REKERNEL=y" >> "$TARGET_CONFIG"
echo "  -> [OK] Added: CONFIG_REKERNEL=y"

echo "[+] Done: Patch ReKernel terpasang."
echo "========================================"
