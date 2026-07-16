#!/bin/bash
# ==========================================================================
# Patch Baseband Guard for Kernel (Final Pro Version)
# ==========================================================================

echo "[*] ========================================"
echo "[*] Memulai Patch Baseband Guard"
echo "[*] ========================================"

# 1. Cek status aktivasi
if [[ "${BASEBAND_GUARD_ENABLE}" != "true" ]]; then
    echo "[-] Skip: BASEBAND_GUARD_ENABLE tidak diatur ke 'true'."
    exit 0
fi

# 2. Validasi Variabel Environment Wajib
for var in GITHUB_WORKSPACE KERNEL_ARCH DEFCONFIG_NAME; do
    if [[ -z "${!var}" ]]; then
        echo "[!] Error: Variabel environment \$${var} belum diatur!"
        exit 1
    fi
done

# 3. Validasi Dependency
if ! command -v wget &> /dev/null; then
    echo "[!] Error: Perintah 'wget' tidak ditemukan. Harap install terlebih dahulu."
    exit 1
fi

# 4. Pindah dan cek direktori kernel
TARGET_DIR="${GITHUB_WORKSPACE}/device_kernel"
if [[ ! -d "$TARGET_DIR" ]]; then
    echo "[!] Error: Direktori kernel $TARGET_DIR tidak ditemukan."
    exit 1
fi

cd "$TARGET_DIR" || exit 1

# 5. Setup Variabel Path Defconfig
DEFCONFIG_PATH="./arch/${KERNEL_ARCH}/configs/${DEFCONFIG_NAME}"
if [[ ! -f "$DEFCONFIG_PATH" ]]; then
    echo "[!] Error: Defconfig aktif ($DEFCONFIG_PATH) tidak ditemukan."
    exit 1
fi

echo "[*] Menggunakan defconfig: $DEFCONFIG_PATH"

# 6. Unduh dan eksekusi Baseband Guard setup
echo "[*] Mengunduh dan mengeksekusi Baseband Guard setup..."
if ! wget -qO- https://github.com/vc-teahouse/Baseband-guard/raw/main/setup.sh | bash; then
    echo "[!] Error: Gagal mengunduh atau menjalankan setup script Baseband Guard."
    exit 1
fi

# 7. Patch CONFIG_BBG
if ! grep -q "^CONFIG_BBG=y" "$DEFCONFIG_PATH"; then
    echo "CONFIG_BBG=y" >> "$DEFCONFIG_PATH"
    echo "  -> [OK] Added: CONFIG_BBG=y"
else
    echo "  -> [SKIP] CONFIG_BBG=y sudah ada."
fi

# 8. Patch CONFIG_BBG_BLOCK_BOOT (jika diaktifkan)
if [[ "${BASEBAND_GUARD_BOOT}" == "true" ]]; then
    if ! grep -q "^CONFIG_BBG_BLOCK_BOOT=y" "$DEFCONFIG_PATH"; then
        echo "CONFIG_BBG_BLOCK_BOOT=y" >> "$DEFCONFIG_PATH"
        echo "  -> [OK] Added: CONFIG_BBG_BLOCK_BOOT=y"
    else
        echo "  -> [SKIP] CONFIG_BBG_BLOCK_BOOT=y sudah ada."
    fi
fi

# 9. Pengecekan dan Patch LSM Hooks
if ! grep -q "DEFINE_LSM" "include/linux/lsm_hooks.h" 2>/dev/null; then
    echo "  -> [SKIP] DEFINE_LSM tidak ditemukan pada LSM hooks, modifikasi LSM diabaikan."
else
    if grep -q "baseband_guard" "$DEFCONFIG_PATH"; then
        echo "  -> [SKIP] baseband_guard sudah terdaftar di dalam CONFIG_LSM."
    else
        echo "[*] Mendeteksi DEFINE_LSM, memproses konfigurasi LSM..."
        
        if grep -rq "^CONFIG_LSM=" "$DEFCONFIG_PATH"; then
            sed -i 's/\(CONFIG_LSM="[^"]*\)"/\1,baseband_guard"/' "$DEFCONFIG_PATH"
            echo "  -> [OK] CONFIG_LSM diupdate dengan baseband_guard."
        else
            if grep -q "bpf" "./security/Kconfig" 2>/dev/null; then
                echo 'CONFIG_LSM="lockdown,yama,loadpin,safesetid,integrity,selinux,smack,tomoyo,apparmor,bpf,baseband_guard"' >> "$DEFCONFIG_PATH"
                echo "  -> [OK] Ditambahkan: Default CONFIG_LSM (termasuk bpf & baseband_guard)"
            else
                echo 'CONFIG_LSM="lockdown,yama,loadpin,safesetid,integrity,selinux,smack,tomoyo,apparmor,baseband_guard"' >> "$DEFCONFIG_PATH"
                echo "  -> [OK] Ditambahkan: Default CONFIG_LSM (dengan baseband_guard)"
            fi
        fi
    fi
fi

echo "[+] Done: Patch Baseband Guard selesai dieksekusi dengan sukses."
echo "========================================"
