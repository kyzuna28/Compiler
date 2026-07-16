#!/bin/bash
# ==========================================================================
# Patch Baseband Guard for Kernel (Pure Bash Script)
# Merged and cleaned script - No Env Checking
# ==========================================================================

echo "[*] ========================================"
echo "[*] Memulai Patch Baseband Guard"
echo "[*] ========================================"

# 1. Validasi Dependency
if ! command -v wget &> /dev/null; then
    echo "[!] Error: Perintah 'wget' tidak ditemukan."
    exit 1
fi

# 2. Cari defconfig yang sedang digunakan (Otomatis)
TARGET_CONFIG=$(grep -Rsl "^CONFIG_KSU=y" arch/*/configs 2>/dev/null | head -n1)

if [ -z "$TARGET_CONFIG" ]; then
    echo "Skip: Defconfig aktif tidak ditemukan (Pastikan dijalankan di dalam root folder kernel)."
    exit 0
fi

echo "[*] Menggunakan defconfig: $TARGET_CONFIG"

# 3. Unduh dan eksekusi Baseband Guard setup (Link Bawaan)
echo "[*] Mengunduh dan mengeksekusi Baseband Guard setup..."
if ! wget -qO- https://github.com/vc-teahouse/Baseband-guard/raw/main/setup.sh | bash; then
    echo "[!] Error: Gagal mengunduh atau menjalankan setup script Baseband Guard."
    exit 1
fi

# 4. Patch CONFIG_BBG
if ! grep -q "^CONFIG_BBG=y" "$TARGET_CONFIG"; then
    echo "CONFIG_BBG=y" >> "$TARGET_CONFIG"
    echo "  -> [OK] Added: CONFIG_BBG=y"
else
    echo "  -> [SKIP] CONFIG_BBG=y sudah ada."
fi

# 5. Patch CONFIG_BBG_BLOCK_BOOT
if ! grep -q "^CONFIG_BBG_BLOCK_BOOT=y" "$TARGET_CONFIG"; then
    echo "CONFIG_BBG_BLOCK_BOOT=y" >> "$TARGET_CONFIG"
    echo "  -> [OK] Added: CONFIG_BBG_BLOCK_BOOT=y"
else
    echo "  -> [SKIP] CONFIG_BBG_BLOCK_BOOT=y sudah ada."
fi

# 6. Pengecekan dan Patch LSM Hooks
if ! grep -q "DEFINE_LSM" "include/linux/lsm_hooks.h" 2>/dev/null; then
    echo "  -> [SKIP] DEFINE_LSM tidak ditemukan pada LSM hooks."
else
    if grep -q "baseband_guard" "$TARGET_CONFIG"; then
        echo "  -> [SKIP] baseband_guard sudah terdaftar di dalam CONFIG_LSM."
    else
        echo "[*] Mendeteksi DEFINE_LSM, memproses konfigurasi LSM..."
        
        if grep -rq "^CONFIG_LSM=" "$TARGET_CONFIG"; then
            sed -i 's/\(CONFIG_LSM="[^"]*\)"/\1,baseband_guard"/' "$TARGET_CONFIG"
            echo "  -> [OK] CONFIG_LSM diupdate dengan baseband_guard."
        else
            if grep -q "bpf" "./security/Kconfig" 2>/dev/null; then
                echo 'CONFIG_LSM="lockdown,yama,loadpin,safesetid,integrity,selinux,smack,tomoyo,apparmor,bpf,baseband_guard"' >> "$TARGET_CONFIG"
                echo "  -> [OK] Ditambahkan: Default CONFIG_LSM (dengan bpf & baseband_guard)"
            else
                echo 'CONFIG_LSM="lockdown,yama,loadpin,safesetid,integrity,selinux,smack,tomoyo,apparmor,baseband_guard"' >> "$TARGET_CONFIG"
                echo "  -> [OK] Ditambahkan: Default CONFIG_LSM (dengan baseband_guard)"
            fi
        fi
    fi
fi

echo "[+] Done: Patch Baseband Guard terpasang."
echo "========================================"
