#!/bin/bash
# ==========================================================================
# No-Kprobes SELinux Workaround (Pure Bash Script)
# Merged and cleaned script - 2026 (Mode Pro No Typo)
# ==========================================================================

patch_files=(
    security/selinux/selinuxfs.c
    security/selinux/ss/status.c
    security/selinux/hooks.c
)

echo "[*] Memulai pengecekan no-kprobe patch..."

# 1. KernelSU belum terpasang
if [ ! -d drivers/kernelsu ]; then
    echo "Skip: drivers/kernelsu tidak ditemukan."
    exit 0
fi

# 2. Fork tidak membutuhkan workaround (Static state check tidak ada)
if ! grep -qr "check_symbol_export" drivers/kernelsu/tools 2>/dev/null; then
    echo "Skip: Workaround tidak diperlukan untuk versi KernelSU ini."
    exit 0
fi

# 3. KALLSYMS aktif (Pengecekan global di seluruh config tanpa env var)
if grep -Rqs "^CONFIG_KALLSYMS=y" arch/*/configs 2>/dev/null \
&& grep -Rqs "^CONFIG_KALLSYMS_ALL=y" arch/*/configs 2>/dev/null; then
    echo "Skip: CONFIG_KALLSYMS_ALL sudah aktif di config."
    exit 0
fi

echo "[*] Syarat terpenuhi, menerapkan patch penghapusan static state..."

# 4. Looping Eksekusi Patch
for i in "${patch_files[@]}"; do
    # Jika file tidak ada, lewati ke file berikutnya
    [ -f "$i" ] || continue

    case "$i" in
    security/selinux/selinuxfs.c)

        grep -q "^const struct file_operations sel_handle_status_ops" "$i" || \
        sed -i 's/^static const struct file_operations sel_handle_status_ops = {/const struct file_operations sel_handle_status_ops = {/' "$i"

        grep -q "^DEFINE_MUTEX(sel_mutex)" "$i" || \
        sed -i 's/^static DEFINE_MUTEX(sel_mutex)/DEFINE_MUTEX(sel_mutex)/' "$i"

        grep -q "ssize_t (\*const write_op\[\])" "$i" || \
        sed -i 's/static ssize_t (\*const write_op\[\])/ssize_t (*const write_op[])/' "$i"

        grep -q "ssize_t (\*write_op\[\])" "$i" || \
        sed -i 's/static ssize_t (\*write_op\[\])/ssize_t (*write_op[])/' "$i"

        echo "  -> Patched: $i"
        ;;

    security/selinux/ss/status.c)

        grep -q "^struct page \*selinux_status_page" "$i" || \
        sed -i 's/^static struct page \*selinux_status_page/struct page *selinux_status_page/' "$i"

        grep -q "^DEFINE_MUTEX(selinux_status_lock)" "$i" || \
        sed -i 's/^static DEFINE_MUTEX(selinux_status_lock)/DEFINE_MUTEX(selinux_status_lock)/' "$i"

        echo "  -> Patched: $i"
        ;;

    security/selinux/hooks.c)

        grep -q "^struct security_operations selinux_ops" "$i" || \
        sed -i 's/^static struct security_operations selinux_ops/struct security_operations selinux_ops/' "$i"

        echo "  -> Patched: $i"
        ;;
    esac
done

echo "[+] Done. Patch selesai dieksekusi."
