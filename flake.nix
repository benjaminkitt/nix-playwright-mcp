
{
  description = "NixOS Flake development environment for Playwright MCP server with Chrome and Firefox support";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    # Include the mcp-servers-nix for additional MCP server utilities
    mcp-servers-nix = {
      url = "github:natsukium/mcp-servers-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, mcp-servers-nix }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        # Instead of building from source, use npx to run the latest version
        # This avoids the complexity of keeping hashes up to date
        playwright-mcp-wrapper = pkgs.writeShellScript "playwright-mcp-wrapped" ''
          #!/usr/bin/env bash
          set -euo pipefail

          # Set up environment variables for browser paths and Playwright
          export PLAYWRIGHT_BROWSERS_PATH="${pkgs.playwright-driver.browsers}"
          export PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS=true
          export CHROME_EXECUTABLE_PATH="${pkgs.chromium}/bin/chromium"
          export FIREFOX_EXECUTABLE_PATH="${pkgs.firefox}/bin/firefox"

          # Set up persistent profile directories
          export MCP_CHROME_PROFILE_DIR="$HOME/.local/share/playwright-mcp/chrome-profile"
          export MCP_FIREFOX_PROFILE_DIR="$HOME/.local/share/playwright-mcp/firefox-profile"
          mkdir -p "$MCP_CHROME_PROFILE_DIR" "$MCP_FIREFOX_PROFILE_DIR"

          # Parse arguments to detect browser choice and set appropriate executable
          BROWSER_ARG=""
          USER_DATA_ARG=""
          EXEC_PATH_ARG=""

          for arg in "$@"; do
            case $arg in
              --browser=chrome|--browser=chromium)
                EXEC_PATH_ARG="--executable-path=${pkgs.chromium}/bin/chromium"
                if [[ "$arg" == "--browser=chrome" ]]; then
                  USER_DATA_ARG="--user-data-dir=$MCP_CHROME_PROFILE_DIR"
                fi
                ;;
              --browser=firefox)
                EXEC_PATH_ARG="--executable-path=${pkgs.firefox}/bin/firefox"
                USER_DATA_ARG="--user-data-dir=$MCP_FIREFOX_PROFILE_DIR"
                ;;
            esac
          done

          # If no browser specified, default to chromium with chrome profile
          if [[ -z "$EXEC_PATH_ARG" ]]; then
            EXEC_PATH_ARG="--executable-path=${pkgs.chromium}/bin/chromium"
            USER_DATA_ARG="--user-data-dir=$MCP_CHROME_PROFILE_DIR"
          fi

          # Run the playwright MCP server
          exec ${pkgs.nodejs_22}/bin/npx @playwright/mcp@latest             $EXEC_PATH_ARG             $USER_DATA_ARG             "$@"
        '';

        # Configuration file for the MCP server
        mcp-config = pkgs.writeText "playwright-mcp-config.json" (builtins.toJSON {
          browser = {
            # Support both Chrome and Firefox
            browserName = "chromium"; # Default to Chromium, can be overridden
            isolated = false; # Use persistent profiles
            userDataDir = null; # Will be set by wrapper script
            launchOptions = {
              headless = false; # Allow headed mode by default
              executablePath = null; # Will be set by wrapper script
              args = [
                "--no-sandbox"
                "--disable-dev-shm-usage"
                "--disable-gpu"
              ];
            };
            contextOptions = {
              viewport = {
                width = 1920;
                height = 1080;
              };
              locale = "en-US";
              timezoneId = "America/New_York";
            };
          };
          server = {
            host = "localhost";
            port = 8931;
          };
          capabilities = [
            "core"
            "tabs"
            "pdf"
            "history"
            "wait"
            "files"
            "install"
            "testing"
          ];
          vision = false; # Use accessibility snapshots by default
          outputDir = "/tmp/playwright-mcp-output";
          network = {
            allowedOrigins = []; # Allow all origins by default
            blockedOrigins = []; # No blocked origins by default
          };
        });

        # Helper script to set up browser profiles from existing desktop profiles
        profile-setup-script = pkgs.writeShellScript "setup-browser-profiles" ''
          #!/usr/bin/env bash
          set -euo pipefail

          CHROME_PROFILE_DIR="$HOME/.local/share/playwright-mcp/chrome-profile"
          FIREFOX_PROFILE_DIR="$HOME/.local/share/playwright-mcp/firefox-profile"

          echo "🔧 Setting up Playwright MCP browser profiles..."

          # Create profile directories
          mkdir -p "$CHROME_PROFILE_DIR" "$FIREFOX_PROFILE_DIR"

          # Function to safely copy directory contents
          safe_copy() {
            local src="$1"
            local dest="$2"
            local name="$3"

            if [[ -d "$src" ]]; then
              echo "📁 Found existing $name profile, copying to Playwright MCP..."
              # Use rsync if available, otherwise cp
              if command -v rsync >/dev/null 2>&1; then
                rsync -av --exclude="lock" --exclude="*.lock" "$src/" "$dest/" 2>/dev/null || true
              else
                cp -r "$src/"* "$dest/" 2>/dev/null || true
              fi
              echo "✅ $name profile copied successfully"
            else
              echo "ℹ️  No existing $name profile found at $src"
            fi
          }

          # Try to copy from existing Chrome/Chromium profiles
          safe_copy "$HOME/.config/google-chrome/Default" "$CHROME_PROFILE_DIR" "Chrome"
          if [[ ! -d "$CHROME_PROFILE_DIR/Default" ]]; then
            safe_copy "$HOME/.config/chromium/Default" "$CHROME_PROFILE_DIR" "Chromium"
          fi

          # Try to copy from existing Firefox profiles
          if [[ -f "$HOME/.mozilla/firefox/profiles.ini" ]]; then
            echo "📁 Found Firefox profiles.ini, looking for default profile..."
            # Find the default profile
            DEFAULT_PROFILE=$(grep -E "Default=.*\.default" "$HOME/.mozilla/firefox/profiles.ini" 2>/dev/null | cut -d'=' -f2 || echo "")
            if [[ -z "$DEFAULT_PROFILE" ]]; then
              # Try to find any .default profile
              DEFAULT_PROFILE=$(find "$HOME/.mozilla/firefox" -maxdepth 1 -name "*.default*" -type d | head -1 | xargs basename 2>/dev/null || echo "")
            fi

            if [[ -n "$DEFAULT_PROFILE" && -d "$HOME/.mozilla/firefox/$DEFAULT_PROFILE" ]]; then
              safe_copy "$HOME/.mozilla/firefox/$DEFAULT_PROFILE" "$FIREFOX_PROFILE_DIR" "Firefox"
            else
              echo "ℹ️  Could not find default Firefox profile"
            fi
          else
            echo "ℹ️  No Firefox profiles.ini found"
          fi

          echo ""
          echo "🎉 Browser profile setup complete!"
          echo "📍 Profile locations:"
          echo "   Chrome/Chromium: $CHROME_PROFILE_DIR"
          echo "   Firefox: $FIREFOX_PROFILE_DIR"
          echo ""
          echo "💡 You can now run the MCP server with persistent profiles."
        '';

        # Development shell with all dependencies
        devShell = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Core dependencies
            nodejs_22

            # Browsers with Playwright support
            playwright-driver.browsers
            chromium
            firefox

            # Additional useful tools
            jq
            curl
            rsync  # For better profile copying

            # Development tools
            nixpkgs-fmt  # For formatting Nix files
          ];

          shellHook = ''
            echo "🎭 Playwright MCP Development Environment"
            echo "======================================="
            echo ""
            echo "📦 Available packages:"
            echo "  Node.js: $(${pkgs.nodejs_22}/bin/node --version)"
            echo "  Chromium: ${pkgs.chromium}/bin/chromium"
            echo "  Firefox: ${pkgs.firefox}/bin/firefox"
            echo ""
            echo "🚀 Available commands:"
            echo "  playwright-mcp-wrapped --help     # Run Playwright MCP server"
            echo "  ${profile-setup-script}           # Set up browser profiles"
            echo "  ./mcp.sh help                     # Helper script commands"
            echo ""
            echo "🌍 Environment variables:"
            echo "  PLAYWRIGHT_BROWSERS_PATH=${pkgs.playwright-driver.browsers}"
            echo "  PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS=true"
            echo "  CHROME_EXECUTABLE_PATH=${pkgs.chromium}/bin/chromium"
            echo "  FIREFOX_EXECUTABLE_PATH=${pkgs.firefox}/bin/firefox"
            echo ""
            echo "📁 Profile directories:"
            echo "  Chrome: $HOME/.local/share/playwright-mcp/chrome-profile"
            echo "  Firefox: $HOME/.local/share/playwright-mcp/firefox-profile"
            echo ""
            echo "⚙️  Configuration file: ${mcp-config}"
            echo ""
            echo "🔗 To use in AI development environments:"
            echo "  Add this URL: github:benjaminkitt/playwright-mcp-nix"
            echo ""

            # Set up environment variables
            export PLAYWRIGHT_BROWSERS_PATH="${pkgs.playwright-driver.browsers}"
            export PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS=true
            export CHROME_EXECUTABLE_PATH="${pkgs.chromium}/bin/chromium"
            export FIREFOX_EXECUTABLE_PATH="${pkgs.firefox}/bin/firefox"
            export MCP_CONFIG_FILE="${mcp-config}"

            # Ensure profile directories exist
            mkdir -p "$HOME/.local/share/playwright-mcp/chrome-profile"
            mkdir -p "$HOME/.local/share/playwright-mcp/firefox-profile"

            # Ensure output directory exists
            mkdir -p "/tmp/playwright-mcp-output"
          '';
        };

      in {
        # Default development shell
        devShells.default = devShell;

        # Packages exposed by this flake
        packages = {
          default = playwright-mcp-wrapper;
          playwright-mcp-wrapper = playwright-mcp-wrapper;
          mcp-config = mcp-config;
          profile-setup = profile-setup-script;
        };

        # Apps that can be run with `nix run`
        apps = {
          default = {
            type = "app";
            program = "${playwright-mcp-wrapper}";
          };

          playwright-mcp = {
            type = "app";
            program = "${playwright-mcp-wrapper}";
          };

          setup-profiles = {
            type = "app";
            program = "${profile-setup-script}";
          };
        };

        # Formatter for the flake
        formatter = pkgs.nixpkgs-fmt;

        # Additional checks for CI/development
        checks = {
          # Check that the wrapper script is valid
          playwright-mcp-wrapper-check = pkgs.runCommand "playwright-mcp-wrapper-check" {} ''
            ${pkgs.bash}/bin/bash -n ${playwright-mcp-wrapper}
            touch $out
          '';

          # Check that required binaries exist
          binaries-check = pkgs.runCommand "binaries-check" {} ''
            test -x ${pkgs.chromium}/bin/chromium
            test -x ${pkgs.firefox}/bin/firefox
            test -x ${pkgs.nodejs_22}/bin/node
            test -d ${pkgs.playwright-driver.browsers}
            touch $out
          '';
        };
      }
    );
}
