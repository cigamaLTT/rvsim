# AGENTS.md

Guidelines for coding agents working in `rvsim`.

## 1. Project Overview & Target Scope

`rvsim` is a browser-based RISC-V simulator written in **C++23**, compiled to **WebAssembly** via **Emscripten**, with a **Dear ImGui** (`docking` branch) + GLFW + OpenGL3/WebGL UI.

- **Target simulator scope**: Full-featured **RV32/RV64** simulator supporting both **ELF binaries** and **assembly input**.
- **Core architectural boundary**: Keep `src/simulator/` (ISA decode/execute, memory, CSRs, ELF loader, assembler) decoupled from ImGui, GLFW, and Emscripten APIs so the simulator core remains portable and unit-testable on a native host compiler.

## 2. Repository Layout

- `CMakeLists.txt` — Emscripten build definition (`rvsim` executable outputting `build/web/index.html`, plus `imgui_lib` and `imgui_text_editor` static libraries).
- `shell_minimal.html` — Custom Emscripten HTML shell (`#canvas`).
- `.clang-format` — Formatting rules (`BasedOnStyle: Google`).
- `.clangd` — `clangd` configuration (`CompilationDatabase: build`, strips unsupported Emscripten flags).
- `.vscode/` — `settings.json` (cSpell words, `clangd.arguments` with `--query-driver=**/*`) and `cmake-kits.json`.
- `src/`
  - `main.cpp` — Entry point; constructs `Context`, registers `Window` instances on `App`, runs `App::Loop()`.
  - `app.h`, `app.cpp` — GLFW/WebGL window setup, Dear ImGui initialization (`DockSpaceOverViewport`), main loop.
  - `context.h`, `context.cpp` — Shared application state (`Context`, `TextEditor`, fonts, async compilation future).
  - `windows/` — UI panels inheriting `rvsim::Window`:
    - `window.h`, `window.cpp`
    - `editor_window.h`, `editor.cpp`
    - `output_window.h`, `output_window.cpp`
    - `demo_window.h`, `demo_window.cpp`
  - `simulator/` — `simulator.h`, `simulator.cpp` (currently a stub; place new simulator components inside `namespace rvsim`).
- `assets/fonts/` — `NotoSans-Regular.ttf`, `NotoSansMono-Regular.ttf` (preloaded at `/assets/fonts/`).
- `external/` — Third-party dependencies (`imgui` submodule on `docking`, `text_editor/TextEditor.{h,cpp}`, `emscripten_mainloop_stub.h`). **Never edit files in `external/` directly** unless explicitly asked.

## 3. Build, Run & Tooling Commands

```bash
# 1. Initialize external/imgui submodule (first clone)
git submodule update --init --recursive

# 2. Configure with Emscripten (exports build/compile_commands.json)
emcmake cmake -B build

# 3. Symlink compile_commands.json at repo root for Serena / clangd tools (gitignored)
ln -sf build/compile_commands.json compile_commands.json

# 4. Build WASM output -> build/web/index.{html,js,wasm,data}
cmake --build build

# 5. Serve locally with COOP/COEP headers for -pthread
emrun build/web/index.html
# Headless server for browser/DevTools inspection:
emrun --no_browser --port 8080 build/web/index.html

# 6. Format modified C++ sources
clang-format -i src/<modified-files>
```

> **Note on `clangd` / Serena:** Because `compile_commands.json` uses `em++`, `clangd` needs `--query-driver` (e.g., `--query-driver="/usr/lib/emscripten/em*"` or `--query-driver=**/*` as in `.vscode/settings.json`) to resolve Emscripten sysroot and `GLFW/glfw3.h` headers.

## 4. Code Conventions & Technical Constraints

- **Language & warnings**: C++23 (`CMAKE_CXX_EXTENSIONS OFF`), compiled with `-Os -Wall -Wextra`. Keep builds free of warnings.
- **No exceptions**: Emscripten builds with `-sDISABLE_EXCEPTION_CATCHING=1`. Do not use `throw` / `try` / `catch` for control flow or error reporting; use `std::expected`, `std::optional`, or explicit error structs/enums.
- **Emscripten `-pthread` & thread safety**: WebAssembly pthreads require COOP/COEP HTTP headers (`emrun` sets them automatically). Keep all Dear ImGui, `TextEditor`, and OpenGL calls strictly on the UI thread and synchronize any shared state touched by worker threads. *(Note: the existing placeholder `Context::StartCompilation()` accesses `text_editor_` from a `std::async` worker — replace that pattern with snapshot-in / result-out synchronization when implementing real assembly/simulation.)*
- **C++ style**: Follow Google C++ Style Guide (`.clang-format`):
  - Put project symbols in `namespace rvsim` (align `src/simulator/` with `namespace rvsim` when expanding the stub).
  - Use `#pragma once` header guards.
  - `PascalCase` for classes, structs, and methods; `snake_case` for local variables and simple accessors (`clear_color()`); trailing `_` on private member variables (`context_`, `window_`).
- **Dear ImGui conventions**:
  - Under `__EMSCRIPTEN__`, `io.IniFilename` is set to `nullptr` (no filesystem INI persistence).
  - Fonts are loaded from `/assets/fonts/...` via Emscripten `--preload-file assets@assets/`.
  - Add new UI panels by subclassing `rvsim::Window` (`Render()` override) and registering them in `main.cpp` via `App::RegisterWindow(...)`.
- **CMake structure**: `CMakeLists.txt` currently gates on `if(NOT EMSCRIPTEN)` and uses `file(GLOB_RECURSE SOURCES CONFIGURE_DEPENDS "src/*.cpp")`. When adding native host unit tests for the simulator, split `src/simulator/` into an Emscripten-independent static library target so tests can build and run on the host without `EMSCRIPTEN`.

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
  - Prefer `serena` (`initial_instructions`, then `serena_repl`) over text-only grep/replace when tracing types, references, or refactoring symbols across `src/`. Requires `compile_commands.json` at the repo root and `--query-driver` for Emscripten headers.
- **Live UI, WebGL canvas & runtime verification → `chrome-devtools`** (global Antigravity plugin, mirrored in `.mcp.json`):
  - After changing `src/windows/`, `app.*`, `shell_minimal.html`, or Emscripten flags, build (`cmake --build build`), serve with `emrun --no_browser --port 8080 build/web/index.html`, and verify rendering/console output via Chrome DevTools.
