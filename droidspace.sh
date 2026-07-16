#!/bin/bash
# ==========================================================================
# Patch Droidspaces for Kernel
# Ultra Pro Version - Full Exhaustive Check & Detailed Logging
# ==========================================================================

echo "[*] ========================================"
echo "[*] Memulai Patch Droidspaces"
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

# Validasi akhir eksistensi defconfig
if [ -z "$TARGET_CONFIG" ] || [ ! -f "$TARGET_CONFIG" ]; then
    echo "[!] Error: Defconfig aktif tidak valid atau file tidak ditemukan! Proses berhenti."
    exit 1
else
    echo "  -> [OK] Defconfig tervalidasi dan siap digunakan."
fi

# 2. Pengecekan & Instalasi spatch (Coccinelle)
echo "[*] Mengecek dependensi: spatch (Coccinelle)..."
if ! command -v spatch &> /dev/null; then
    echo "  [-] 'spatch' tidak ditemukan. Memulai instalasi otomatis..."
    sudo apt-get update -y > /dev/null 2>&1
    sudo apt-get install --no-install-recommends -y coccinelle > /dev/null 2>&1
    
    # Verifikasi ulang pasca instalasi
    if ! command -v spatch &> /dev/null; then
        echo "[!] Error: Gagal menginstal Coccinelle! Hentikan proses."
        exit 1
    else
        echo "  -> [OK] Coccinelle berhasil diinstal."
    fi
else
    echo "  -> [OK] 'spatch' sudah terinstal di sistem."
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

# Mencari file yang dibutuhkan di dalam repo
CONFIG_SRC=$(find "$REPO_DIR" -type f -name "droidspaces.config" | head -n 1)
COCCI_CGROUP=$(find "$REPO_DIR" -type f -name "fix_restore_cgroup_file_prefix_handling.cocci" | head -n 1)
COCCI_XT=$(find "$REPO_DIR" -type f -name "fix_kernel_panic_in_xt_qtaguid.cocci" | head -n 1)

CONFIG_DEST=$(dirname "$TARGET_CONFIG")

# 4. Salin Konfigurasi Droidspaces
echo "[*] Memproses droidspaces.config..."
if [ -n "$CONFIG_SRC" ] && [ -f "$CONFIG_SRC" ]; then
    if [ -d "$CONFIG_DEST" ]; then
        cp "$CONFIG_SRC" "$CONFIG_DEST/"
        echo "  -> [OK] droidspaces.config berhasil disalin ke $CONFIG_DEST/"
    else
        echo "[!] Error: Direktori tujuan defconfig ($CONFIG_DEST) tidak ditemukan."
        exit 1
    fi
else
    echo "[!] Error: File droidspaces.config tidak ditemukan di dalam repositori clone."
    exit 1
fi

# Fungsi eksekusi spatch dengan log mendetail
apply_cocci_patch() {
    local target_file="$1"
    local cocci_src="$2"
    
    if [ -z "$cocci_src" ] || [ ! -f "$cocci_src" ]; then
        echo "  [-] Error: Skema cocci untuk patch ini tidak valid atau hilang."
        return 1
    fi

    local cocci_name=$(basename "$cocci_src")
    cp "$cocci_src" "./$cocci_name"
    
    echo "  [*] Menjalankan spatch pada: $target_file..."
    if spatch --sp-file "$cocci_name" --in-place "$target_file" &> /dev/null; then
        echo "  -> [OK] Patch berhasil diterapkan pada: $target_file"
        rm -f "$cocci_name"
        return 0
    else
        echo "  [-] Error: Gagal spatch pada $target_file. Kemungkinan kode tidak kompatibel."
        rm -f "$cocci_name"
        return 1
    fi
}

echo "[*] ========================================"
echo "[*] Menerapkan Patch C (Coccinelle)"
echo "[*] ========================================"

# 5. Patch xt_qtaguid.c
echo "[*] Memeriksa eksistensi xt_qtaguid.c..."
if [ -f "net/netfilter/xt_qtaguid.c" ]; then
    apply_cocci_patch "net/netfilter/xt_qtaguid.c" "$COCCI_XT"
else
    echo "  -> Skip: net/netfilter/xt_qtaguid.c tidak ditemukan pada tree kernel ini."
fi

# 6. Patch cgroup.c
echo "[*] Memeriksa eksistensi file cgroup..."
CGROUP_FILE=""
if [ -f "kernel/cgroup/cgroup.c" ]; then
    CGROUP_FILE="kernel/cgroup/cgroup.c"
    echo "  -> [OK] Ditemukan: kernel/cgroup/cgroup.c"
elif [ -f "kernel/cgroup.c" ]; then
    CGROUP_FILE="kernel/cgroup.c"
    echo "  -> [OK] Ditemukan: kernel/cgroup.c"
else
    echo "  [-] Info: File cgroup.c sama sekali tidak ditemukan."
fi

if [ -n "$CGROUP_FILE" ]; then
    echo "[*] Mengecek status patch cgroup..."
    if ! grep -q "kernfs_create_link" "$CGROUP_FILE" 2>/dev/null; then
        echo "  [*] kernfs_create_link belum ada, menerapkan patch..."
        apply_cocci_patch "$CGROUP_FILE" "$COCCI_CGROUP"
    else
        echo "  -> Skip: $CGROUP_FILE sudah mengandung kernfs_create_link (sudah ter-patch)."
    fi
else
    echo "  -> Skip: Proses patch cgroup dibatalkan karena file tidak ada."
fi

echo "[+] ========================================"
echo "[+] Done. Patch Droidspaces selesai diproses."
