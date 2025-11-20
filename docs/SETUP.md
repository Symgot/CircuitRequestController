# CircuitRequestController - Setup Guide

This guide provides detailed instructions for setting up the development environment for the CircuitRequestController mod.

## Table of Contents

1. [Quick Start](#quick-start)
2. [Prerequisites](#prerequisites)
3. [Development Setup](#development-setup)
4. [VS Code Configuration](#vs-code-configuration)
5. [Testing](#testing)
6. [Building for Release](#building-for-release)
7. [Troubleshooting](#troubleshooting)

## Quick Start

For developers who want to get started quickly:

```bash
# Clone the repository
git clone https://github.com/Symgot/CircuitRequestController.git
cd CircuitRequestController

# Extract flib for development
unzip flib_0.16.5.zip

# Open in VS Code
code .

# Press F5 to start debugging
```

## Prerequisites

### Required Software

1. **Factorio 2.0 or higher**
   - Download from [factorio.com](https://www.factorio.com/)
   - Or install via Steam

2. **Visual Studio Code**
   - Download from [code.visualstudio.com](https://code.visualstudio.com/)

3. **Factorio Mod Debug Extension**
   - Install from VS Code marketplace: [Factorio Mod Debug](https://marketplace.visualstudio.com/items?itemName=justarandomgeek.factoriomod-debug)
   - Or search for "Factorio Mod Debug" in VS Code extensions

### Optional Software

- **Git** - For version control
- **Lua Language Server** - For better code completion and diagnostics

## Development Setup

### 1. Set Factorio Path

The Factorio Mod Debug extension needs to know where Factorio is installed.

#### Windows

Open PowerShell and run:
```powershell
[System.Environment]::SetEnvironmentVariable("FACTORIO_PATH", "C:\Program Files\Steam\steamapps\common\Factorio", "User")
```

Or for portable installation:
```powershell
[System.Environment]::SetEnvironmentVariable("FACTORIO_PATH", "C:\Factorio", "User")
```

#### Linux

Add to your `~/.bashrc` or `~/.zshrc`:
```bash
export FACTORIO_PATH="/path/to/factorio"
```

Common locations:
- Steam: `~/.steam/steam/steamapps/common/Factorio`
- Manual install: `~/factorio`

Then reload your shell:
```bash
source ~/.bashrc
```

#### macOS

Add to your `~/.zshrc`:
```bash
export FACTORIO_PATH="/Applications/factorio.app/Contents"
```

Then reload your shell:
```bash
source ~/.zshrc
```

### 2. Extract flib Library

The flib library is included in the repository as `flib_0.16.5.zip`. Extract it for development:

```bash
unzip flib_0.16.5.zip
```

This creates a `flib_0.16.5/` directory which is git-ignored and used only during development.

**Note**: When the mod is released, flib will be downloaded automatically as a dependency from the Factorio mod portal.

### 3. Verify Setup

Check that everything is configured correctly:

1. Open the project in VS Code
2. Check the bottom-left corner for Factorio version indicator
3. Press F5 to start debugging
4. Factorio should launch with the debugger attached

## VS Code Configuration

The project includes pre-configured VS Code settings:

### Launch Configurations (.vscode/launch.json)

Three debug configurations are available:

1. **Factorio Mod Debug** - Full debugging with control and data stages
2. **Factorio Mod Debug (Profile)** - Performance profiling mode
3. **Factorio Mod Debug (Data Stage Only)** - Only debug data.lua

### Settings (.vscode/settings.json)

Configured for:
- Lua 5.2 runtime (Factorio uses Lua 5.2)
- Factorio global variables
- Proper code formatting

### Tasks (.vscode/tasks.json)

Available tasks (Ctrl+Shift+P → "Tasks: Run Task"):

- **Extract flib** - Extracts flib_0.16.5.zip for development
- **Clean flib** - Removes the extracted flib directory
- **Package Mod** - Creates a release zip file

## Testing

### Manual Testing

1. Start Factorio with debugging (F5)
2. Create a new game or load a save
3. Follow the test cases in [TESTING.md](TESTING.md)

### Automated Testing

The repository includes a logic verification script:

```bash
lua5.2 /tmp/verify_logic.lua
```

This runs unit tests on the core module logic.

### Setting Breakpoints

1. Open a `.lua` file
2. Click in the left margin to set a breakpoint (red dot appears)
3. Start debugging (F5)
4. The debugger will pause when the breakpoint is hit

Useful breakpoints:
- `circuit-request-controller.lua:310` - Controller processing
- `circuit-request-controller.lua:186` - Signal update
- `circuit-request-controller.lua:840` - GUI interaction

### Debug Console

When paused at a breakpoint, use the Debug Console to:
- Evaluate Lua expressions
- Inspect variables
- Call functions

Example:
```lua
storage.circuit_controllers
game.tick
```

## Building for Release

### Manual Build

Use the VS Code task:
1. Ctrl+Shift+P → "Tasks: Run Task"
2. Select "Package Mod"
3. Find the zip file in the parent directory

### GitHub Actions

The repository includes a GitHub Actions workflow for automated releases:

1. Go to the "Actions" tab
2. Select "Create Release" workflow
3. Click "Run workflow"

The workflow will:
- Read version from `info.json`
- Create a properly structured zip file
- Upload as a GitHub release
- Exclude development files (flib_0.16.5/, .vscode/, etc.)

## Troubleshooting

### Factorio Won't Launch

**Problem**: Pressing F5 doesn't start Factorio

**Solutions**:
1. Check that `FACTORIO_PATH` is set correctly:
   ```bash
   echo $FACTORIO_PATH
   ```
2. Restart VS Code after setting the environment variable
3. Check VS Code output panel for error messages

### Debugger Won't Attach

**Problem**: Factorio launches but debugger doesn't work

**Solutions**:
1. Ensure Factorio Mod Debug extension is installed
2. Check that the mod is enabled in Factorio's mod list
3. Look for errors in the Factorio console (F4 → show_debug_info)

### Module Not Found Errors

**Problem**: Lua errors about missing modules

**Solutions**:
1. Ensure flib is extracted: `ls flib_0.16.5/`
2. Re-extract if needed: `unzip -o flib_0.16.5.zip`
3. Check that the mod directory structure is correct

### Performance Issues

**Problem**: Game runs slowly with debugger

**Solutions**:
1. Use "Profile" mode instead of "Debug" mode
2. Remove breakpoints you don't need
3. Disable "hookLog" in launch.json if not needed

### flib Not Found in Release

**Problem**: Mod doesn't work when installed from release

**Solutions**:
1. Ensure flib is installed from the mod portal
2. Check `info.json` has `"? flib >= 0.16.5"` in dependencies
3. Verify flib is enabled in Factorio's mod list

## Additional Resources

- [Factorio Modding Documentation](https://lua-api.factorio.com/)
- [Factorio Mod Debug Extension](https://github.com/justarandomgeek/vscode-factoriomod-debug)
- [flib Documentation](https://mods.factorio.com/mod/flib)
- [Factorio Discord](https://discord.gg/factorio) - #mod-making channel

## Getting Help

If you encounter issues:

1. Check the [TESTING.md](TESTING.md) guide
2. Review Factorio logs in `%APPDATA%/Factorio/factorio-current.log` (Windows) or `~/.factorio/factorio-current.log` (Linux/macOS)
3. Open an issue on GitHub with:
   - Your Factorio version
   - Steps to reproduce the problem
   - Relevant log excerpts
   - Screenshots if applicable
