#!/bin/bash
# ==========================================================================
# Patch Baseband Guard for Kernel
# Pro Version - Workflow Optimized (Uses $TARGET_CONFIG)
# ==========================================================================

echo "[*] ========================================"
echo "[*] Memulai Patch Baseband Guard"
echo "[*] ========================================"

if [ -z "$TARGET_CONFIG" ] || [ ! -f "$TARGET_CONFIG" ]; then
    echo "[!] Error: Variabel TARGET_CONFIG tidak valid!"
    exit 1
fi

if ! wget -qO- https://github.com/vc-teahouse/Baseband-guard/raw/main/setup.sh | bash; then
    echo "[!] Error: Gagal mengunduh atau menjalankan setup script Baseband Guard."
    exit 1
fi

if ! grep -q "^CONFIG_BBG=y" "$TARGET_CONFIG"; then
    echo "CONFIG_BBG=y" >> "$TARGET_CONFIG"
    echo "  -> [OK] Added: CONFIG_BBG=y"
fi

if ! grep -q "^CONFIG_BBG_BLOCK_BOOT=y" "$TARGET_CONFIG"; then
    echo "CONFIG_BBG_BLOCK_BOOT=y" >> "$TARGET_CONFIG"
    echo "  -> [OK] Added: CONFIG_BBG_BLOCK_BOOT=y"
fi

if ! grep -q "DEFINE_LSM" "include/linux/lsm_hooks.h" 2>/dev/null; then
    echo "  -> [SKIP] DEFINE_LSM tidak ditemukan pada LSM hooks."
else
    if grep -q "baseband_guard" "$TARGET_CONFIG"; then
        echo "  -> [SKIP] baseband_guard sudah terdaftar di CONFIG_LSM."
    else
        echo "[*] Memproses konfigurasi LSM hooks..."
        if grep -rq "^CONFIG_LSM=" "$TARGET_CONFIG"; then
            sed -i 's/\(CONFIG_LSM="[^"]*\)"/\1,baseband_guard"/' "$TARGET_CONFIG"
            echo "  -> [OK] CONFIG_LSM diupdate dengan baseband_guard."
        else
            if grep -q "bpf" "./security/Kconfig" 2>/dev/null; then
                echo 'CONFIG_LSM="lockdown,yama,loadpin,safesetid,integrity,selinux,smack,tomoyo,apparmor,bpf,baseband_guard"' >> "$TARGET_CONFIG"
            else
                echo 'CONFIG_LSM="lockdown,yama,loadpin,safesetid,integrity,selinux,smack,tomoyo,apparmor,baseband_guard"' >> "$TARGET_CONFIG"
            fi
            echo "  -> [OK] Ditambahkan: Default CONFIG_LSM (dengan baseband_guard)"
        fi
    fi
fi

echo "[+] Done: Patch Baseband Guard terpasang."
