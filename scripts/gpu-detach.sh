#!/bin/bash
GPU="0000:0c:00.0"
GPU_AUDIO="0000:0c:00.1"

echo "Killing graphical stack..."
killall Hyprland Xwayland 2>/dev/null || true
sleep 1
lsof /dev/dri/* 2>/dev/null | awk 'NR>1 {print $2}' | sort -u | xargs -r kill -9
sleep 1

echo "Unbinding EFI framebuffer FIRST..."
echo efi-framebuffer.0 > /sys/bus/platform/drivers/efi-framebuffer/unbind 2>/dev/null || true
sleep 1

echo "Unbinding vtconsoles..."
for vt in /sys/class/vtconsole/vtcon*; do
    echo 0 > "$vt/bind" 2>/dev/null || true
    echo "$vt = $(cat $vt/bind)"
done
sleep 1

echo "Unbinding PCI devices..."
echo $GPU       > /sys/bus/pci/devices/$GPU/driver/unbind
echo $GPU_AUDIO > /sys/bus/pci/devices/$GPU_AUDIO/driver/unbind
sleep 1

echo "Unloading amdgpu..."
modprobe -r amdgpu || { echo "FATAL: amdgpu still in use"; cat /sys/module/amdgpu/refcnt; exit 1; }

echo "Binding vfio-pci..."
echo vfio-pci > /sys/bus/pci/devices/$GPU/driver_override
echo vfio-pci > /sys/bus/pci/devices/$GPU_AUDIO/driver_override
echo $GPU       > /sys/bus/pci/drivers_probe
echo $GPU_AUDIO > /sys/bus/pci/drivers_probe

echo "Done."

