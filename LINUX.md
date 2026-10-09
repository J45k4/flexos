# Linux executable compatibility on FlexOS

FlexOS loads ordinary static Linux x86 executables into a separate ring-3 address
space. Both x86-64 ELF/SYSCALL and i386 ELF/INT 0x80 are supported. The kernel,
loader, memory services, Linux ABI, graphics/input drivers, X11 service, build
tools and headless harnesses are Flexscript. There is no Linux kernel in the
guest and applications need no FlexOS adapter or executable patch.

This separate boot target runs one process, returns to the kernel on exit or a
CPU fault, then halts. It now runs static libc programs, an independent Xlib
client and [historical id Linux Doom with X11](LINUX-DOOM.md). It is a bounded ABI
subset, not compatibility with arbitrary Linux applications, and is not yet
connected to the desktop shell's execution provider.

## Build and run

Use the current Flexscript compiler with bare-metal native callbacks. Released
0.0.5 can build that compiler from source; its frozen binary cannot directly
compile this kernel. On a Linux x86-64 host, from the FlexOS repository root:

```sh
mkdir -p build
/path/to/current-flex tools/build-linux.flex -o build/build-linux
build/build-linux /path/to/current-flex
build/linux/hello.elf
build/run-linux qemu-system-x86_64 build/linux/hello.elf
```

The last two commands execute the same ELF on host Linux and FlexOS. The
launcher stages unchanged modules under safe filenames, forwards serial stdin
after UART setup and returns the guest application's exit status. It defaults
to headless QEMU. An optional firmware directory follows the ELF argument.

Compile applications using their normal Linux target, for example:

```sh
/path/to/current-flex myapp.flex -o build/linux/myapp.elf
cc -static -no-pie myapp.c -o build/linux/myapp-c.elf
# The current loader's ELF segment arena starts at 4 MiB:
cc -m32 -static -no-pie -Wl,-Ttext-segment=0x400000 myapp.c -o build/linux/myapp32.elf
```

The C examples use ordinary static libc and Linux startup code. A 32-bit C build
requires multilib libc/compiler support. No FlexOS compiler target or application
platform shim is involved.

For application files and arguments, supply a read-only ustar root filesystem:

```sh
tar --format=ustar -cf build/rootfs.tar -C my-rootfs .
build/run-linux qemu-system-x86_64 build/linux/myapp.elf \
  --rootfs build/rootfs.tar -- 'argument with spaces' ''
# Use --display sdl,gl=off to open a graphical guest instead of headless QEMU.
```

## Implemented services

| Linux API | Current service |
| --- | --- |
| `read`, `write`, vector I/O, close | Serial console, binary-safe files, devices and local stream descriptors |
| open/openat, stat/statx, seek, getdents64 | Read-only tar rootfs, directory-relative opens and device discovery |
| mmap, mprotect, munmap, brk | Anonymous memory, framebuffer mappings and hardware page permissions |
| arch_prctl / set_thread_area | x86-64 FS TLS and i386 GS TLS for static libc |
| clocks, gettimeofday, time, relative sleeps | CMOS UTC epoch and HPET elapsed time; millisecond resolution |
| poll, fcntl, ioctl | Descriptor readiness, nonblocking input, console metadata and device control |
| System V shared memory | Eight segments, up to 32 attachments, actual page aliases and deferred removal |
| AF_UNIX stream I/O | Built-in X11 service at `/tmp/.X11-unix/X0`; pathname and abstract connections |
| identity, uname, get-only prlimit64 | One process, UID/GID 1000, bounded stack and descriptor limits |
| exit/exit_group | Return status to the kernel |

Unknown syscalls return `-ENOSYS`; unsupported arguments/facilities return Linux
negative errno values. User buffers are checked for mapping and permissions.
Files are read-only: writes/saves and directory creation are unavailable. Console
transfers are bounded to 1 MiB; there are 16 non-console descriptor slots.

