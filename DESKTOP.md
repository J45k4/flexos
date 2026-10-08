# FlexOS desktop

The desktop boots directly on QEMU's emulated PC as a native x86-64 kernel.
There is no Linux guest. The window manager, applications, software renderer,
original bitmap font, PCI/VGA and PS/2 drivers, build tools and tests are all
written in Flexscript and compiled to machine code by Flexscript.

## Build and run

Use a current Flexscript compiler containing the bare-metal backend and its
16/32-bit port I/O builtins. The released 0.0.5 compiler can build that compiler
from current sources, but cannot itself compile this desktop.

From this repository's root:

```sh
mkdir -p build
/path/to/current-flex tools/build-baremetal.flex -o build/build-baremetal
build/build-baremetal /path/to/current-flex
build/run-desktop qemu-system-x86_64
```

Install QEMU's SDL display backend on Wayland, or GTK on other hosts, as well as
its x86 system emulator. The
launcher selects standard VGA, a 1024x768 display, one CPU and 64 MiB RAM. It
exposes the serial administrator shell in the launching terminal. Click inside
QEMU to capture the mouse; Ctrl+Alt+G releases it. Closing QEMU stops the guest.
When `WAYLAND_DISPLAY` is set, the launcher selects `sdl,gl=off` for native
relative PS/2 mouse capture. Other hosts use GTK by default. A third launcher
argument overrides this choice. If the guest pointer is stuck in an existing
Wayland GTK window, use SDL instead; restarting loses RAM files.
Install the SDL UI module too (`qemu-ui-sdl` on Arch); the emulator's headless
package may not include it.

An extracted QEMU can be passed explicitly:

```sh
LD_LIBRARY_PATH=/path/to/qemu/usr/lib \
QEMU_MODULE_DIR=/path/to/qemu/usr/lib/qemu \
build/run-desktop /path/to/qemu/usr/bin/qemu-system-x86_64 /path/to/qemu/usr/share/qemu
```

A third argument selects another QEMU display backend. The serial-only kernel
and its launcher are still available; see [BAREMETAL.md](BAREMETAL.md).

## Using the desktop

Click a desktop shortcut, dock icon or launcher entry to open an application.
The dock indicates open windows; clicking the active application minimizes it.
Drag a title bar to move a window and its lower-right corner to resize it.
Title-bar controls minimize, maximize/restore and close windows.

| Shortcut | Action |
| --- | --- |
| F1 or Super | Toggle the launcher |
| F2 / F3 / F4 | Open Notes / Files / Terminal |
| Ctrl+Alt+T | Open Terminal |
| Alt+Tab | Switch to the previously focused visible window |
| Alt+F4 | Close the focused window |
| Escape | Dismiss menus or Notes selection |

Files browses the shared RAM filesystem. Click a folder to enter it or a text
file to open it in Notes. Up returns to the parent directory; New note creates
a uniquely named text file in the current directory. Arrow keys and Enter also
navigate the list. Refresh updates it after changes from Terminal.

Notes supports insertion, deletion, arrow keys, Home/End, Ctrl+A and Ctrl+S.
The Save button also saves. Closing Notes preserves its draft during the
session; opening another file or creating a new note requires saving a dirty
draft first. Notes has an 8 KiB limit. Its default save path is `/notes.txt`.

Terminal uses the same filesystem commands as the serial shell. Try:

```text
help
mkdir projects
write projects/hello.txt "Hello from the desktop"
cat projects/hello.txt
ls projects
```

Home/End and arrow keys edit the command; Up recalls the previous command.
`clear` or Ctrl+L clears the display. `exit` closes Terminal; `shutdown` or the
top-bar Power menu halts the kernel. QEMU stays open after the CPU halts.

**Storage is volatile:** all files disappear on a fresh boot. These four built-in
applications execute inside the kernel. The hosted target's supervised VM
applications are not available on bare metal yet.

## Architecture and tests

`core/desktop.flex` owns window state, focus, application models, input policy
and the event loop. `core/desktop-render.flex`, `core/graphics.flex` and
`core/font.flex` draw the interface into a software backbuffer. Only
`platform/pc-desktop.flex` knows about PCI, Bochs VBE and the i8042 controller.
`platform/baremetal.flex` supplies memory, filesystem and serial services.
The renderer repaints after scene changes and updates small rectangles for
cursor movement. It uses no external fonts, images, browser or GUI toolkit.

```sh
build/test-desktop /path/to/current-flex qemu-system-x86_64
# Optional third argument: QEMU firmware directory.
```

The Flexscript test harness boots the real image and sends QMP keyboard/mouse
events through emulated PS/2 devices. It checks framebuffer pixels, window
geometry and visibility, editing, reopen/save, folder navigation, New note,
unsaved-draft protection and graphical Terminal commands. The serial shell
independently verifies saved file contents. Screenshots are written to
`build/desktop-tests/`. Shutdown checks actual ring-0, long-mode and halted CPU
registers. CI runs this harness and uploads the boot images and screenshots.

The Wayland host path has an additional fully headless regression:

```sh
build/test-desktop-wayland /path/to/current-flex qemu-system-x86_64 sway
# Optional fourth argument: QEMU firmware directory.
```

It creates a private temporary Wayland runtime and a Sway headless output using
the software renderer. Virtual pointer/keyboard events pass through QEMU's SDL
display backend, emulated PS/2 devices and the real guest desktop. Framebuffer
checks verify movement, clicking, dragging, capture release and recapture. It
opens no host windows, captures no host input, and shuts down its own processes.
The test driver and Wayland protocol client are Flexscript too. Sway and
libxkbcommon are test dependencies; CI runs both desktop harnesses.

The current hardware target is QEMU standard VGA with PS/2 input, fixed
1024x768 resolution, ASCII text and a US keyboard layout. Input is polled;
interrupts, a scheduler, persistent disks, clipboard, wheel scrolling and
isolated desktop app execution remain future work. Physical PCs are untested.
