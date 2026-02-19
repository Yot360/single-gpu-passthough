#!/bin/bash
set -e

GPU="0000:0c:00.0"
GPU_AUDIO="0000:0c:00.1"

echo "Stopping graphical stack..."

killall Hyprland Xwayland 2>/dev/null || true

echo "Unbinding virtual consoles..."
for vt in /sys/class/vtconsole/vtcon*; do
  echo 0 > "$vt/bind" 2>/dev/null || true
done

echo $GPU > "/sys/bus/pci/devices/$GPU/driver/unbind"
echo $GPU_AUDIO > "/sys/bus/pci/devices/$GPU_AUDIO/driver/unbind"


echo "Unbinding EFI framebuffer..."
echo efi-framebuffer.0 > /sys/bus/platform/drivers/efi-framebuffer/unbind 2>/dev/null || true

echo "Unloading amdgpu..."
modprobe -r amdgpu

echo "Binding GPU to vfio-pci..."
echo vfio-pci > /sys/bus/pci/devices/$GPU/driver_override || true
echo vfio-pci > /sys/bus/pci/devices/$GPU_AUDIO/driver_override || true

echo $GPU > /sys/bus/pci/drivers_probe || true
echo $GPU_AUDIO > /sys/bus/pci/drivers_probe || true

echo "Done."
