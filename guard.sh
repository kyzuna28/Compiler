#!/bin/bash
# ==========================================================================
# Patch Baseband Guard for Kernel
# Ultra Pro Version - Full Exhaustive Check & Detailed Logging
# ==========================================================================

echo "[*] ========================================"
echo "[*] Memulai Patch Baseband Guard"
echo "[*] ========================================"

# 1. Deteksi Defconfig Otomatis
if [ -z "$TARGET_CONFIG" ]; then
    echo "[*] Info: Variabel TARGET_CONFIG kosong, mencari otomatis..."
    TARGET_CONFIG=$(grep -Rsl "^CONFIG_KSU=y" arch/*/configs 2>/dev/null | head -n1)
    if [ -n "$TARGET_CONFIG" ]; then
        echo "  -> [OK] Ditemukan defconfig aktif: $TARGET_CONFIG"
    else
        echo "  [-] Warning: Tidak dapat menemukan defconfig dengan CONFIG_KSU=y otomatis."
    fi
else
    echo "[*] Info: TARGET_CONFIG sudah diatur manual ke $TARGET_CONFIG"
fi

if [ -z "$TARGET_CONFIG" ] || [ ! -f "$TARGET_CONFIG" ]; then
    echo "[!] Error: Defconfig aktif tidak valid atau file tidak ditemukan! Proses berhenti."
    exit 1
else
    echo "  -> [OK] Defconfig tervalidasi dan siap digunakan."
fi

# 2. Mengunduh dan Menjalankan Setup Script Baseband Guard
echo "[*] Menghubungi repositori Baseband Guard (GitHub)..."
if wget -qO- https://github.com/vc-teahouse/Baseband-guard/raw/main/setup.sh | bash; then
    echo "  -> [OK] Setup script Baseband Guard berhasil diunduh dan dieksekusi."
else
    echo "[!] Error: Gagal mengunduh atau mengeksekusi setup script Baseband Guard dari GitHub."
    exit 1
fi

# 3. Update Defconfig (BBG Base)
echo "[*] Memeriksa flag CONFIG_BBG di defconfig..."
if ! grep -q "^CONFIG_BBG=y" "$TARGET_CONFIG"; then
    if echo "CONFIG_BBG=y" >> "$TARGET_CONFIG"; then
        echo "  -> [OK] Injected: Ditambahkan CONFIG_BBG=y ke $TARGET_CONFIG"
    else
        echo "  [-] Error: Gagal menulis CONFIG_BBG ke defconfig."
    fi
else
    echo "  -> Skip: CONFIG_BBG=y sudah tertanam sebelumnya."
fi

echo "[*] Memeriksa flag CONFIG_BBG_BLOCK_BOOT di defconfig..."
if ! grep -q "^CONFIG_BBG_BLOCK_BOOT=y" "$TARGET_CONFIG"; then
    if echo "CONFIG_BBG_BLOCK_BOOT=y" >> "$TARGET_CONFIG"; then
        echo "  -> [OK] Injected: Ditambahkan CONFIG_BBG_BLOCK_BOOT=y ke $TARGET_CONFIG"
    else
        echo "  [-] Error: Gagal menulis CONFIG_BBG_BLOCK_BOOT ke defconfig."
    fi
else
    echo "  -> Skip: CONFIG_BBG_BLOCK_BOOT=y sudah tertanam sebelumnya."
fi

# 4. Konfigurasi LSM Hooks
echo "[*] Memeriksa lsm_hooks.h untuk injeksi LSM..."
if [ -f "include/linux/lsm_hooks.h" ]; then
    if ! grep -q "DEFINE_LSM" "include/linux/lsm_hooks.h" 2>/dev/null; then
        echo "  -> Skip: DEFINE_LSM tidak ditemukan pada include/linux/lsm_hooks.h (Versi Kernel mungkin berbeda)."
    else
        echo "  -> [OK] DEFINE_LSM didukung oleh kernel ini."
        
        echo "[*] Mengecek pendaftaran baseband_guard di CONFIG_LSM..."
        if grep -q "baseband_guard" "$TARGET_CONFIG"; then
            echo "  -> Skip: baseband_guard sudah terdaftar di daftar CONFIG_LSM."
        else
            echo "  [*] Memproses injeksi baseband_guard ke antrean LSM..."
            if grep -rq "^CONFIG_LSM=" "$TARGET_CONFIG"; then
                # Jika CONFIG_LSM sudah ada, sisipkan di akhir
                if sed -i 's/\(CONFIG_LSM="[^"]*\)"/\1,baseband_guard"/' "$TARGET_CONFIG"; then
                    echo "  -> [OK] CONFIG_LSM berhasil diupdate dengan parameter baseband_guard."
                else
                    echo "  [-] Error: Gagal mengedit parameter CONFIG_LSM menggunakan sed."
                fi
            else
                # Jika CONFIG_LSM belum ada sama sekali, buat baru
                echo "  [*] Parameter CONFIG_LSM tidak ditemukan. Membuat entri default..."
                if grep -q "bpf" "./security/Kconfig" 2>/dev/null; then
                    echo 'CONFIG_LSM="lockdown,yama,loadpin,safesetid,integrity,selinux,smack,tomoyo,apparmor,bpf,baseband_guard"' >> "$TARGET_CONFIG"
                    echo "  -> [OK] Entri default CONFIG_LSM (dengan bpf & baseband_guard) berhasil dibuat."
                else
                    echo 'CONFIG_LSM="lockdown,yama,loadpin,safesetid,integrity,selinux,smack,tomoyo,apparmor,baseband_guard"' >> "$TARGET_CONFIG"
                    echo "  -> [OK] Entri default CONFIG_LSM (tanpa bpf) berhasil dibuat."
                fi
            fi
        fi
    fi
else
    echo "  [-] Error: File include/linux/lsm_hooks.h tidak ditemukan di direktori kernel ini."
fi

echo "[+] ========================================"
echo "[+] Done. Patch Baseband Guard selesai diproses."
