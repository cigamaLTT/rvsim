# AGENTS.md

Guidelines for coding agents working in `rvsim`.

## 1. Project Overview & Target Scope

`rvsim` is a cross-platform RISC-V simulator written in **C++23**, targeting **Linux, Windows, macOS, and WebAssembly (Emscripten)**, with a **Dear ImGui** (`docking` branch) + GLFW + OpenGL3/WebGL2 UI.

- **Target simulator scope**: Full-featured **RV32/RV64** simulator supporting both **ELF binaries** and **assembly input**.
- **Core architectural boundary**: Keep `src/simulator/` (ISA decode/execute, memory, CSRs, ELF loader, assembler) decoupled from ImGui, GLFW, and Emscripten APIs so the simulator core remains portable and unit-testable on a native host compiler.

## 2. Repository Layout

- `CMakeLists.txt` — Unified multi-OS + Web CMake build (`rvsim` executable, `imgui_lib`, `imgui_text_editor`, and `rvsim_platform`), fetching `ocornut/imgui` and native `glfw` via `CPM.cmake`.
- `CMakePresets.json` — Configure and build presets (`native-debug`, `native-release`, `web`, `web-emcmake`).
- `cmake/` — Build helpers:
  - `get_cpm.cmake` — `CPM.cmake` (`v0.43.2`) bootstrapper with SHA256 verification.
  - `embed_assets.cmake` — Build-time `.ttf` asset embedder generating `generated/embedded_fonts.{h,cpp}`.
- `web/coi-serviceworker.js` — Cross-Origin Isolation service worker (`v0.1.7`), copied next to `build/web/index.html` via `POST_BUILD` for static hosts such as GitHub Pages.
- `shell_minimal.html` — Custom Emscripten HTML shell (`#canvas`) loading `coi-serviceworker.js` and gating `{{{ SCRIPT }}}` inside `<template id="emscripten-script">` until `window.crossOriginIsolated` is true.
- `.github/workflows/ci.yml` — 4-platform CI (`linux`, `windows`, `macos`, `web`) plus `v*`-tag GitHub Release and GitHub Pages deployment.
- `.clang-format` — Formatting rules (`BasedOnStyle: Google`).
- `.clangd` — `clangd` configuration (`CompilationDatabase: build/native-release`, strips `-sDISABLE_EXCEPTION_CATCHING=*`, `-sUSE_*`, and `--use-port=*` without matching `-std=c++23`).
- `.vscode/` — `settings.json` (cSpell words, `clangd.arguments` with `--query-driver=**/*`).
- `src/`
  - `main.cpp` — Entry point; constructs `Context`, registers `Window` instances on `App`, runs `App::Loop()`.
  - `app.h`, `app.cpp` — GLFW/OpenGL/WebGL window setup, Dear ImGui initialization (`DockSpaceOverViewport`), embedded font loading, main loop.
  - `context.h`, `context.cpp` — Shared application state (`Context`, `TextEditor`, fonts, async compilation future).
  - `windows/` — UI panels inheriting `rvsim::Window`:
    - `window.h`, `window.cpp`
    - `editor_window.h`, `editor.cpp`
    - `output_window.h`, `output_window.cpp`
    - `demo_window.h`, `demo_window.cpp`
  - `simulator/` — `simulator.h`, `simulator.cpp` (currently a stub; place new simulator components inside `namespace rvsim`).
- `assets/fonts/` — `NotoSans-Regular.ttf`, `NotoSansMono-Regular.ttf` (embedded into the binary at build time).
- `external/` — Vendored third-party dependencies (`text_editor/TextEditor.{h,cpp}`, `emscripten_mainloop_stub.h`). **Never edit files in `external/` directly** unless explicitly asked.

## 3. Build, Run & Tooling Commands

