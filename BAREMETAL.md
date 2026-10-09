# FlexOS on bare metal in QEMU

FlexOS boots as a native, ring-0 x86-64 kernel on QEMU's emulated PC. There is no
Linux guest. The kernel, serial driver, memory allocator, RAM filesystem,
build tools and test harness are Flexscript. Flexscript's bare-metal backend
generates the Multiboot header and 32-bit-to-64-bit CPU startup; no assembly,
C source, assembler, linker or Rust toolchain is used.

QEMU and its ordinary PC firmware/Multiboot loader are external emulator tools.
The graphical target adds a native desktop with Files, Notes and Terminal;
see [desktop build and usage](DESKTOP.md). This document describes the serial
target and the shared bare-metal services.

There is also a [native Doom boot target](DOOM.md). It loads the original engine
as an external game ELF and supplies its hardware/runtime services in Flexscript.
The separate game payload uses a C compiler and linker on the build host.

## Build

Requirements: a Linux x86-64 build host, QEMU's x86 system emulator and a current
Flexscript compiler with `--target baremetal-x86_64`. Released Flexscript 0.0.5
can build that compiler from current Flexscript sources; its frozen binary
predates the bare-metal target. Supply the compiler path explicitly.

From this repository's root:

```sh
mkdir -p build
/path/to/current-flex tools/build-baremetal.flex -o build/build-baremetal
build/build-baremetal /path/to/current-flex
build/run-qemu qemu-system-x86_64
```

If QEMU is extracted locally, pass its executable and firmware directory:

```sh
build/run-qemu /path/to/qemu-system-x86_64 /path/to/share/qemu
```

The launcher executes QEMU directly with 64 MiB RAM, one CPU, TCG acceleration,
serial stdio, no display/monitor/network and `-kernel build/flexos-baremetal.bin`.
It does not start a Linux kernel, mount a host filesystem in the guest or use
host commands for guest shell operations. Ctrl+C stops the emulator.

## Try it

```text
help
resources
cat welcome.txt
mkdir projects
cd projects
write notes.txt "Hello from bare metal"
cat notes.txt
ls
pwd
cd /
exit
```

`exit` prints `FlexOS halted.` and halts the guest CPU. QEMU remains open until
you stop it. Files exist only in guest RAM and disappear on a fresh boot.

The shared core owns command parsing, path normalization, the app registry and
event loop. `platform/baremetal.flex` owns polled COM1 serial I/O, a reusable
kernel heap, a 64-entry RAM filesystem and shutdown. It checks the Multiboot
handoff and available memory before starting the shell. Images load at 4 MiB;
page tables occupy 1 MiB, a downward-growing stack ends at 3 MiB, and the kernel
heap spans 16..32 MiB. Page tables use 0x100000..0x106000; the compiler
identity-maps the first four GiB in supervisor mode, including PCI framebuffer
addresses used by the desktop.

## Verify

```sh
build/test-baremetal /path/to/current-flex qemu-system-x86_64
# Optional firmware directory is the third argument.
```

The Flexscript harness builds two identical boot images, checks their Multiboot
headers and rejects Linux allocation/syscalls/FFI and invalid entry signatures.
It boots a real QEMU guest and verifies serial input/output, filesystem commands,
UTF-8, quoting, traversal rejection, errors, hundreds of allocation/free cycles,
shutdown and filesystem reset on a fresh boot. Through a temporary local QMP
socket it checks actual CPU registers for ring-0 long mode and `HLT=1` on exit.
No host-side script implements guest shell behavior.

The CI bare-metal job builds the current Flexscript compiler from its source
repository using released 0.0.5, runs this harness and uploads the boot image.
Its `flexscript_ref` workflow input accepts a compiler source commit or tag;
the default is `master`, which must contain the bare-metal backend. The compiler
change needs to be published before this job can run remotely.

## Current boundary

Interrupts stay disabled and the serial driver polls. The serial/desktop targets
have no IDT; there is no scheduler, disk driver, networking or freestanding VM
yet. The Doom target
adds a polled HPET clock; the serial and desktop targets do not use it. The graphical
target uses polled PS/2 input and a software-rendered VGA framebuffer. App
registration and capability commands share the hosted core, but `run`
returns an unavailable-provider error on bare metal. `resources` states this
explicitly. The Linux-hosted target continues to support restricted VM apps.

The next execution provider needs a freestanding VM and a scheduler; the kernel
cannot use Linux `fork`/`exec` on this target. A separate [Linux ABI boot
target](LINUX.md) now provides native ring-3 execution with separate page tables,
CPU fault handling and a Linux syscall subset, fbdev/evdev and X11 for unchanged static x86 ELF
applications, including [historical Linux Doom](LINUX-DOOM.md). It runs one process and then halts; it is not yet connected to
the shell or desktop execution provider. Booting on physical hardware has not
been tested.
