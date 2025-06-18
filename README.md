# Playwright MCP Server - NixOS Flake

A comprehensive NixOS Flake development environment for the Playwright MCP (Model Context Protocol) server with full Chrome and Firefox support, including persistent browser profiles.

## Features

- ✅ **Complete Playwright MCP Server Setup**: Based on Microsoft's official implementation
- ✅ **Multi-Browser Support**: Both Chrome/Chromium and Firefox browsers included
- ✅ **Profile Persistence**: Maintains browser profiles between sessions
- ✅ **Desktop Profile Integration**: Can import existing Chrome/Firefox profiles from your desktop
- ✅ **NixOS Integration**: Properly configured for NixOS with all dependencies
- ✅ **Development Environment**: Ready-to-use development shell with all tools
- ✅ **AI Agent Compatible**: Can be added as a URL to development environments for AI agents

## Quick Start

### Using with direnv (Recommended)

1. Clone this repository or copy the `flake.nix` to your project
2. Enable direnv: `direnv allow`
3. The environment will automatically activate when you enter the directory

### Manual activation

```bash
# Enter the development shell
nix develop

# Or run the MCP server directly
nix run
```

## Usage

### Running the MCP Server

```bash
# Basic usage (headed mode, persistent profiles)
playwright-mcp-wrapped

# Headless mode
playwright-mcp-wrapped --headless

# Specify browser
playwright-mcp-wrapped --browser firefox

# With custom configuration
playwright-mcp-wrapped --config /path/to/config.json

# Server mode (for remote connections)
playwright-mcp-wrapped --port 8931
```

### Setting Up Browser Profiles

To use your existing desktop browser profiles:

```bash
# Run the profile setup script
nix run .#setup-profiles
```

This will copy your existing Chrome/Chromium and Firefox profiles to the Playwright MCP directories:
- Chrome: `~/.local/share/playwright-mcp/chrome-profile`
- Firefox: `~/.local/share/playwright-mcp/firefox-profile`

### Configuration

The flake includes a default configuration file that can be customized. Key features:

- **Browser Support**: Both Chromium and Firefox
- **Profile Persistence**: Profiles are saved between sessions
- **Headed Mode**: Browser windows are visible by default
- **Full Capabilities**: All MCP capabilities enabled (tabs, PDF, history, wait, files, install, testing)

### Using in AI Development Environments

Add this flake as a development environment URL:

```json
{
  "devEnvironments": {
    "playwright-mcp": {
      "url": "github:benjaminkitt/nix-playwright-mcp"
    }
  }
}
```

Or for Claude Desktop MCP configuration:

```json
{
  "mcpServers": {
    "playwright": {
      "command": "nix",
      "args": ["run", "github:benjaminkitt/nix-playwright-mcp"]
    }
  }
}
```

## Architecture

This flake provides:

1. **Custom Playwright MCP Package**: Wraps Microsoft's Playwright MCP server with NixOS-specific configurations
2. **Browser Integration**: Properly configured Chromium and Firefox with Playwright support
3. **Profile Management**: Scripts to handle browser profile persistence and desktop integration
4. **Development Environment**: Complete shell with all dependencies and helpful environment variables

## Browser Profile Locations

### Default Locations
- **Chrome/Chromium Profile**: `~/.local/share/playwright-mcp/chrome-profile`
- **Firefox Profile**: `~/.local/share/playwright-mcp/firefox-profile`

### Desktop Profile Sources
The setup script will look for existing profiles in:
- **Chrome**: `~/.config/google-chrome`
- **Chromium**: `~/.config/chromium`  
- **Firefox**: `~/.mozilla/firefox` (default profile)

## Configuration Options

The MCP server supports extensive configuration through command-line arguments:

```bash
--allowed-origins      # Semicolon-separated allowed origins
--blocked-origins      # Semicolon-separated blocked origins
--browser             # Browser to use: chrome, firefox, webkit, msedge
--headless            # Run in headless mode
--user-data-dir       # Custom profile directory
--viewport-size       # Browser viewport size (e.g., "1920,1080")
--device              # Device to emulate (e.g., "iPhone 15")
--proxy-server        # Proxy server configuration
--storage-state       # Path to storage state file
--isolated            # Use isolated (non-persistent) profiles
--vision              # Use screenshot mode instead of accessibility snapshots
--config              # Path to JSON configuration file
```

## Troubleshooting

### Browser Not Found
If you get browser not found errors:
```bash
nix run .#playwright-mcp -- --browser chromium
# or
export PLAYWRIGHT_BROWSERS_PATH=$(nix-build '<nixpkgs>' -A playwright-driver.browsers --no-out-link)
```

### Profile Issues
If browser profiles aren't working:
```bash
# Reset profiles
rm -rf ~/.local/share/playwright-mcp/
nix run .#setup-profiles
```

### Permission Issues
Ensure the profile directories are writable:
```bash
chmod -R u+w ~/.local/share/playwright-mcp/
```

## Contributing

This flake is designed to be easily extensible. Key areas for contribution:

1. **Browser Support**: Additional browser configurations
2. **Profile Management**: Enhanced profile import/export capabilities  
3. **Configuration**: More sophisticated configuration management
4. **Integration**: Better integration with various AI development environments

## License

This project follows the same license as the underlying Playwright MCP server (Apache 2.0).

## Related Projects

- [Microsoft Playwright MCP](https://github.com/microsoft/playwright-mcp) - The upstream MCP server
- [natsukium/mcp-servers-nix](https://github.com/natsukium/mcp-servers-nix) - Nix framework for MCP servers
- [akirak/nix-playwright-mcp](https://github.com/akirak/nix-playwright-mcp) - Alternative Nix wrapper for Playwright MCP
