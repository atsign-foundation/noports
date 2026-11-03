# noports_core

## Project Overview

`noports_core` is the foundational Dart library for the **NoPorts** suite. It implements the core logic for secure, decentralized remote access using the **@platform**. This library is consumed by various frontend applications and tools, such as the `sshnoports` CLI and `npt_flutter`.

**Key Features:**
*   **SSH No Ports (SSHNP):** logic for establishing outbound-only, secure SSH connections.
*   **SSH No Ports Daemon (SSHNPD):** logic for the daemon running on the remote device.
*   **Socket Rendezvous (SRV):** logic for the rendezvous point to stitch connections.
*   **Command Utilities:** CLI commands for atsign onboarding and device enrollment
    *   `activate` - CRAM authentication or APKAM enrollment of new devices
    *   `issue-keys` - Generate enrollment OTPs and approve device requests
    *   Exported via `lib/commands.dart` for use in CLI applications
    *   See `lib/src/commands/` for implementation details

## Using the Codebase Cache

**IMPORTANT:** This repository includes a pre-built codebase cache in `.claude-cache/` with comprehensive architectural information. **Always consult the cache first** before exploring source files.

### Cache Location
`.claude-cache/` directory contains indexed information about 95 Dart files, 350+ symbols, and complete architectural documentation.

### Quick Reference Files
*   **`.claude-cache/summary/architecture.json`** - Complete architectural overview, tech stack, all 8 core components
*   **`.claude-cache/content/summaries/sshnp.json`** - SSHNP client component details
*   **`.claude-cache/content/summaries/sshnpd.json`** - SSHNPD daemon component details
*   **`.claude-cache/content/summaries/srvd.json`** - SRVD relay component details
*   **`.claude-cache/content/summaries/patterns.json`** - All design patterns (Channel, Strategy, Mixin, etc.)
*   **`.claude-cache/index/symbols.json`** - Complete symbol index (classes, enums, interfaces, mixins)
*   **`.claude-cache/index/files.json`** - File organization by component
*   **`.claude-cache/context/quick_reference.json`** - Quick start guide and common tasks

### Exploration Hierarchy (MANDATORY)

When working with this codebase, **ALWAYS** follow this order:

1. **PRIMARY: Local Cache Files** (`.claude-cache/` directory)
   - `.claude-cache/summary/architecture.json` - Complete architectural overview
   - `.claude-cache/index/symbols.json` - All symbols (classes, enums, interfaces, mixins)
   - `.claude-cache/content/summaries/*.json` - Component-specific details
   - `.claude-cache/index/files.json` - File organization

2. **SECONDARY: MCP Tools** (only if cache files insufficient)
   - `mcp__claude-cache__get_summary` - Architectural summary
   - `mcp__claude-cache__query_cache` - Query with keywords
   - `mcp__claude-cache__search_cache` - Search by path/symbol/keyword

3. **TERTIARY: Direct File Reading** (only when necessary)
   - Read actual source files only after exhausting cache options
   - Use when implementation details are required
   - Use when cache verification is needed

**DO NOT read source files directly until you've checked the cache.**

### Example Workflow

**Question**: "How does SSHNPD handle connections?"

**Correct approach**:
1. Read `.claude-cache/content/summaries/sshnpd.json` → Get overview of responsibilities
2. Read `.claude-cache/index/symbols.json` → Find SshnpdImpl class location
3. If needed: `mcp__claude-cache__query_cache` with focus "sshnpd,connections"
4. If still needed: Read `lib/src/sshnpd/sshnpd_impl.dart` for implementation

**Incorrect approach**:
1. ❌ Grep for "connection" across all files
2. ❌ Read sshnpd_impl.dart without context

### Maintaining the Cache

The cache is built using the `claude-cache` CLI tool. To regenerate after significant changes:

```bash
# Rebuild the cache
claude-cache build --exclude tests,generated

# Generate summaries
claude-cache summarize

# Check cache status
claude-cache stats
```

## Architecture

The project follows a standard Dart package structure:

*   **`lib/`**: Public API exports.
    *   `sshnp.dart`: Core client interface.
    *   `sshnpd.dart`: Core daemon interface.
    *   `commands.dart`: shared CLI commands.
*   **`lib/src/`**: Internal implementation details.
    *   `sshnp/`: Client implementation (OpenSSH and DartSSH2 variants).
    *   `sshnpd/`: Daemon implementation.
    *   `srvd/`: Server/Rendezvous implementation.
*   **`test/`**: Unit and integration tests organized by component.

## Building and Testing

Since this is a library, it is primarily built as a dependency. However, you can run tests and analysis locally.

### Prerequisites
*   **Dart SDK:** Version `^3.8.0` (as specified in `pubspec.yaml`).

### Commands

*   **Get Dependencies:**
    ```bash
    dart pub get
    ```

*   **Run Tests:**
    ```bash
    dart test
    ```
    To run tests for a specific component:
    ```bash
    dart test test/sshnp
    ```

*   **Analyze Code:**
    ```bash
    dart analyze
    ```

## Development Conventions

*   **Code Style:** Adheres to standard Dart guidelines using `package:lints/recommended.yaml`.
*   **Exports:** Implementation details are hidden in `lib/src/` and exposed via explicit exports in `lib/`.
*   **Logging:** Uses `at_utils` logger and a custom `StreamingLoggingHandler`.
*   **Async/Await:** Heavy usage of `Future` and `Stream` for network operations.
