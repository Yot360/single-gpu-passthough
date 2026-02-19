# single-gpu-passthough
 My custom personal scrips for single AMD GPU passthrough with vendor reset bug fix

## My sytstem
Those script are specific to my system but easily modifiable.  
I'm on Hyprland, no Display Manager, starting it from TTY at login.  
I use Gentoo with OpenRC and a custom kernel.  
My GPU is an RX 6650 XT with vendor reset bug (which I fixed by suspending system).  
I also passthrough all my disks to the VM, so I made a module that mounts/unmounts them as needed.  

## Editing
All scripts are pretty self explanatory so if you want to edit them and use them on your system, go for it.
 
## Installation
- Install OpenRC modules (do not set the libvirt one as autostart)
- Copy hooks folder to `/etc/libvirt/`
- Copy each script to /usr/local/bin
- Make qemu, gpu-detach.sh, gpu-reattach.sh executable

## Resources used
[Risingprism's guide](https://gitlab.com/risingprismtv/single-gpu-passthrough)  
[akshaycodes's suspend method](https://gitlab.com/akshaycodes/vfio-script)
