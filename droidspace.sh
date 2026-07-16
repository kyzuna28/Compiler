#!/bin/bash
# ==========================================================================
# Patch Droidspaces for Kernel (Final Pro Version - Auto Search GitHub)
# ==========================================================================

echo "[*] ========================================"
echo "[*] Memulai Patch Droidspaces"
echo "[*] ========================================"

# 1. Cek status aktivasi
if [[ "${DROIDSPACES_ENABLE}" != "true" ]]; then
    echo "[-] Skip: DROIDSPACES_ENABLE tidak diatur ke 'true'."
    exit 0
fi

# 2. Validasi Variabel Environment Wajib
for var in GITHUB_WORKSPACE KERNEL_ARCH; do
    if [[ -z "${!var}" ]]; then
        echo "[!] Error: Variabel environment \$${var} belum diatur!"
        exit 1
    fi
done

# 3. Validasi Dependency (spatch)
if ! command -v spatch &> /dev/null; then
    echo "[!] Error: Perintah 'spatch' (Coccinelle) tidak ditemukan."
    exit 1
fi

# 4. Clone / Sinkronisasi Repository Compiler
REPO_URL="https://github.com/kyzuna28/Compiler.git"
REPO_DIR="/tmp/Compiler_Repo"

echo "[*] Menyiapkan repository sumber patch dari kyzuna28/Compiler..."
if [[ ! -d "$REPO_DIR" ]]; then
    if ! git clone --depth=1 "$REPO_URL" "$REPO_DIR" -q; then
        echo "[!] Error: Gagal melakukan clone repository $REPO_URL"
        exit 1
    fi
else
    echo "  -> [OK] Menggunakan cache repository di $REPO_DIR"
fi

# 5. Auto-mencari file Droidspaces di Repo
echo "[*] Auto-mencari file Droidspaces di repository..."
CONFIG_SRC=$(find "$REPO_DIR" -type f -name "droidspaces.config" | head -n 1)
COCCI_CGROUP=$(find "$REPO_DIR" -type f -name "fix_restore_cgroup_file_prefix_handling.cocci" | head -n 1)
COCCI_XT=$(find "$REPO_DIR" -type f -name "fix_kernel_panic_in_xt_qtaguid.cocci" | head -n 1)

# 6. Pindah dan cek direktori kernel
TARGET_DIR="${GITHUB_WORKSPACE}/device_kernel"
if [[ ! -d "$TARGET_DIR" ]]; then
    echo "[!] Error: Direktori kernel $TARGET_DIR tidak ditemukan."
    exit 1
fi

cd "$TARGET_DIR" || exit 1

# 7. Cek Konflik SuSFS
if [[ "${SUSFS_ENABLE}" == "true" ]]; then
    echo "[!] WARNING: Terdeteksi SuSFS aktif! Droidspaces mungkin akan berjalan tidak normal."
fi

# 8. Salin konfigurasi Droidspaces
if [[ -z "$CONFIG_SRC" ]]; then
    echo "[!] Error: File droidspaces.config tidak ditemukan di repository."
    exit 1
fi

CONFIG_DEST="./arch/${KERNEL_ARCH}/configs/"
if [[ -d "$CONFIG_DEST" ]]; then
    cp "$CONFIG_SRC" "$CONFIG_DEST"
    echo "  -> [OK] Config: droidspaces.config berhasil disalin ke $CONFIG_DEST"
else
    echo "[!] Error: Direktori konfigurasi arsitektur ($CONFIG_DEST) tidak ditemukan."
    exit 1
fi

# ==========================================================================
# PROSES PATCHING FILE
# ==========================================================================

apply_cocci_patch() {
    local target_file="$1"
    local cocci_src="$2"
    
    if [[ -z "$cocci_src" || ! -f "$cocci_src" ]]; then
        echo "  [-] Error: File script coccinelle tidak ditemukan di repository."
        return 1
    fi

    local cocci_name=$(basename "$cocci_src")
    cp "$cocci_src" "./$cocci_name"
    
    if spatch --sp-file "$cocci_name" --in-place "$target_file" &> /dev/null; then
        echo "  -> [OK] Patched: $target_file berhasil di-patch."
        rm -f "$cocci_name"
        return 0
    else
        echo "  [-] Error: Gagal mengeksekusi spatch pada $target_file"
        rm -f "$cocci_name"
        return 1
    fi
}

# 9. Jalankan Patch xt_qtaguid.c
if [[ -f "net/netfilter/xt_qtaguid.c" ]]; then
    apply_cocci_patch "net/netfilter/xt_qtaguid.c" "$COCCI_XT"
else
    echo "  -> [SKIP] net/netfilter/xt_qtaguid.c tidak ditemukan."
fi

# 10. Jalankan Patch cgroup.c
CGROUP_FILE=""
if [[ -f "kernel/cgroup/cgroup.c" ]]; then
    CGROUP_FILE="kernel/cgroup/cgroup.c"
elif [[ -f "kernel/cgroup.c" ]]; then
    CGROUP_FILE="kernel/cgroup.c"
fi

if [[ -n "$CGROUP_FILE" ]]; then
    if ! grep -q "kernfs_create_link" "$CGROUP_FILE" 2>/dev/null; then
        apply_cocci_patch "$CGROUP_FILE" "$COCCI_CGROUP"
    else
        echo "  -> [SKIP] $CGROUP_FILE sudah ter-patch."
    fi
else
    echo "  -> [SKIP] File cgroup.c tidak ditemukan di path manapun."
fi

echo "[+] Done: Patch Droidspaces selesai dieksekusi dengan sukses."
echo "========================================"
