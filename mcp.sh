#!/usr/bin/env bash
set -euo pipefail

# Playwright MCP Server Helper Script
# This script provides easy commands for common operations

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

show_help() {
    cat << EOF
Playwright MCP Server Helper

Usage: $0 <command> [options]

Commands:
    dev         Enter development shell
    run         Run MCP server (default: headed mode)
    run-headless Run MCP server in headless mode  
    run-firefox Run MCP server with Firefox
    run-server  Run MCP server in server mode (port 8931)
    setup       Set up browser profiles from desktop
    clean       Clean browser profiles and cache
    config      Show configuration locations
    help        Show this help message

Examples:
    $0 dev                    # Enter development environment
    $0 run                    # Run with default settings (Chrome, headed)
    $0 run-firefox            # Run with Firefox browser
    $0 run-headless           # Run in headless mode
    $0 setup                  # Copy desktop browser profiles
    $0 clean                  # Reset browser profiles

Environment Variables:
    MCP_BROWSER              Browser to use (chrome, firefox, webkit)
    MCP_HEADLESS             Run in headless mode (true/false)
    MCP_PORT                 Server port (default: 8931)
    MCP_CONFIG               Path to configuration file

EOF
}

run_mcp() {
    local args=("$@")
    echo "🎭 Starting Playwright MCP Server..."
    nix run . -- "${args[@]}"
}

case "${1:-help}" in
    dev)
        echo "🚀 Entering Playwright MCP development environment..."
        nix develop
        ;;
    run)
        shift
        run_mcp "$@"
        ;;
    run-headless)
        shift
        run_mcp --headless "$@"
        ;;
    run-firefox)
        shift
        run_mcp --browser firefox "$@"
        ;;
    run-server)
        shift
        run_mcp --port "${MCP_PORT:-8931}" "$@"
        ;;
    setup)
        echo "🔧 Setting up browser profiles..."
        nix run .#setup-profiles
        ;;
    clean)
        echo "🧹 Cleaning browser profiles and cache..."
        rm -rf "$HOME/.local/share/playwright-mcp/"
        rm -rf "/tmp/playwright-mcp-output"
        echo "Cleaned up successfully!"
        ;;
    config)
        echo "📁 Configuration locations:"
        echo "  Chrome profile: $HOME/.local/share/playwright-mcp/chrome-profile"
        echo "  Firefox profile: $HOME/.local/share/playwright-mcp/firefox-profile"
        echo "  Output directory: /tmp/playwright-mcp-output"
        echo "  Example config: $SCRIPT_DIR/example-config.json"
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo "❌ Unknown command: $1"
        echo "Run '$0 help' for usage information."
        exit 1
        ;;
esac
