# Doom on native FlexOS

For the unchanged historical Linux/X11 executable using the general Linux ABI,
see [Linux Doom on FlexOS](LINUX-DOOM.md). This document describes the earlier
trusted native adapter target.

The original Doom engine (DoomGeneric) runs as a freestanding x86-64 game ELF
inside the FlexOS bare-metal guest. Flexscript implements the kernel, binary
module loader, memory services, VGA framebuffer scaling, PS/2 keyboard and mouse,
HPET timing, dependency/build tools and headless tests. There is no Linux guest.
The engine and its small game-side C ABI adapter are an external payload, built
with the host C compiler and linker. They are not linked into the FlexOS kernel.

This is a separate Doom boot target, alongside the serial and desktop targets.
It starts directly in episode 1, map 1 on skill 2. The default downloaded assets
are Freedoom Phase 1, which uses the real Doom engine with freely distributable
replacement levels and artwork. Supply your own compatible Doom IWAD to use
original game assets; commercial assets are not included in this repository.

## Build and launch

Requirements: a current Flexscript compiler with native bare-metal callbacks,
a Linux x86-64 host, `cc`, `ld`, `curl`, `tar`, `unzip` and QEMU's x86 PC emulator.
Released Flexscript 0.0.5 can build the current compiler source; its frozen binary
cannot compile this kernel directly.

From the FlexOS repository root:

```sh
mkdir -p build
/path/to/current-flex tools/fetch-doom.flex -o build/fetch-doom
build/fetch-doom
/path/to/current-flex tools/build-doom.flex -o build/build-doom
build/build-doom /path/to/current-flex \
  build/doom-deps/doomgeneric-dcb7a8dbc7a16ce3dda29382ac9aae9d77d21284/doomgeneric
build/run-doom qemu-system-x86_64 build/doom-deps/freedoom-0.13.0/freedoom1.wad
```

With locally extracted QEMU, append its firmware directory:

```sh
build/run-doom /path/to/qemu-system-x86_64 /path/to/game.wad /path/to/share/qemu
```

The launcher selects SDL on Wayland and GTK elsewhere. An optional fourth
argument overrides the display, for example `none` for headless operation.
Click the emulator display to capture input. Ctrl+Alt+G releases SDL capture.
The guest uses 128 MiB RAM, one CPU, standard VGA, HPET, serial stdio and no
network device. The ELF and IWAD are passed as two Multiboot modules. Paths are
staged under safe temporary filenames to handle spaces and commas correctly.

Controls:

| Input | Action |
| --- | --- |
| Arrow keys | Move forward/back, turn left/right |
| W/S | Move forward/back |
| A/D | Strafe left/right |
| Ctrl / left mouse | Fire |
| Mouse movement | Original Doom mouse movement/turning |
| Space | Use/open door |
| Shift | Run |
| 1..7 | Select weapon |
| Tab | Automap |
| Escape | Game menu |
| F12 | Halt the FlexOS guest |

Close the emulator window or interrupt the launcher to stop QEMU after halting.
The launcher does not forward its piped stdin to the guest; serial `stats` and
`quit` are used by the headless harness.

## Headless verification

```sh
build/test-doom qemu-system-x86_64 build/doom-deps/freedoom-0.13.0/freedoom1.wad
build/test-doom-wayland qemu-system-x86_64 build/doom-deps/freedoom-0.13.0/freedoom1.wad sway
# Append the firmware directory when needed.
```

The Flexscript test starts QEMU with `-display none`. It checks a nonblank game
framebuffer, advancing live game ticks, actual player coordinates and angle,
held keys and releases, ammunition consumption from keyboard and mouse fire,
relative mouse turning, ring-0 long-mode halt, and rejection of invalid WAD
directories, ELF segments and entry addresses. Captures are written to
`build/doom-tests/{start,playing,menu}.png`. No host window or desktop input is
used. CI builds and tests this target alongside the existing OS tests.

The build tool applies a checked patch to a build copy of DoomGeneric's input
source so it drains all queued key releases in one input pass. The upstream
loop stops after each release, which can leave movement active across several
game tics during quick combinations. The test measures release queue latency
and checks that turning stops after a burst. The renderer polls input between
scanlines and scales pairs of pixels with word operations. Readiness is announced
after the engine's opening screen transition finishes.

The Wayland test uses a private headless compositor and the real SDL keyboard
path to check W/S, arrows, repeated keydowns, overlapping aliases and direction
changes. Telemetry exposes held input, forward/side commands and momentum
separately: original Doom momentum can continue movement after a command clears.
The movement physics remain unchanged.

## Current boundary

The game is a trusted native ring-0 payload. ELF bounds checking prevents its
segments from overwriting kernel/heap/WAD regions while loading; it is not a
sandbox or separate address space. The kernel does not dynamically link libc,
make Linux syscalls or invoke host drawing/input services. The game adapter
provides the libc subset this engine needs. Configuration and save-game file
writes are unavailable; sound and music are disabled. Networking and desktop
window integration are not implemented for this target.

The kernel image stays below 1 MiB. Game ELF segments occupy 8..12 MiB, the
kernel heap occupies 16..32 MiB, and a validated IWAD of at most 48 MiB is copied
to 64..112 MiB before any kernel heap allocations. QEMU PC HPET is required;
interrupts remain disabled and hardware input is polled. The engine uses its
original fixed-point gameplay and renderer at 320x200, displayed at 960x600.

## Dependencies and licenses

`tools/fetch-doom.flex` pins URLs and verifies SHA-256 before extraction:

- [DoomGeneric](https://github.com/ozkl/doomgeneric) revision
  `dcb7a8dbc7a16ce3dda29382ac9aae9d77d21284`: GPL-2.0-or-later. The payload
  adapter is also GPL-2.0-or-later. Preserve the upstream license and provide
  corresponding engine and adapter source when distributing the game ELF.
- [stb_sprintf](https://github.com/nothings/stb) revision
  `2c980bb59875b0d32144a71867fbdebb2f77cd20`: MIT/public-domain dual license.
  Its license text is included in the downloaded header.
- [Freedoom 0.13.0](https://github.com/freedoom/freedoom/releases/tag/v0.13.0):
  BSD-3-Clause. The archive includes `COPYING.txt` and `CREDITS.txt`; retain them
  alongside redistributed WAD assets.

Downloaded sources, assets, executables and screenshots remain under ignored
`build/`. The kernel source does not import or vendor the engine source.
