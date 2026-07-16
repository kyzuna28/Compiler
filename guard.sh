#!/bin/bash
# ==========================================================================
# Patch Baseband Guard for Kernel
# Pro Version - Auto Detect Config & Workflow Optimized
# ==========================================================================

echo "[*] ========================================"
echo "[*] Memulai Patch Baseband Guard"
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
echo "[*] Syarat terpenuhi, mengambil file patch..."

# 2. Mengunduh dan Menjalankan Setup Script Baseband Guard
if ! wget -qO- https://github.com/vc-teahouse/Baseband-guard/raw/main/setup.sh | bash; then
    echo "[!] Error: Gagal mengunduh atau menjalankan setup script Baseband Guard."
    exit 1
fi

# 3. Update Defconfig (BBG Base)
if ! grep -q "^CONFIG_BBG=y" "$TARGET_CONFIG"; then
    echo "CONFIG_BBG=y" >> "$TARGET_CONFIG"
    echo "  -> Patched: Ditambahkan CONFIG_BBG=y ke config"
else
    echo "  -> Skip: CONFIG_BBG=y sudah ada di defconfig."
fi

if ! grep -q "^CONFIG_BBG_BLOCK_BOOT=y" "$TARGET_CONFIG"; then
    echo "CONFIG_BBG_BLOCK_BOOT=y" >> "$TARGET_CONFIG"
    echo "  -> Patched: Ditambahkan CONFIG_BBG_BLOCK_BOOT=y ke config"
else
    echo "  -> Skip: CONFIG_BBG_BLOCK_BOOT=y sudah ada di defconfig."
fi

# 4. Konfigurasi LSM Hooks
if ! grep -q "DEFINE_LSM" "include/linux/lsm_hooks.h" 2>/dev/null; then
    echo "  -> Skip: DEFINE_LSM tidak ditemukan pada LSM hooks."
else
    if grep -q "baseband_guard" "$TARGET_CONFIG"; then
        echo "  -> Skip: baseband_guard sudah terdaftar di CONFIG_LSM."
    else
        echo "[*] Memproses konfigurasi LSM hooks..."
        if grep -rq "^CONFIG_LSM=" "$TARGET_CONFIG"; then
            sed -i 's/\(CONFIG_LSM="[^"]*\)"/\1,baseband_guard"/' "$TARGET_CONFIG"
            echo "  -> Patched: CONFIG_LSM diupdate dengan baseband_guard."
        else
            if grep -q "bpf" "./security/Kconfig" 2>/dev/null; then
                echo 'CONFIG_LSM="lockdown,yama,loadpin,safesetid,integrity,selinux,smack,tomoyo,apparmor,bpf,baseband_guard"' >> "$TARGET_CONFIG"
            else
                echo 'CONFIG_LSM="lockdown,yama,loadpin,safesetid,integrity,selinux,smack,tomoyo,apparmor,baseband_guard"' >> "$TARGET_CONFIG"
            fi
            echo "  -> Patched: Ditambahkan default CONFIG_LSM (dengan baseband_guard)"
        fi
    fi
fi

echo "[+] Done. Patch Baseband Guard selesai dieksekusi."
