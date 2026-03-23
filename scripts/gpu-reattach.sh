#!/bin/bash

GPU="0000:0c:00.0"
GPU_AUDIO="0000:0c:00.1"

log() { echo "[$(date +%H:%M:%S)] $*" | tee -a /tmp/gpu-reattach.log; }
fail() { log "FATAL: $*"; exit 1; }

log "=== START GPU REATTACH ==="

log "Killing lingering GPU-related processes..."
for proc in qemu qemu-system qemu-kvm Xwayland hyprland; do
    pkill -9 -f "$proc" 2>/dev/null && log "Killed $proc" || true
done
sleep 1

log "Unbinding from vfio-pci..."
echo $GPU       > /sys/bus/pci/devices/$GPU/driver/unbind       2>/dev/null || true
echo $GPU_AUDIO > /sys/bus/pci/devices/$GPU_AUDIO/driver/unbind 2>/dev/null || true
echo ""         > /sys/bus/pci/devices/$GPU/driver_override      2>/dev/null || true
echo ""         > /sys/bus/pci/devices/$GPU_AUDIO/driver_override 2>/dev/null || true

if lsmod | grep -q amdgpu; then
    log "amdgpu already loaded, checking refcnt..."
    REFCNT=$(cat /sys/module/amdgpu/refcnt 2>/dev/null || echo "?")
    log "amdgpu refcnt=$REFCNT"
    modprobe -r amdgpu 2>/dev/null && log "amdgpu unloaded" || log "WARNING: could not unload amdgpu (refcnt=$REFCNT), continuing anyway"
fi

log "PCIe function-level reset..."
echo 1 > /sys/bus/pci/devices/$GPU/reset       2>/dev/null || true
echo 1 > /sys/bus/pci/devices/$GPU_AUDIO/reset 2>/dev/null || true
sleep 1

log "Removing PCI devices..."
echo 1 > /sys/bus/pci/devices/$GPU_AUDIO/remove 2>/dev/null || true
echo 1 > /sys/bus/pci/devices/$GPU/remove       2>/dev/null || true
sleep 2

log "Cleaning debugfs..."
umount /sys/kernel/debug/dri 2>/dev/null || true
rm -rf /sys/kernel/debug/dri 2>/dev/null || true
umount /sys/kernel/debug     2>/dev/null || true
mount -t debugfs none /sys/kernel/debug 2>/dev/null || true
sleep 1

log "Syncing..."
sync
echo 3 > /proc/sys/vm/drop_caches
log "Suspending for GPU reset (8s)..."
rtcwake -m mem -s 4
log "Resumed from suspend."
sleep 3

log "Rescanning PCI bus..."
echo 1 > /sys/bus/pci/rescan
sleep 3

log "Waiting for GPU device..."
for i in {1..30}; do
    if [ -d "/sys/bus/pci/devices/$GPU" ]; then
        log "GPU found at iteration $i."
        break
    fi
    sleep 0.5
done
[ -d "/sys/bus/pci/devices/$GPU" ] || fail "GPU not found after rescan!"

CURRENT_DRIVER=$(readlink /sys/bus/pci/devices/$GPU/driver 2>/dev/null | xargs basename 2>/dev/null || echo "none")
log "Current GPU driver after rescan: $CURRENT_DRIVER"
if [ "$CURRENT_DRIVER" = "vfio-pci" ]; then
    log "GPU still on vfio-pci, unbinding again..."
    echo $GPU > /sys/bus/pci/devices/$GPU/driver/unbind 2>/dev/null || true
    echo "" > /sys/bus/pci/devices/$GPU/driver_override  2>/dev/null || true
    sleep 1
fi

rm -rf /sys/kernel/debug/dri 2>/dev/null || true
sleep 1

log "Loading amdgpu..."
modprobe amdgpu

if ! dmesg | tail -30 | grep -q "amdgpu.*probe"; then
    PROBE_ERR=$(dmesg | tail -30 | grep -i "error\|failed" | tail -5)
    log "WARNING: amdgpu probe uncertain. Recent errors: $PROBE_ERR"
fi

if [ ! -d "/dev/dri" ]; then
    log "ERROR: /dev/dri absent after modprobe! Dumping dmesg..."
    dmesg | grep -i "amdgpu\|drm\|error" | tail -20 | tee -a /tmp/gpu-reattach.log
    fail "/dev/dri not created — amdgpu probe failed"
fi
log "/dev/dri OK: $(ls /dev/dri)"

log "Rebinding EFI framebuffer..."
echo efi-framebuffer.0 > /sys/bus/platform/drivers/efi-framebuffer/bind 2>/dev/null || true
sleep 1

log "Rebinding virtual consoles..."
for vt in /sys/class/vtconsole/vtcon*; do
    [ -f "$vt/bind" ] && echo 1 > "$vt/bind" 2>/dev/null || true
done
