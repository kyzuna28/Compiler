#!/bin/bash
# ==========================================================================
# Patch ReKernel for Kernel
# Ultra Pro Version - Full Exhaustive Check & Detailed Logging
# ==========================================================================

echo "[*] ========================================"
echo "[*] Memulai Patch ReKernel"
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

# 2. Cek apakah sudah ter-patch sebelumnya
echo "[*] Memeriksa status CONFIG_REKERNEL..."
if grep -q "^CONFIG_REKERNEL=y" "$TARGET_CONFIG"; then
    echo "  -> Skip: CONFIG_REKERNEL=y sudah tertanam di defconfig."
    echo "[+] Done. Patch ReKernel selesai tanpa perubahan tambahan."
    exit 0
else
    echo "  -> [OK] CONFIG_REKERNEL belum terpasang. Melanjutkan proses..."
fi

# 3. Persiapan Repositori Patch
REPO_URL="https://github.com/kyzuna28/Compiler.git"
REPO_DIR="/tmp/Compiler_Repo"

echo "[*] Mengecek repositori patch di $REPO_DIR..."
if [ ! -d "$REPO_DIR" ]; then
    echo "  [-] Direktori belum ada. Memulai proses clone..."
    if git clone --depth=1 "$REPO_URL" "$REPO_DIR" -q; then
        echo "  -> [OK] Berhasil clone repositori patch."
    else
        echo "[!] Error: Gagal clone repositori patch! Periksa koneksi internet."
        exit 1
    fi
else
    echo "  -> [OK] Repositori patch sudah tersedia di cache sementara."
fi

# Mencari file spesifik ReKernel
REKERNEL_SH=$(find "$REPO_DIR" -type f -name "rekernel_patches.sh" | head -n 1)
REKERNEL_PATCH=$(find "$REPO_DIR" -type f -name "rekernel_extra.patch" | head -n 1)

# 4. Eksekusi Script Internal ReKernel
echo "[*] Memeriksa script eksekutor rekernel_patches.sh..."
if [ -n "$REKERNEL_SH" ] && [ -f "$REKERNEL_SH" ]; then
    echo "  -> [OK] Ditemukan $(basename "$REKERNEL_SH"). Mengeksekusi..."
    cp "$REKERNEL_SH" ./
    if bash "./$(basename "$REKERNEL_SH")"; then
        echo "  -> [OK] Eksekusi rekernel_patches.sh berhasil."
    else
        echo "  [-] Warning: Eksekusi rekernel_patches.sh mengembalikan error (mungkin tidak kompatibel penuh)."
    fi
    rm -f "./$(basename "$REKERNEL_SH")"
else
    echo "[!] Error: Script rekernel_patches.sh tidak ditemukan di dalam repositori!"
    exit 1
fi

# 5. Terapkan Patch Ekstra ReKernel (.patch)
echo "[*] Memeriksa file diff rekernel_extra.patch..."
if [ -n "$REKERNEL_PATCH" ] && [ -f "$REKERNEL_PATCH" ]; then
    echo "  -> [OK] Ditemukan $(basename "$REKERNEL_PATCH"). Menerapkan patch..."
    
    # Pastikan folder target ada
    if [ ! -d "drivers/rekernel" ]; then
        mkdir -p drivers/rekernel
        echo "  [*] Info: Membuat direktori drivers/rekernel..."
    fi
    
    cp "$REKERNEL_PATCH" ./
    if patch -p1 < "./$(basename "$REKERNEL_PATCH")" > /dev/null 2>&1; then
        echo "  -> [OK] Patch $(basename "$REKERNEL_PATCH") sukses diterapkan."
    else
        echo "  [-] Warning: Gagal menerapkan patch (sebagian/keseluruhan sudah di-patch atau beda versi kernel)."
    fi
    rm -f "./$(basename "$REKERNEL_PATCH")"
else
    echo "  [-] Skip: File rekernel_extra.patch tidak ditemukan. Melewati langkah ini."
fi

# 6. Update Defconfig
echo "[*] Memperbarui file defconfig..."
if echo "CONFIG_REKERNEL=y" >> "$TARGET_CONFIG"; then
    echo "  -> [OK] Added: CONFIG_REKERNEL=y ditambahkan ke $TARGET_CONFIG"
else
    echo "  [-] Error: Gagal menulis ke file $TARGET_CONFIG"
    exit 1
fi

echo "[+] ========================================"
echo "[+] Done. Patch ReKernel selesai diproses."
