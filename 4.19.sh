#!/bin/bash
# ==========================================================================
# Kbuild Min-Tool-Version Fixer (Pure Bash Script)
# Merged and cleaned script - 2026 (Mode Pro No Typo)
# ==========================================================================

set -e

echo "[*] Memulai inisialisasi Kbuild tool version script..."

# 1. Deteksi otomatis lokasi direktori scripts
if [ -d "kernel-dir/scripts" ]; then
    SCRIPTS_DIR="kernel-dir/scripts"
elif [ -d "scripts" ]; then
    SCRIPTS_DIR="scripts"
else
    echo "[-] Skip: Direktori 'scripts' tidak ditemukan. Pastikan eksekusi dari root kernel."
    exit 1
fi

TARGET_FILE="${SCRIPTS_DIR}/min-tool-version.sh"

echo "[*] Direktori scripts ditemukan di: ${SCRIPTS_DIR}"
echo "[*] Menyiapkan file ${TARGET_FILE}..."

# 2. Injeksi script min-tool-version.sh sesuai standar Linux 4.19
cat << 'EOF' > "$TARGET_FILE"
#!/bin/sh
# SPDX-License-Identifier: GPL-2.0
# Print the minimum supported version of the given tool.

if [ "$#" -ne 1 ]; then
	echo "usage: $0 toolname" >&2
	exit 1
fi

case "$1" in
binutils)
	echo 2.23.0
	;;
gcc)
	echo 5.1.0
	;;
llvm)
	echo 11.0.0
	;;
lld)
	echo 11.0.0
	;;
*)
	echo "$1: unknown tool" >&2
	exit 1
	;;
esac
EOF

# 3. Eksekusi Perbaikan Permission (Chmod)
echo "[*] Menyesuaikan izin eksekusi (+x) pada direktori scripts..."

chmod +x "$TARGET_FILE"
chmod +x "${SCRIPTS_DIR}"/*.sh 2>/dev/null || true

if [ -d "${SCRIPTS_DIR}/kconfig" ]; then
    chmod +x "${SCRIPTS_DIR}/kconfig"/*.sh 2>/dev/null || true
fi

# 4. Validasi Hasil (Dry-Run Test)
TEST_BINUTILS=$("$TARGET_FILE" binutils 2>/dev/null || true)

if [ "$TEST_BINUTILS" = "2.23.0" ]; then
    echo "  -> Patched & Verified: ${TARGET_FILE} (binutils=${TEST_BINUTILS})"
    echo "[+] Done. Patch Kbuild selesai dieksekusi tanpa error."
else
    echo "[-] Error: Gagal memvalidasi output skrip. Periksa sistem dasar container CI/CD."
    exit 1
fi

exit 0
