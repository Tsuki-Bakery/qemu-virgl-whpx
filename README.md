# QEMU with VirGL for Windows

This repository provides a Docker-based build system for cross-compiling QEMU with VirGL renderer support for Windows hosts.

## Dependencies

To build QEMU with WHPX (Windows Hypervisor Platform) support, the following headers from the Windows SDK are required:

- WinHvEmulation.h
- WinHvPlatform.h
- WinHvPlatformDefs.h

These headers are typically located at `C:\Program Files (x86)\Windows Kits\10\Include\<your_windows_version>\um` and should be copied to the folder with the Dockerfile.

To run QEMU with VirGL on Windows, the following ANGLE DLLs are required:

- libEGL.dll
- libGLESv2.dll
- d3dcompiler_47.dll

These DLLs can be obtained from Microsoft Edge or Google Chrome (located in their installation directories).

## Building QEMU

### Using Docker

1. Build the Docker image and load it into the local registry:
   ```bash
   # For Mac with Apple Silicon (M1/M2/M3/M4):
   docker buildx build --platform linux/arm64 -t qemu-virgl-win-cross --load .
   
   # For other platforms (Linux, Windows, Intel Mac):
   docker build -t qemu-virgl-win-cross .
   ```

2. Extract the built files to your local machine:
   ```bash
   mkdir -p ./output
   docker run --rm -v "$(pwd)/output:/mnt/output" qemu-virgl-win-cross
   ```

3. Copy the required ANGLE DLLs to the `output/bin` directory.

## Running QEMU with VirGL

### Creating a Virtual Machine

1. Create a disk image:
   ```
   ./output/qemu-img.exe create -f qcow2 vm-disk.qcow2 50G
   ```

2. Install Windows from an ISO:
   ```
   ./output/qemu-system-x86_64w.exe -M q35 -m 4G -cdrom windows.iso -hda vm-disk.qcow2 -device virtio-vga-gl -display sdl,gl=on
   ```

### Running Windows Guests with VirGL

For optimal 3D acceleration using VirGL:

```
./output/qemu-system-x86_64w.exe -M q35 -m 4G -hda windows.qcow2 -device virtio-vga-gl -display sdl,gl=on
```

Alternative command with explicit OpenGL ES mode:

```
./output/qemu-system-x86_64w.exe -M q35 -m 4G -hda windows.qcow2 -device virtio-vga-gl -display sdl,gl=es
```

**Note:** For Windows guests, you'll need to install VirtIO GPU drivers from the [VirtIO drivers ISO](https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/).

### Running Linux Guests with VirGL

Linux guests have excellent 3D acceleration support with VirGL, often better than Windows guests. Modern Linux distributions already include the necessary VirtIO GPU drivers.

1. Install a Linux distribution:
   ```
   ./output/qemu-system-x86_64w.exe -M q35 -m 4G -cdrom ubuntu.iso -hda linux.qcow2 -device virtio-vga-gl -display sdl,gl=on
   ```

2. Run an existing Linux VM with acceleration:
   ```
   ./output/qemu-system-x86_64w.exe -M q35 -m 4G -hda linux.qcow2 -device virtio-vga-gl -display sdl,gl=on -smp cores=4
   ```

For optimal Linux guest experience:
- Use Ubuntu 20.04 or newer, Fedora 34+, or any recent distro with kernel 5.10+
- The Mesa drivers in these distributions have excellent VirtIO support
- 3D applications and desktop environments will automatically use hardware acceleration

To verify 3D acceleration is working in your Linux guest:
```bash
glxinfo | grep "OpenGL renderer"
```
The output should show "virgl" as the renderer.

## Optimization Options

- **Memory**: Adjust `-m 4G` to set the amount of RAM for the VM
- **CPU Cores**: Add `-smp cores=4` to specify the number of virtual CPU cores
- **Audio**: Add `-audiodev dsound,id=audio0 -device intel-hda -device hda-output,audiodev=audio0` for sound
- **Network**: Add `-nic user,hostfwd=tcp::3389-:3389` to enable RDP access

## Troubleshooting

If you encounter graphical issues:

1. Ensure all three ANGLE DLLs are in the same directory as the QEMU executable
2. Try the `-display sdl,gl=es` option which explicitly uses OpenGL ES mode
3. For older Windows versions, install the latest graphics drivers

## Advanced Options

For debugging or special use cases:

- Add `-enable-kvm` on Linux hosts for KVM acceleration
- Add `-enable-whpx` on Windows hosts for Hyper-V acceleration
- Add `-monitor stdio` to access the QEMU monitor
- Add `-usb -device usb-tablet` for better mouse integration

## Credits

This build system is based on the work by [matthias-prangl](https://github.com/matthias-prangl).