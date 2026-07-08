#!/bin/bash
# ==========================================================================
# SUSFS Missing Include Workaround (Pure Bash Script)
# Merged and cleaned script - 2026 (Mode Pro No Typo)
# ==========================================================================

patch_files=(
    fs/open.c
)

echo "[*] Memulai pengecekan missing include SUSFS patch..."

# 1. Header SUSFS belum terpasang
if [ ! -f include/linux/susfs_def.h ]; then
    echo "Skip: include/linux/susfs_def.h tidak ditemukan."
    exit 0
fi

# 2. Pastikan target file open.c tersedia
if [ ! -f fs/open.c ]; then
    echo "Skip: fs/open.c tidak ditemukan di source kernel."
    exit 0
fi

echo "[*] Syarat terpenuhi, menerapkan patch injeksi header di posisi yang aman..."

# 3. Looping Eksekusi Patch
for i in "${patch_files[@]}"; do
    [ -f "$i" ] || continue

    case "$i" in
    fs/open.c)
        # Inject tepat di bawah <linux/compat.h> (Baris 33 sesuai referensi source lu)
        # agar struct current_uid() dikenali compiler dan tidak menyebabkan error 'member reference base type int'
        grep -q "#include <linux/susfs_def.h>" "$i" || \
        sed -i '/#include <linux\/compat.h>/a #include <linux/susfs_def.h>' "$i"

        echo "  -> Patched: $i"
        ;;
    esac
done

echo "[+] Done. Patch selesai dieksekusi."