The startup stack uses the executable's 32/64-bit word size, includes `/app` as
argv[0], quoted application arguments, `FLEXOS=1`, `HOME=/`, `DISPLAY=unix:0`, and
auxiliary program-header/entry/page-size/identity information. No entropy or vDSO
is supplied. Thread startup bookkeeping supports single-threaded libc, but there
are no threads, futex synchronization or signal delivery.

## Graphics, input and X11

`/dev/fb0` exposes ordinary fbdev metadata/ioctls and a shared mapping of the
1024x768 BGRA framebuffer. `/dev/input/event0` exposes standard Linux evdev
keyboard events, polling, capability bitmaps and exclusive grab. Mouse support
has not been added to this Linux input driver.

The built-in X11 service consumes standard little-endian X11 requests through
a local stream, manages resources and properties, exposes an 8-bit PseudoColor
visual, presents indexed windows, and sends exposure/keyboard events. The core
subset includes window/pixmap/GC creation and destruction, rectangle drawing,
PutImage, palette updates, geometry and keyboard mapping. MIT-SHM attach,
detach, image presentation and completion events use actual System V shared
pages; unsupported extensions/operations fail instead of being simulated.

This initial service lives in the Flexscript kernel, with one client and at most
64 graphics resources/properties. It is not Xorg or a complete window system.
Fonts/text rendering, general cursors/mouse, the remaining X11 requests,
Internet sockets, application bind/listen, writable storage, dynamic linking,
scheduling and signals remain future work. The existing desktop and trusted
native Doom targets continue separately.

## CPU and memory boundary

Kernel and application page tables are separate. Kernel memory, page tables,
port I/O and hardware remain privileged, except the explicitly requested fbdev
mapping. Protected trampolines switch stacks and CR3 for SYSCALL/INT 0x80. CPU
fault gates use a private TSS stack and return status 139 for a user fault.
Kernel faults halt with a diagnostic. Interrupts remain disabled; no preemption
or process creation/exec is implemented.

The base target needs 128 MiB RAM; a rootfs needs 256 MiB and is copied above
kernel/user allocation arenas before heap initialization. ELF modules must fit
below 16 MiB and rootfs archives are at most 48 MiB. ELF segments use VAs
4..128 MiB, brk 128..256 MiB, anonymous/shared memory 256..768 MiB, framebuffer
mappings 768..992 MiB, and a 1-MiB stack ends at 1 GiB. User pages draw from a
reusable 64-MiB physical pool. Mapping/table arenas are bounded and virtual
mapping addresses advance instead of being reused.

Only little-endian static x86 ET_EXEC is accepted. TLS templates are validated;
libc performs TLS initialization. PIE, interpreters and dynamic linking are
rejected. Segment/file bounds, overlap, alignment and executable entry are
validated; RX/R/RW permissions are preserved.

## Headless verification

```sh
build/test-linux /path/to/current-flex qemu-system-x86_64
build/test-linux-x11 /path/to/current-flex qemu-system-x86_64
# Optional firmware directory follows QEMU.
# X11 test also accepts a final directory of static i386 X11 libraries.
```

The Flexscript harness compares identical executable bytes on Linux and FlexOS.
It covers both libc ABIs, TLS, shared-memory aliases and deletion, binary rootfs
I/O, arguments, devices, UART, loader rejection and CPU-enforced privilege,
write and NX boundaries. The separate ordinary Xlib client verifies drawing,
properties, geometry, keyboard mapping and press/release events. All guests use
private headless QMP; no user desktop input is needed. CI also runs historical
Linux Doom's gameplay test. Compiler callback changes must be published in the
parent Flexscript repository before the remote pipeline can build them.

References: [Linux x86 entry](https://github.com/torvalds/linux/blob/master/arch/x86/entry/entry_64.S),
[AMD64 ELF ABI](https://refspecs.linuxfoundation.org/elf/x86_64-abi-0.99.pdf),
[X11 protocol](https://www.x.org/releases/X11R7.7/doc/xproto/x11protocol.html),
[fbdev](https://www.kernel.org/doc/html/latest/fb/api.html),
[evdev events](https://www.kernel.org/doc/html/latest/input/event-codes.html).
