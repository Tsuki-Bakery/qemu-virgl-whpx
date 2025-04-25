# QEMU with ANGLE-accelerated VirGL for Windows

This project provides a Docker-based build system for cross-compiling QEMU for Windows x86_64 hosts with WHPX (Windows Hypervisor Platform) support, so is intended for use on Windows hosts with any Microsoft virtualization service enabled (WSL2, Virtualization-based Security, Hyper-V, etc.).

It enables 3D acclerated graphics for guests with ANGLE through VirGL so you don't need any further setup or configuration for GPU.

> [!IMPORTANT]
> This project is still very experimental and is not suitable for any production use.

## Building

### Using Docker

> [!NOTE]  
> Due to potential licensing problems, we can't include source code and DLL (Dynamic-link library) files for now. You will need to manually find and copy those files by following guidance in this guide.

To build QEMU with WHPX (Windows Hypervisor Platform) support, the following headers from the Windows SDK are required:

- WinHvEmulation.h
- WinHvPlatform.h
- WinHvPlatformDefs.h

These headers are typically located at `C:\Program Files (x86)\Windows Kits\10\Include\<your_windows_version>\um` and should be copied to the root directory of this project (same level with Dockerfile).

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

Find and copy `d3dcompiler_47.dll` file to the `output\bin` directory. You can find this DLL file in most Chromium web browsers binary directory, or from System32: 

```C:\Windows\System32\D3DCompiler_47.dll```

> [!TIP]
> You can use the same prebuilt binaries we use for testing at [Releases](https://github.com/Tsuki-Bakery/qemu-virgl-winhost/releases).
> You will still need (only) to copy `d3dcompiler_47.dll` file to the `output/bin` directory on yourself.
> We're also planning to setup GitHub Actions for automated builds.

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

### GNU/Linux guests

Linux guests have excellent 3D acceleration support with VirGL, often better than Windows guests. Modern Linux distributions already include the necessary VirtIO GPU drivers.

Install a Linux distribution:
   ```
    .\output\qemu-system-x86_64w.exe `
    -M q35 `
    -m 4G `
    -smp 4 `
    -accel whpx,kernel-irqchip=off `
    -netdev user,id=anet0 -device virtio-net-pci,netdev=anet0 `
    -usb -device usb-tablet `
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
> [!NOTE]
> For Windows guests, you'll need to install VirtIO GPU drivers from the [VirtIO drivers ISO](https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/).

With ISO file for Windows setup installation:
   ```
    .\output\qemu-system-x86_64.exe `
    -M q35 `
    -m 4G `
    -smp 4 `
    -accel whpx,kernel-irqchip=off `
    -netdev user,id=anet0 -device virtio-net-pci,netdev=anet0 `
    -usb -device usb-tablet `
    -cdrom windows.iso `
    -hda windows-disk.qcow2 `
    -device virtio-vga-gl `
    -display sdl,gl=on
   ```

After installation, you can remove `-cdrom windows.iso` option.

~~Alternatively, you can explicitly use OpenGL ES for ANGLE: `-display sdl,gl=es`~~ Currently not working well, will crash. 

## Troubleshooting

### Can't file some QEMU library DLL files
We're addressing this issue. For now, run this every time you open Powershell:

```
$env:Path += ';C:\path\to\qemu\output\bin'
```
or edit user path, if you don't mind.

## How to Contribute

Feel free to open or participate in project discussions on [the issues page](https://github.com/Tsuki-Bakery/qemu-virgl-winhost/issues).

You may clone this repository, improve it and create a merge request, or help us to review them at [Pull requests](https://github.com/Tsuki-Bakery/qemu-virgl-winhost/pulls).

You can also join us to talk around this project on our [Telegram chat room](https://t.me/+Fo64cxKTGnNlZDhl).

## Credits

Original [work](https://github.com/matthias-prangl/qemu-virgl-winhost) from [matthias-prangl](https://github.com/matthias-prangl).