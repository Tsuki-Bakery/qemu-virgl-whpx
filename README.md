# QEMU with ANGLE-accelerated VirGL for Windows host

> [!CAUTION]
> This project is still very experimental and is not suitable for any production use.

This project provides a Docker-based build system for cross-compiling QEMU for Windows x86_64 hosts with WHPX (Windows Hypervisor Platform) accelerator support, so is intended for use on Windows hosts with any Microsoft virtualization service enabled (WSL2, Virtualization-based Security, Hyper-V, etc.).

It enables 3D acclerated graphics for guests with ANGLE through VirGL so you don't need any further setup or configuration for GPU.

Due to limitation to WHPX accelerator, only x86_64 (amd64) guest is supported.

## Download

Latest binaries build is offered at [Releases page](https://github.com/Tsuki-Bakery/qemu-virgl-whpx/releases) upon commit.

## Building

### Using Docker

Build the Docker image and load it into the local registry:
   ```bash
   # For most platforms (Linux, Windows, Intel Mac):
   docker build -t qemu-virgl-whpx .
   ```

Extract the built files to your local machine:
   ```bash
   mkdir -p ./output
   docker run --rm -v "$(pwd)/output:/mnt/output" qemu-virgl-whpx
   ```

## Usage

### Requirements for host

Built binary is expected to work on Windows 11 at any version. No test were done on any Windows 10 host so far.

Make sure you have enabled [Windows Hypervisor Platform](https://developer.android.com/studio/run/emulator-acceleration#vm-windows-whpx) to utilize most virtualization performance, otherwise it's much better to use Virtualbox or VMWare Workstation/Player.

For working shell, you should use [Powershell](https://github.com/powershell/powershell/releases) 7.0 and later to prevent older Powershell crash when QEMU fails.

### Create a disk image

You should create a disk image for persistence data storage:

   ```
   # Set disk size and shouldn't bigger than physical drive size
   # Disk image will only take space when data actually written
   .\output\qemu-img.exe create -f qcow2 vm-disk.qcow2 64G
   ```
Preferably create a new folder per guest for easier management.

### Launch options

We suggest the following launch options for most of the time with decently new hardware:

```powershell
qemu-system-x86_64.exe `
-accel whpx,kernel-irqchip=off `
-serial mon:stdio `
-usb -device usb-tablet `
-M q35 `
-m 8G ` 
-device virtio-vga-gl -display sdl,gl=on `
-netdev user,id=anet0 -device virtio-net-pci,netdev=anet0 `
-device intel-hda -device hda-duplex `
-drive file=linux.qcow2,if=virtio `
-cdrom linux.iso `
-bios path\to\qemu\share\edk2\x64\OVMF.4m.fd ` 
-smp sockets=1,cores=8,threads=2 ` 
-cpu qemu64,+sse4.2,+sse4.1,+aes,+avx,+ssse3,+x2apic,+sse,+sse2,+xsave,+acpi,+mmxext,+pdpe1gb,+rdtscp,+pclmulqdq,+cx16,+movbe,+popcnt,+rdrand
```
### Explanation

- `-accel whpx,kernel-irqchip=off`: enable WHPX virtualization accelerator (Recommended).
- `-serial mon:stdio`: Monitor OS serial to stdio if available.
- `-M q35`: set chipset emulation to q35. Must include and don't change unless you try to emulate old Windows guests like XP and older.
- `-m 8G`: set memory (to 8GB), change this to suit your preferences.
- `-device virtio-vga-gl -display sdl,gl=on `: Use VirGLrenderer with 3D OpenGL acceleration enabled. (Recommended).
   - Turn off acceleration by removing `-device virtio-vga-gl` and `,gl=on` if you get black screen. Usually on SeaBIOS before booting an OS.
   - You can use `-display gtk` however 3D acceleration won't be available.
- `-smp`: CPU core/threads count for guest. 
    - You can simply set `-smp 8` to emulate 8 cores CPU to guest. 
    - Alternatively, if you want it 8 cores, 16 threads, then `-smp sockets=1,cores=8,threads=2` like above. 
    - For AMD Ryzen users, add `+topoext` to `-cpu` options to allow multithreading and utilize most performance.
- `-cpu`: advanced CPU options. 
    - Suggested list of instruction flags above is ideal for x86_64-v3 microarch level, which is Ryzen Zen 2/Intel Broadwell and above (mostly CPU made in 2015) and later.
    - If you use older CPU, consult [microarchitecture levels](https://en.wikipedia.org/wiki/X86-64#Microarchitecture_levels) and `qemu-system-x86_64.exe -cpu help` to find those suits your CPU. Note that `host` and `host-passthrough` options are **not** available on Windows builds of QEMU.
    - Leaving `-cpu` option unset will likely result kernel panic for most of the time, very poor performance for Android-x86 guests, or unable to load many kernel modules like zfs.
- `-netdev user,id=anet0 -device virtio-net-pci,netdev=anet0`: enable (userspace) Internet access for guest (Recommended).
- `-usb -device usb-tablet`: seamless mouse grabbing better mouse integration (Recommended). 
    - For some games that grab mouse i.e. Minecraft, it's better to remove this option and let QEMU totally capture the mouse when you click on guest window (Ctrl+Alt+G to uncapture) and turn off "Mouse acceleration" in guest settings (if available) to reduce mouse janking and drifting.
- `-device intel-hda -device hda-duplex`: emulate sound device for playing guest audio to host.
- `-bios path\to\qemu\share\edk2\x64\OVMF.4m.fd`: use EDK2 OVMF (Open Virtual Machine Firmware) to start guest in UEFI. (Recommended)

To verify 3D acceleration is working in your Linux guest:
```bash
glxinfo | grep "OpenGL renderer"
```

The output should show "virgl" along with GPU identical to your host GPU as the renderer.

For optimal Linux guest experience:
- Use Ubuntu 20.04 or newer, Fedora 34+, or any recent distro with kernel 5.10+.
- The Mesa drivers in these distributions have excellent VirtIO and VirGL support.
- 3D applications and desktop environments will automatically use hardware acceleration without further configuration.

### Windows guests

> [!CAUTION]
> Windows guest support is considered very immature at the meantime.
> The following guide is quick start guide for participating developers and some notes what we have done and learned so far.

> [!TIP]
> It's just better to use Hyper-V Manager to make and use Windows virtual machines (for now).

What works:
- Windows 10 and below (testing was done with Windows 10 Enterprise IoT LTSC 2021).
- Basic 2D graphics via Red Hat VirtIO GPU DOD controller/QXL driver. Removing `-device virtio-vga-gl` and `,gl=on` improves performance.

What doesn't work:
- Windows 11 just crashes with error of `WHPX: Unexpected VP exit code 4`, we suspect it checks for nested virtualization (for Virtualization-based security). Being tracked on [this issue](https://gitlab.com/qemu-project/qemu/-/issues/2461).
- 3D accelerated graphics due to WIP VirtIO GPU driver.
- Restart ends up WHPX crashing of `WHPX: Unexpected VP exit code 4` as well. Shut down takes a while.

> [!NOTE]
> For Windows guests, you'll need VirtIO GPU drivers and guest helper from the [VirtIO drivers ISO](https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/). Keep it mounted as a `-cdrom` device helps your development a lot.

With ISO file for Windows setup installation:
   ```
    qemu-system-x86_64.exe `
    -M q35 `
    -m 4G `
    -smp 4 `
    -accel whpx`
    -netdev user,id=anet0 -device virtio-net-pci,netdev=anet0 `
    -device intel-hda -device hda-duplex
    -usb -device usb-tablet `
    -cdrom windows.iso `
    -hda windows-disk.qcow2 `
    -display sdl
   ```

> [!NOTE]
> Remove `-device virtio-vga-gl` from launch options until you have installed all VirtIO drivers and guest tools after OOBE setup. Otherwise you'll get black screen for most of the time.

> [!TIP]
> You can potentially improve disk I/O performance by replacing `-hda windows-disk.qcow2` with `-drive file=.\windows-disk.qcow2,if=virtio` and load drivers from `<virtio-win-disk>:\amd64\<your-windows-version>`.

After installation, you can remove `-cdrom windows.iso` option and run `virtio-win-guest-tools.exe` installation file in VirtIO drivers ISO file.

## How to Contribute

Feel free to open or participate in project discussions on [the issues page](https://github.com/Tsuki-Bakery/qemu-virgl-whpx/issues).

You may clone this repository, improve it and create a merge request, or help us to review them at [Pull requests](https://github.com/Tsuki-Bakery/qemu-virgl-whpx/pulls).

You can also join us to talk around this project on our [Telegram chat room](https://t.me/+Fo64cxKTGnNlZDhl).

## Credits

- Original [work](https://github.com/matthias-prangl/qemu-virgl-winhost) from [matthias-prangl](https://github.com/matthias-prangl).
- [Version bump and improvements](https://github.com/startergo/qemu-virgl-winhost) form [startergo](https://github.com/startergo).