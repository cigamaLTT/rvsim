# RISC-V Simulator (`rvsim`)

Cross-platform RISC-V simulator written in C++23 with Dear ImGui, GLFW, and OpenGL3/WebGL2, targeting **Linux, Windows, macOS, and the Web (Emscripten)**.

## Prerequisites

- **CMake** `3.21+` and **Ninja**
- **Strict C++23 toolchain** (must support `<print>` and `<ranges>`):
  - **Linux:** GCC `14+` or Clang `18+` (`libc++`)
  - **macOS:** Xcode `16.3+`
  - **Windows:** Visual Studio `2022 17.7+` (MSVC `19.37+`) or Visual Studio `2026`
  - **Web:** [Emscripten](https://emscripten.org/) (`emsdk` latest or system `emcmake`)

Dependencies (`ocornut/imgui` and `glfw/glfw` on native builds) are fetched automatically via `CPM.cmake` at configure time—no recursive git clone is required. Core UI fonts are embedded into the compiled binary at build time.

### Linux Desktop Dependencies

On Debian/Ubuntu, install X11, Wayland, and OpenGL development headers for GLFW:

```bash
sudo apt-get install \
  libxrandr-dev libxinerama-dev libxcursor-dev libxi-dev \
  libgl1-mesa-dev libwayland-dev libxkbcommon-dev pkg-config
```

## Building and Running

Clone the repository:

```bash
git clone https://github.com/tuasananh/rvsim
cd rvsim
```

### Native (Linux / macOS / Windows)

On Windows, run from a **Visual Studio Developer Command Prompt** (or Developer PowerShell) so `Ninja` finds `cl.exe`. On Ubuntu 24.04, select GCC 14 with `CXX=g++-14`.

```bash
cmake --preset native-release
cmake --build --preset native-release
```

Run the native executable:

```bash
./build/native-release/rvsim      # Linux / macOS
.\build\native-release\rvsim.exe  # Windows
```

For a debug build, use the `native-debug` preset instead.

### Web (Emscripten)

If using `emsdk` (with `EMSDK` set via `source emsdk_env.sh`):

```bash
cmake --preset web
cmake --build --preset web
```

If using a distro-packaged Emscripten without `$EMSDK` (such as Arch Linux `/usr/lib/emscripten`):

```bash
emcmake cmake --preset web-emcmake
cmake --build --preset web-emcmake
```

Serve locally with `emrun`:

```bash
emrun build/web/index.html
```

> **Note on Web multi-threading (`-pthread`):** Because `rvsim` uses WebAssembly pthreads (`SharedArrayBuffer`), static hosts require a Secure Context (`https://` or `http://localhost`). `web/coi-serviceworker.js` is bundled automatically so deployments on static hosts such as GitHub Pages can enable Cross-Origin Isolation.
