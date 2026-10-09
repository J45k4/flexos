# Historical Linux Doom on FlexOS

id Software's original `linuxdoom-1.10` source runs through FlexOS's general
Linux and X11 services. The engine's C/header files, including its original
`i_video.c`, remain unchanged. A normal Linux toolchain builds a static i386 ELF
with ordinary libc, Xlib and Xext. FlexOS boots that ELF byte-for-byte in ring 3;
there is no game-side FlexOS adapter and no Linux kernel or Xorg in the guest.

Flexscript implements the ELF loader, 32-bit Linux ABI, TLS, rootfs, local X11
stream service, indexed palette rendering, PS/2-to-X11 keyboard events, real
System V shared memory and MIT-SHM image/completion requests. These services
also run an independent ordinary Xlib client. This is separate from the older
trusted ring-0 [native Doom adapter](DOOM.md).

## Build

Requirements: current Flexscript compiler, x86-64 Linux host, multilib `cc` and
static i386 libc/X11/Xext/XCB/Xau/Xdmcp libraries, `make`, `tar`, `curl`, `unzip`,
`nm` and QEMU. On Ubuntu the extra build dependencies are `gcc-multilib`,
`libx11-dev:i386` and `libxext-dev:i386` (enable the i386 package architecture).
From the FlexOS repository root:

```sh
mkdir -p build
/path/to/current-flex tools/fetch-doom.flex -o build/fetch-doom
build/fetch-doom
/path/to/current-flex tools/build-linux-doom.flex -o build/build-linux-doom
build/build-linux-doom /path/to/current-flex \
  build/doom-deps/DOOM-a77dfb96cb91780ca334d0d4cfd86957558007e0/linuxdoom-1.10 \
  build/doom-deps/freedoom-0.13.0/freedoom1.wad
build/run-linux-doom qemu-system-x86_64
```

The fetcher pins source commit `a77dfb96cb91780ca334d0d4cfd86957558007e0`
and verifies archive SHA-256 before extraction. The builder can also accept a
final static i386 X11 library directory for locally extracted libraries.
Legacy `errnos.h`/`values.h` definitions and forced `errno.h` inclusion provide
the historical build environment without editing engine sources. GNU89,
32-bit compilation, common globals, wraparound integer arithmetic and disabled
strict aliasing preserve the old C assumptions. The link address starts at
4 MiB within the loader's current arena; the resulting ELF is a standard Linux
executable. There is no FlexOS library in its link command.

The builder creates `build/linux-id-doom/objects/linuxxdoom` and a read-only tar
rootfs containing the supplied compatible IWAD as `doom.wad`. The default is
Freedoom Phase 1 replacement assets, not commercial Doom assets. Original Doom
prints a registered/commercial startup message because of that filename.
Retain the engine's GPL license and provide corresponding source when
redistributing its binary; preserve Freedoom's BSD license/credits for WADs.
Dependency sources and binaries remain under ignored `build/`.

## Run the built version in this workspace

```sh
cd /home/teppo/Work/my/flexscript/workdir/flexos
LD_LIBRARY_PATH=../../build/qemu-local/usr/lib \
QEMU_MODULE_DIR=../../build/qemu-local/usr/lib/qemu \
build/run-linux-doom ../../build/qemu-local/usr/bin/qemu-system-x86_64 \
  ../../build/qemu-local/usr/share/qemu
```

The launcher uses SDL on Wayland, GTK elsewhere, 256 MiB guest RAM, one CPU,
standard VGA and no network device. Click inside to capture the keyboard;
Ctrl+Alt+G releases SDL capture. It starts episode 1/map 1/skill 2 with the
original `-2` option for a 640x400 game window in the 1024x768 display. The
generic Linux launcher defaults SDL to its software renderer, matching the
headless input tests. An explicit `SDL_RENDER_DRIVER` environment variable
overrides that choice. This avoids depending on the host's accelerated SDL
presentation path for the guest framebuffer.

| Key | Action |
| --- | --- |
| Up/down arrows | Forward/backward |
| Left/right arrows | Turn |
| Ctrl | Fire |
| Space | Use/open door |
| Shift | Run |
| Alt + left/right | Strafe |
| 1..7 | Weapon |
| Tab | Automap |
| Escape | Menu |
| F10, then Y | Quit; launcher returns after kernel resumes |

Bindings and movement physics are original. W/S are not bound by default.
This Linux/X11 target currently has keyboard input only, no sound server/music,
no save/config writes and no desktop window integration. Mouse and W/S support
in the older native adapter do not apply to this executable.

## Headless checks

```sh
build/test-linux-doom qemu-system-x86_64
# Exercise the actual SDL keyboard path in a private headless compositor.
build/test-linux-doom-wayland qemu-system-x86_64 sway
# Append a firmware directory when using an extracted emulator.
```

The Flexscript harness tests actual CPU ring-3/32-bit mode, original ELF bytes,
IWAD loading, advancing game ticks, framebuffer pixels, player movement and
angle, key release, ammunition, menu and clean process exit. It uses upstream
symbols/ABI offsets and QMP memory inspection externally; it adds no telemetry
to the game or game-specific kernel API. PNGs are saved in
`build/linux-id-doom-tests/`. CI runs this alongside the general Linux/Xlib and
existing OS tests. The SDL harness measures from the host key event to the
original engine's movement command, including starts, reversals, repeated
presses, simultaneous directions and releases, with a 150 ms bound. Original
movement inertia and accelerated keyboard turning remain part of the engine;
the harness does not treat velocity or the eventual stopping position as a
measure of keyboard delivery time.

The general X11 renderer clips once per window and converts pixels using row
pointers. It polls hardware during rendering and queues collected key events
before image completion. An independent Xlib shared-memory client checks that
a batch of frames cannot postpone a key release until every frame completes,
as well as odd-width images and clipping at the framebuffer edge.

An additional unchanged DoomGeneric Linux framebuffer build is available in
`tools/build-linux-doom-vt.flex`, `tools/run-linux-doom-vt.flex` and
`tests/linux-doom-vt.flex`; it uses fbdev/evdev directly and remains separate
from this historical X11 target.
