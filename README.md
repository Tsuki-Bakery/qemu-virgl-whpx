# QEMU with ANGLE-accelerated VirGL for Windows host

This project provides a Docker-based build system for cross-compiling QEMU for Windows x86_64 hosts with WHPX (Windows Hypervisor Platform) acclerator support, so is intended for use on Windows hosts with any Microsoft virtualization service enabled (WSL2, Virtualization-based Security, Hyper-V, etc.).

It enables 3D acclerated graphics for guests with ANGLE through VirGL so you don't need any further setup or configuration for GPU.

Due to limitation to WHPX accelerator, only x86_64 (amd64) guest is supported.

> [!IMPORTANT]
> This project is still very experimental and is not suitable for any production use.

## Download

Latest binaries build is offered at [Releases page](https://github.com/Tsuki-Bakery/qemu-virgl-whpx/releases) upon commit.

> [!IMPORTANT]
> Due to potential licensing problems, we can't include file d3dcompiler_47.dll (which is needed to compile Direct3D shaders for ANGLE) for now.

Find and copy `d3dcompiler_47.dll` file to the extracted binaries directory (same level as `qemu*.exe` files). You can find this DLL file in most Chromium web browsers binary directory, or from System32: 

```C:\Windows\System32\D3DCompiler_47.dll```

## Building

### Using Docker


Build the Docker image and load it into the local registry:
   ```bash
   # For most platforms (Linux, Windows, Intel Mac):
   docker build -t qemu-virgl-win-cross .
   ```

Extract the built files to your local machine:
   ```bash
   mkdir -p ./output
   docker run --rm -v "$(pwd)/output:/mnt/output" qemu-virgl-win-cross
   ```

> [!IMPORTANT]
> You will also need to find and copy `d3dcompiler_47.dll` file within `qemu*.exe` files as guided in [Download](#Download) section.

## Usage

### Requirements for host

Built binary is expected to work on Windows 11 at any version. No test were done on any Windows 10 host so far.

Make sure you have enabled [Windows Hypervisor Platform](https://developer.android.com/studio/run/emulator-acceleration#vm-windows-whpx) to utilize most virtualization performance, otherwise it's better to use Virtualbox or VMware Workstation/Player.

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

- `-m`: Memory (RAM) size.
- `-smp`: CPU core/threads count for guest.
- `-accel whpx,kernel-irqchip=off`: enable WHPX virtualization accelerator (Recommended).
- `-netdev user,id=anet0 -device virtio-net-pci,netdev=anet0`: enable Internet access for guest (Recommended).
- `-usb -device usb-tablet`: better mouse integration (Recommended).
- `-device intel-hda -device hda-duplex`: enable emulated sound device for playing guest audio to host.

### GNU/Linux guests

Linux guests have excellent 3D acceleration support with VirGL, often better than Windows guests. Modern Linux distributions already include the necessary VirtIO GPU drivers.

Install a Linux distribution:
   ```
    qemu-system-x86_64.exe `
    -M q35 `
    -m 4G `
    -smp 4 `
    -accel whpx,kernel-irqchip=off `
    -netdev user,id=anet0 -device virtio-net-pci,netdev=anet0 `
    -usb -device usb-tablet `
    -device intel-hda -device hda-duplex
    -cdrom ubuntu.iso `
    -drive file=.\ubuntu-disk.qcow2,if=virtio `
    -device virtio-vga-gl `
    -display sdl,gl=on
   ```
After installation, you can remove `-cdrom ubuntu.iso` option.

To verify 3D acceleration is working in your Linux guest:
```bash
glxinfo | grep "OpenGL renderer"
```
The output should show "virgl" along with GPU identical to your host GPU as the renderer.

For optimal Linux guest experience:
- Use Ubuntu 20.04 or newer, Fedora 34+, or any recent distro with kernel 5.10+.
- The Mesa drivers in these distributions have excellent VirtIO support.
- 3D applications and desktop environments will automatically use hardware acceleration without further configuration.

### Windows guests

> [!CAUTION]
> Windows guest support is considered very immature at the meantime.
> The following guide is quick start guide for participating developers and some notes what we have done and learned so far.

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
> Remove `-device virtio-vga-gl` from launch options until you have installed all VirtIO drivers and guest tools after OOBE setup.

> [!TIP]
> You can potentially improve disk I/O performance by replacing `-hda windows-disk.qcow2` with `-drive file=.\windows-disk.qcow2,if=virtio` and load drivers from `<virtio-win-disk>:\amd64\<your-windows-version>`.

After installation, you can remove `-cdrom windows.iso` option and run `virtio-win-guest-tools.exe` installation file in VirtIO drivers ISO file.

## How to Contribute

Feel free to open or participate in project discussions on [the issues page](https://github.com/Tsuki-Bakery/qemu-virgl-whpx/issues).

You may clone this repository, improve it and create a merge request, or help us to review them at [Pull requests](https://github.com/Tsuki-Bakery/qemu-virgl-whpx/pulls).

You can also join us to talk around this project on our [Telegram chat room](https://t.me/+Fo64cxKTGnNlZDhl).

## Credits

Original [work](https://github.com/matthias-prangl/qemu-virgl-winhost) from [matthias-prangl](https://github.com/matthias-prangl).