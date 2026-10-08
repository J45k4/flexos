# FlexOS hosted kernel in Flexscript

FlexOS also boots directly on QEMU's virtual hardware, with no Linux guest.
See [bare-metal build and test instructions](BAREMETAL.md). Both targets use the
same shell and filesystem policy core; their platform adapters differ.
For graphical windows, Files, Notes and Terminal, see [the desktop](DESKTOP.md).

This implements the original first milestone: a Linux-hosted core with a console
shell, filesystem resource, and supervised applications. The core, Linux adapter,
apps, build tool and test harness are written in Flexscript. This replaces the
previous Rust and browser experiments; their sources remain in Git history.
The core compiles directly to a native Linux executable. Application guests run
in separate Flexscript VM processes supervised by that executable.

This repository is self-contained. There are no source imports or symlinks to a
Flexscript checkout. Supply compiler and VM executable paths explicitly.

## Build

Requirements: Linux x86-64 with `openat2` and `close_range` support. Released
Flexscript 0.0.5 can compile the kernel and tools. App execution needs a current
Flexscript VM with `run --restricted --no-url-imports` support; the frozen 0.0.5
release predates those VM features. The native kernel itself has no libc or
shared-library dependency. The VM and test harness use the system glibc.

From the repository root, substitute your compiler's absolute path:

```sh
mkdir -p build
/path/to/flex tools/build.flex -o build/build
build/build /path/to/flex
build/flexos --flex /path/to/current-flex
```

The builder creates `build/root` and installs the example app sources only if
they are absent. It preserves existing files. Choose another resource with
`--root DIRECTORY`; the directory must already exist.

## Shell example

```text
resources
mkdir projects
cd projects
write notes.txt "Hello from FlexOS"
cat notes.txt
cd /
app hello hello.flex
run hello
wait
app reader read.flex
grant reader fs.read
run reader projects/notes.txt
wait
revoke reader fs.read
apps
ps
exit
```

`help` lists all commands. Commands support single/double quotes and backslash
escapes, including `\n`, `\r` and `\t`. This is FlexOS command dispatch; commands
are not forwarded to a host shell. The interactive prompt uses the terminal's
existing canonical mode. There is no custom line editor or history yet.

For scripts and one-off operations:

```sh
printf 'pwd\nls\nexit\n' | build/flexos --batch
build/flexos --command resources
```

Shell `/` means the mounted filesystem resource, never the host's `/`. Path
normalization rejects traversal above that root. Linux opens use
[`openat2` with `RESOLVE_BENEATH | RESOLVE_NO_MAGICLINKS`](https://man7.org/linux/man-pages/man2/openat2.2.html).
Parent descriptors also confine mkdir/unlink operations. Internal relative
symlinks can be read; writes reject final symlinks. Files must be regular text
files without zero bytes, at most 64 KiB.

## Applications and capabilities

`app NAME SOURCE` registers a self-contained `.flex` source inside the resource.
`run NAME [ARGS...]` starts it asynchronously in a separate restricted VM
process. Apps receive no filesystem access initially. `grant NAME fs.read`
allows a subsequent invocation to read the mounted root. Guest file paths are
relative to that resource; the Linux adapter sets the child working directory
using the mounted directory descriptor.

Networking, filesystem writes, raw FFI, process creation and stdin remain
unavailable to guests. URL imports are disabled. Local source imports are also
rejected before execution: the VM's runtime read grant does not confine its
compiler's source reads. The adapter copies checked entry source into a private
0700 directory, so source changes after validation cannot change the invocation.
The import check recognizes tokens outside comments and strings.

Each VM invocation has a 4-MiB managed heap, 1,000,000 instructions, a one-second
VM deadline, and a 1-MiB combined output budget. Eligible code can use the VM's
automatic baseline JIT. The supervisor adds a five-second wall deadline and the
Linux adapter applies 512-MiB address-space and two-second CPU limits to the
whole VM process, including compilation. It closes inherited descriptors, gives
stdin `/dev/null`, and captures stdout/stderr. Guest terminal control bytes are
rendered as `?`.

`ps` reports app state and exit status. `wait` drains/reaps active apps; `stop`
terminates an app. Revoking a running app's read capability terminates that
invocation before removing the grant. Granting capabilities affects the next
invocation. `exit` and stdin EOF stop and reap active guests. Guests also receive
a parent-death kill signal. Private source copies are removed on normal exit.

Limits: 16 registered apps, 32 command words, and 4095 bytes per command. App
registrations/grants are session state; files persist. The administrator shell
owns read/write access to the chosen resource. These are VM capability
boundaries in a prototype, not a complete OS security architecture or an
audited sandbox for hostile tenants. Host administrators can still alter the
backing filesystem. Abruptly killing the kernel can leave a private source cache
under `/tmp/flexos-*`; normal shutdown removes it.

## Verification

```sh
build/test-flexos /path/to/native-compiler /path/to/current-flex-vm
```

The Flexscript harness builds a fresh kernel, exercises isolated temporary
filesystems and VM processes, checks traversal/symlink confinement, grants and
revocation, denied networking/write/FFI, infinite-loop budgets, argv/quoting,
source-import confinement, supervision, burst output, EOF cleanup, and a real
pseudo-terminal session with unchanged terminal attributes.

CI uses released 0.0.5 to build the kernel/tools and a pinned Flexscript source
revision to build the newer VM. It runs the same harness and uploads the native
kernel. No Rust, Cargo, Python, Node or C compiler is needed for these builds.

## Architecture and next targets

`core/kernel.flex` owns shell parsing, virtual paths, the app/capability registry,
process lifecycle policy, and the event loop. It has no Linux syscall or FFI
calls. `platform/linux.flex` supplies allocation, clock, file descriptors,
filesystem operations, terminal I/O and child-process operations.

The first execution provider is the Flexscript VM and the first storage provider
is a local directory. Distributed CPU/GPU/storage providers, Monolith integration,
authentication and encrypted transport, browser/mobile targets,
and additional bare-metal drivers are future work. Browser/mobile targets need
compiler/runtime support and additional adapters. The current compiler emits
Linux x86-64 ELF files or freestanding x86-64 boot images.
