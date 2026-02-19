#!/bin/bash
set -e

GPU="0000:0c:00.0"
GPU_AUDIO="0000:0c:00.1"

echo "Unbinding from vfio..."
echo $GPU > /sys/bus/pci/devices/$GPU/driver/unbind || true
echo $GPU_AUDIO > /sys/bus/pci/devices/$GPU_AUDIO/driver/unbind || true

echo "Clearing override..."
echo "" > /sys/bus/pci/devices/$GPU/driver_override || true
echo "" > /sys/bus/pci/devices/$GPU_AUDIO/driver_override || true

echo "Forcing PCIe reset..."
echo 1 > /sys/bus/pci/devices/$GPU/reset || true
echo 1 > /sys/bus/pci/devices/$GPU_AUDIO/reset || true

echo "Removing devices..."
echo 1 > /sys/bus/pci/devices/$GPU/remove 2>/dev/null || true
echo 1 > /sys/bus/pci/devices/$GPU_AUDIO/remove 2>/dev/null || true

sleep 1

echo "Suspending system to reset gpu..."
rtcwake -m mem -s 5

sleep 1

echo "Rescan PCI..."
echo 1 > /sys/bus/pci/rescan
sleep 1

echo "Reloading amdgpu..."
modprobe amdgpu

echo "Rebinding virtual consoles..."
for vt in /sys/class/vtconsole/vtcon*; do
    echo 1 > "$vt/bind" 2>/dev/null || true
done

echo "Done. Start Hyprland manually."