```bash
# 1. Native build (Linux / macOS / Windows via Ninja; dependencies fetched via CPM.cmake)
cmake --preset native-release
cmake --build --preset native-release
./build/native-release/rvsim

# 2. Web build via Emscripten SDK (with $EMSDK set via source emsdk_env.sh)
cmake --preset web
cmake --build --preset web

#    Or with distro-packaged Emscripten without $EMSDK (e.g., Arch /usr/lib/emscripten)
emcmake cmake --preset web-emcmake
cmake --build --preset web-emcmake

# 3. Symlink compile_commands.json at repo root for Serena / clangd tools (gitignored)
ln -sf build/native-release/compile_commands.json compile_commands.json
#    (Or build/web/compile_commands.json when inspecting Emscripten-only code)

# 4. Serve Web build locally with COOP/COEP headers for -pthread
emrun build/web/index.html
# Headless server for browser/DevTools inspection:
emrun --no_browser --port 8080 build/web/index.html

# 5. Format modified C++ sources
clang-format -i src/<modified-files>
```

> **Note on `clangd` / Serena:** When pointing `compile_commands.json` at `build/web/compile_commands.json` (`em++`), `clangd` needs `--query-driver` (e.g., `--query-driver="/usr/lib/emscripten/em*"` or `--query-driver=**/*` as in `.vscode/settings.json`) to resolve Emscripten sysroot headers.

## 4. Code Conventions & Technical Constraints

- **Language & warnings**: Strict C++23 (`<print>`, `<ranges>`, `CMAKE_CXX_EXTENSIONS OFF`), compiled with `-Wall -Wextra` on GCC/Clang/Emscripten and `/W4` on MSVC on `rvsim` (third-party headers marked `SYSTEM`). Requires GCC 14+, Clang 18+ (`libc++`), Xcode 16.3+, Visual Studio 2022 17.7+ (MSVC 19.37+), or Emscripten. Keep builds free of warnings.
- **No exceptions**: Emscripten builds default to `-sDISABLE_EXCEPTION_CATCHING=1`. Do not use `throw` / `try` / `catch` for control flow or error reporting; use `std::expected`, `std::optional`, or explicit error structs/enums.
- **Emscripten `-pthread` & thread safety**: WebAssembly pthreads use `-sPTHREAD_POOL_SIZE=2` and `-sALLOW_MEMORY_GROWTH=1`, and require COOP/COEP HTTP headers (`emrun` sets them automatically; `web/coi-serviceworker.js` enables them on static hosts such as GitHub Pages under HTTPS/`localhost`). Keep all Dear ImGui, `TextEditor`, and OpenGL calls strictly on the UI thread and synchronize any shared state touched by worker threads. *(Note: the existing placeholder `Context::StartCompilation()` accesses `text_editor_` from a `std::async` worker — replace that pattern with snapshot-in / result-out synchronization when implementing real assembly/simulation.)*
- **C++ style**: Follow Google C++ Style Guide (`.clang-format`):
  - Put project symbols in `namespace rvsim` (align `src/simulator/` with `namespace rvsim` when expanding the stub).
  - Use `#pragma once` header guards.
  - `PascalCase` for classes, structs, and methods; `snake_case` for local variables and simple accessors (`clear_color()`); trailing `_` on private member variables (`context_`, `window_`).
- **Dear ImGui conventions**:
  - Under `__EMSCRIPTEN__`, `io.IniFilename` is set to `nullptr` (no filesystem INI persistence).
  - Core UI fonts (`assets/fonts/*.ttf`) are embedded at build time into `generated/embedded_fonts.{h,cpp}` and loaded via `AddFontFromMemoryTTF(..., 0.0f, &font_cfg)` with `font_cfg.FontDataOwnedByAtlas = false` (no `--preload-file`).
  - Add new UI panels by subclassing `rvsim::Window` (`Render()` override) and registering them in `main.cpp` via `App::RegisterWindow(...)`.
