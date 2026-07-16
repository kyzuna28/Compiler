#!/bin/bash
# ==========================================================================
# Patch Droidspaces for Kernel (Pure Bash Script)
# Merged and cleaned script - No Env Checking
# ==========================================================================

echo "[*] ========================================"
echo "[*] Memulai Patch Droidspaces"
echo "[*] ========================================"

# 1. Validasi Dependency (spatch) - Tetap diperlukan untuk Coccinelle
if ! command -v spatch &> /dev/null; then
    echo "[!] Error: Perintah 'spatch' (Coccinelle) tidak ditemukan."
    echo "    Install dulu dengan: sudo apt install coccinelle"
    exit 1
fi

# 2. Clone / Sinkronisasi Repository untuk ngambil file sumber
REPO_URL="https://github.com/kyzuna28/Compiler.git"
REPO_DIR="/tmp/Compiler_Repo"

if [ ! -d "$REPO_DIR" ]; then
    echo "[*] Mengunduh repository patch..."
    git clone --depth=1 "$REPO_URL" "$REPO_DIR" -q || { echo "[!] Error: Gagal clone repo."; exit 1; }
fi

# Auto-mencari file Droidspaces di Repo
CONFIG_SRC=$(find "$REPO_DIR" -type f -name "droidspaces.config" | head -n 1)
COCCI_CGROUP=$(find "$REPO_DIR" -type f -name "fix_restore_cgroup_file_prefix_handling.cocci" | head -n 1)
COCCI_XT=$(find "$REPO_DIR" -type f -name "fix_kernel_panic_in_xt_qtaguid.cocci" | head -n 1)

# 3. Cari defconfig yang sedang digunakan (Otomatis tanpa KERNEL_ARCH)
TARGET_CONFIG=$(grep -Rsl "^CONFIG_KSU=y" arch/*/configs 2>/dev/null | head -n1)

if [ -z "$TARGET_CONFIG" ]; then
    echo "Skip: Defconfig aktif tidak ditemukan (Pastikan dijalankan di dalam root folder kernel)."
    exit 0
fi

echo "[*] Using config: $TARGET_CONFIG"

# Tentukan folder tujuan (otomatis ngikutin path defconfig yang ketemu)
CONFIG_DEST=$(dirname "$TARGET_CONFIG")

# 4. Salin konfigurasi Droidspaces
if [ -n "$CONFIG_SRC" ] && [ -d "$CONFIG_DEST" ]; then
    cp "$CONFIG_SRC" "$CONFIG_DEST/"
    echo "  -> [OK] droidspaces.config berhasil disalin ke $CONFIG_DEST."
else
    echo "[!] Error: File config atau direktori tujuan tidak ditemukan."
    exit 1
fi

apply_cocci_patch() {
    local target_file="$1"
    local cocci_src="$2"
    
    [ -z "$cocci_src" ] || [ ! -f "$cocci_src" ] && return 1

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

echo "[*] Memulai eksekusi Coccinelle patch..."

# 5. Patch xt_qtaguid.c
if [ -f "net/netfilter/xt_qtaguid.c" ]; then
    apply_cocci_patch "net/netfilter/xt_qtaguid.c" "$COCCI_XT"
else
    echo "  -> [SKIP] net/netfilter/xt_qtaguid.c tidak ditemukan."
fi

# 6. Patch cgroup.c
CGROUP_FILE=""
if [ -f "kernel/cgroup/cgroup.c" ]; then
    CGROUP_FILE="kernel/cgroup/cgroup.c"
elif [ -f "kernel/cgroup.c" ]; then
    CGROUP_FILE="kernel/cgroup.c"
fi

if [ -n "$CGROUP_FILE" ]; then
    if ! grep -q "kernfs_create_link" "$CGROUP_FILE" 2>/dev/null; then
        apply_cocci_patch "$CGROUP_FILE" "$COCCI_CGROUP"
    else
        echo "  -> [SKIP] $CGROUP_FILE sudah ter-patch."
    fi
else
    echo "  -> [SKIP] File cgroup tidak ditemukan."
fi

echo "[+] Done: Patch Droidspaces terpasang."
echo "========================================"
