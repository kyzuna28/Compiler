#!/bin/bash
# ==========================================================================
# SUSFS Missing Include Workaround (Pure Bash Script)
# Merged and cleaned script - 2026 (Mode Pro No Typo)
# ==========================================================================

patch_files=(
    fs/open.c
)

echo "[*] Memulai pengecekan missing include SUSFS..."

# 1. Cek apakah file header SUSFS ada di source kernel
if [ ! -f include/linux/susfs_def.h ]; then
    echo "Skip: File include/linux/susfs_def.h tidak ditemukan. Patch SUSFS belum diterapkan."
    exit 0
fi

# 2. Cari defconfig yang sedang digunakan untuk memastikan SUSFS aktif
TARGET_CONFIG=$(grep -Rsl "^CONFIG_SUSFS=y" arch/*/configs 2>/dev/null | head -n1)

if [ -z "$TARGET_CONFIG" ]; then
    echo "Skip: Defconfig dengan CONFIG_SUSFS=y tidak ditemukan."
    exit 0
fi

echo "[*] Using config: $TARGET_CONFIG"

echo "[*] Syarat terpenuhi, menerapkan patch injeksi header SUSFS..."

# 3. Looping Eksekusi Patch
for i in "${patch_files[@]}"; do
    # Jika file tidak ada, lewati ke file berikutnya
    [ -f "$i" ] || continue

    case "$i" in
    fs/open.c)
        # Cek apakah file sudah memiliki include susfs_def.h
        if grep -q "#include <linux/susfs_def.h>" "$i"; then
            echo "  -> Skip: $i sudah memiliki include susfs_def.h"
        else
            # Inject include di baris paling atas (baris 1) menggunakan sed
            sed -i '1i #include <linux/susfs_def.h>' "$i"
            echo "  -> Patched: $i"
        fi
        ;;
    esac
done

echo "[+] Done. Patch selesai dieksekusi."