- **CMake structure**: `CMakeLists.txt` supports both native desktop (`OpenGL::GL`, `Threads::Threads`, CPM `glfw`) and Emscripten (`contrib.glfw3`, `-pthread`) via `rvsim_platform` and `CMakePresets.json`, and uses `file(GLOB_RECURSE SOURCES CONFIGURE_DEPENDS "src/*.cpp")`. When adding native host unit tests for the simulator, split `src/simulator/` into an Emscripten-independent static library target so tests can build and run on the host without `EMSCRIPTEN`.
- **Git & commit conventions**:
  - **Commit very atomically**: Keep every commit small, single-purpose, and logically self-contained. Separate distinct concerns (e.g., header fixes, standalone bug fixes, build scripts, build migration, presets/IDE config, CI workflows, and documentation) into individual commits instead of bundling unrelated edits.
  - **Conventional Commits**: Use concise imperative subjects with Conventional Commit prefixes (`feat:`, `fix:`, `build:`, `ci:`, `refactor:`, `docs:`, `chore:`, with optional scopes such as `feat(web):`).
  - Never push commits to a remote unless explicitly asked by the user.

## 5. Installed Agent Skills (`.agents/skills/`)

Activate the relevant skill before non-trivial work in its domain:

- `imgui-ui-ux-engineering` — Dear ImGui dockspace layout, widget IDs, tables/`ImGuiListClipper`, DPI scaling, and UI reviews.
- `assembly-riscv` — RV32/RV64 ISA instructions, psABI calling conventions, extensions, and RISC-V assembly patterns.
- `elf-inspection` — ELF32/ELF64 headers, sections, program segments, symbol tables, and binary loading.
- `interpreters` — Bytecode/instruction decode and dispatch loop design, VM architecture, and execution engines.
- `cmake` — Target-first CMake refactoring, native test targets, and cross-compilation setups.
- `cpp-coding-standards` — Modern C++ Core Guidelines, RAII, ownership, and type safety.
- `cpp-testing` — GoogleTest/CTest and sanitizer setup when introducing native unit tests.

## 6. Configured MCP Servers & Usage Rules

Project MCP servers are configured in `.agents/plugins/rvsim-tools/mcp_config.json` (Antigravity workspace plugin) and mirrored alongside global tools in `.mcp.json` (for Claude Code / Cursor / VS Code). **Use these MCP tools proactively instead of guessing or relying on brittle manual workarounds:**

- **RISC-V encodings, assembly, and compiler test vectors → `compiler-explorer`** (`https://compiler-explorer.com/mcp`):
  - Whenever you need to verify RV32/RV64 instruction encodings, ABI output, or assembly test fixtures (especially since no local `riscv64-unknown-elf-gcc` is installed), call `compile` / `list_compilers` / `lookup_asm_instruction` on Godbolt instead of hand-encoding instructions from memory.
- **Third-party repo architecture & internals → `deepwiki`** (`https://mcp.deepwiki.com/mcp`):
  - Before guessing internal behavior, backend APIs, or ISA specs for public repositories (such as `ocornut/imgui`, `emscripten-core/emscripten`, or `riscv/riscv-isa-manual`), query `read_wiki_structure`, `read_wiki_contents`, or `ask_wiki_question`.
- **Library API references → `context7`** (global Antigravity plugin, mirrored in `.mcp.json`):
  - Before writing unfamiliar library calls or CMake/toolchain flags, call `resolve-library-id` and `query-docs` to verify current API signatures.
- **Cross-file C++ symbol lookup & semantic refactoring → `serena`** (`uvx --from serena-agent serena start-mcp-server --context ide --project-from-cwd`):
  - Prefer `serena` (`initial_instructions`, then `serena_repl`) over text-only grep/replace when tracing types, references, or refactoring symbols across `src/`. Requires `compile_commands.json` at the repo root and `--query-driver` when pointing at Emscripten headers.
- **Live UI, WebGL canvas & runtime verification → `chrome-devtools`** (global Antigravity plugin, mirrored in `.mcp.json`):
  - After changing `src/windows/`, `app.*`, `shell_minimal.html`, or Emscripten flags, build (`cmake --build --preset web-emcmake` or `web`), serve with `emrun --no_browser --port 8080 build/web/index.html`, and verify rendering/console output via Chrome DevTools.
