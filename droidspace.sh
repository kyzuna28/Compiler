#!/bin/bash
# ==========================================================================
# Patch Droidspaces for Kernel
# Pro Version - Workflow Optimized (Auto-Install spatch)
# ==========================================================================

echo "[*] ========================================"
echo "[*] Memulai Patch Droidspaces"
echo "[*] ========================================"

# Auto-Install Dependency (Coccinelle)
if ! command -v spatch &> /dev/null; then
    echo "[*] 'spatch' tidak ditemukan. Menginstal Coccinelle..."
    sudo apt-get update -y > /dev/null 2>&1
    sudo apt-get install --no-install-recommends -y coccinelle > /dev/null 2>&1
    
    if ! command -v spatch &> /dev/null; then
        echo "[!] Error: Gagal menginstal Coccinelle! Hentikan proses."
        exit 1
    else
        echo "  -> [OK] Coccinelle terinstal."
    fi
fi

if [ -z "$TARGET_CONFIG" ] || [ ! -f "$TARGET_CONFIG" ]; then
    echo "[!] Error: Variabel TARGET_CONFIG tidak valid!"
    exit 1
fi

REPO_URL="https://github.com/kyzuna28/Compiler.git"
REPO_DIR="/tmp/Compiler_Repo"

if [ ! -d "$REPO_DIR" ]; then
    git clone --depth=1 "$REPO_URL" "$REPO_DIR" -q || { echo "[!] Error: Gagal clone repo patch."; exit 1; }
fi

CONFIG_SRC=$(find "$REPO_DIR" -type f -name "droidspaces.config" | head -n 1)
COCCI_CGROUP=$(find "$REPO_DIR" -type f -name "fix_restore_cgroup_file_prefix_handling.cocci" | head -n 1)
COCCI_XT=$(find "$REPO_DIR" -type f -name "fix_kernel_panic_in_xt_qtaguid.cocci" | head -n 1)

CONFIG_DEST=$(dirname "$TARGET_CONFIG")

if [ -n "$CONFIG_SRC" ] && [ -d "$CONFIG_DEST" ]; then
    cp "$CONFIG_SRC" "$CONFIG_DEST/"
    echo "  -> [OK] droidspaces.config disalin ke $CONFIG_DEST"
else
    echo "[!] Error: File config Droidspaces tidak ditemukan."
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

# 1. Patch xt_qtaguid.c
if [ -f "net/netfilter/xt_qtaguid.c" ]; then
    apply_cocci_patch "net/netfilter/xt_qtaguid.c" "$COCCI_XT"
fi

# 2. Patch cgroup.c
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
fi

echo "[+] Done: Patch Droidspaces terpasang."
