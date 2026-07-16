#!/bin/bash
# ==========================================================================
# Patch Droidspaces for Kernel (Direct Install Version)
# ==========================================================================

echo "[*] ========================================"
echo "[*] Memulai Patch Droidspaces"
echo "[*] ========================================"

# Validasi Variabel Environment Wajib
for var in GITHUB_WORKSPACE KERNEL_ARCH; do
    if [[ -z "${!var}" ]]; then
        echo "[!] Error: Variabel environment \$${var} belum diatur!"
        exit 1
    fi
done

# Validasi Dependency (spatch)
if ! command -v spatch &> /dev/null; then
    echo "[!] Error: Perintah 'spatch' (Coccinelle) tidak ditemukan."
    exit 1
fi

# Clone / Sinkronisasi Repository
REPO_URL="https://github.com/kyzuna28/Compiler.git"
REPO_DIR="/tmp/Compiler_Repo"

if [[ ! -d "$REPO_DIR" ]]; then
    git clone --depth=1 "$REPO_URL" "$REPO_DIR" -q || exit 1
fi

# Auto-mencari file Droidspaces di Repo
echo "[*] Auto-mencari file sumber di repository..."
CONFIG_SRC=$(find "$REPO_DIR" -type f -name "droidspaces.config" | head -n 1)
COCCI_CGROUP=$(find "$REPO_DIR" -type f -name "fix_restore_cgroup_file_prefix_handling.cocci" | head -n 1)
COCCI_XT=$(find "$REPO_DIR" -type f -name "fix_kernel_panic_in_xt_qtaguid.cocci" | head -n 1)

# Pindah ke direktori kernel
TARGET_DIR="${GITHUB_WORKSPACE}/device_kernel"
cd "$TARGET_DIR" || exit 1

# Cek Konflik SuSFS
if [[ "${SUSFS_ENABLE}" == "true" ]]; then
    echo "[!] WARNING: Terdeteksi SuSFS aktif! Droidspaces mungkin akan berjalan tidak normal."
fi

# Salin konfigurasi Droidspaces
CONFIG_DEST="./arch/${KERNEL_ARCH}/configs/"
if [[ -n "$CONFIG_SRC" && -d "$CONFIG_DEST" ]]; then
    cp "$CONFIG_SRC" "$CONFIG_DEST"
    echo "  -> [OK] droidspaces.config berhasil disalin."
else
    echo "[!] Error: File config atau direktori tujuan tidak ditemukan."
    exit 1
fi

apply_cocci_patch() {
    local target_file="$1"
    local cocci_src="$2"
    
    if [[ -z "$cocci_src" || ! -f "$cocci_src" ]]; then return 1; fi

    local cocci_name=$(basename "$cocci_src")
    cp "$cocci_src" "./$cocci_name"
    
    if spatch --sp-file "$cocci_name" --in-place "$target_file" &> /dev/null; then
        echo "  -> [OK] Patched: $target_file"
        rm -f "$cocci_name"
        return 0
    else
        echo "  [-] Error: Gagal spatch pada $target_file"
        rm -f "$cocci_name"
        return 1
    fi
}

# Patch xt_qtaguid.c
if [[ -f "net/netfilter/xt_qtaguid.c" ]]; then
    apply_cocci_patch "net/netfilter/xt_qtaguid.c" "$COCCI_XT"
fi

# Patch cgroup.c
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
fi

echo "[+] Done: Patch Droidspaces terpasang."
echo "========================================"
