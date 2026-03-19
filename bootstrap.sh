#!/bin/zsh
# =============================================================================
# mlx-server bootstrap.sh
# Run once on a bare Mac to install all dependencies and configure the service.
# Usage: ./bootstrap.sh
# =============================================================================
set -euo pipefail

REPO_DIR="${0:A:h}"
PYTHON_VERSION="3.11"
PLIST_NAME="com.mlx.server"

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║        MLX Server Bootstrap               ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# -----------------------------------------------------------------------------
# 1. Confirm Apple Silicon
# -----------------------------------------------------------------------------
ARCH=$(uname -m)
if [[ "$ARCH" != "arm64" ]]; then
  echo "ERROR: This setup requires Apple Silicon (arm64). Detected: $ARCH"
  exit 1
fi
echo "✓ Apple Silicon confirmed ($ARCH)"

# -----------------------------------------------------------------------------
# 2. Install Xcode Command Line Tools if missing
# -----------------------------------------------------------------------------
if ! xcode-select -p &>/dev/null; then
  echo "→ Installing Xcode Command Line Tools..."
  xcode-select --install
  echo "  Please complete the Xcode CLT installation, then re-run this script."
  exit 0
else
  echo "✓ Xcode Command Line Tools present"
fi

# -----------------------------------------------------------------------------
# 3. Install Homebrew if missing
# -----------------------------------------------------------------------------
if ! command -v brew &>/dev/null; then
  echo "→ Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
else
  eval "$(/opt/homebrew/bin/brew shellenv)"
  echo "✓ Homebrew present ($(brew --version | head -1))"
fi

# -----------------------------------------------------------------------------
# 4. Install uv if missing
# -----------------------------------------------------------------------------
if ! command -v uv &>/dev/null; then
  echo "→ Installing uv..."
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="$HOME/.local/bin:$PATH"
else
  export PATH="$HOME/.local/bin:$PATH"
  echo "✓ uv present ($(uv --version))"
fi

# -----------------------------------------------------------------------------
# 5. Create virtualenv and install dependencies
# -----------------------------------------------------------------------------
echo "→ Creating Python $PYTHON_VERSION virtualenv..."
cd "$REPO_DIR"
uv venv --python "$PYTHON_VERSION" .venv
echo "→ Installing dependencies from lockfile..."
uv sync
echo "✓ Python environment ready"

# -----------------------------------------------------------------------------
# 6. Verify MLX can see the GPU
# -----------------------------------------------------------------------------
echo "→ Verifying MLX Metal access..."
DEVICE=$(.venv/bin/python -c "import mlx.core as mx; print(mx.default_device())")
if [[ "$DEVICE" != *"gpu"* ]]; then
  echo "ERROR: MLX did not detect GPU. Got: $DEVICE"
  exit 1
fi
echo "✓ MLX GPU confirmed: $DEVICE"

# -----------------------------------------------------------------------------
# 7. HuggingFace token
# -----------------------------------------------------------------------------
echo ""
echo "→ HuggingFace token setup"

EXISTING_TOKEN=$(security find-generic-password -a "huggingface" -s "HF_TOKEN" -w 2>/dev/null || true)
if [[ -n "$EXISTING_TOKEN" ]]; then
  echo "✓ HF_TOKEN already in Keychain — skipping"
else
  echo "  Enter your HuggingFace token (starts with hf_):"
  read -rs HF_TOKEN_INPUT
  if [[ -z "$HF_TOKEN_INPUT" ]]; then
    echo "ERROR: Token cannot be empty"
    exit 1
  fi
  security add-generic-password -a "huggingface" -s "HF_TOKEN" -w "$HF_TOKEN_INPUT"
  echo "✓ HF_TOKEN stored in macOS Keychain"
fi

# -----------------------------------------------------------------------------
# 8. Ensure logs directory exists
# -----------------------------------------------------------------------------
mkdir -p "$REPO_DIR/logs"
echo "✓ Log directory ready"

# -----------------------------------------------------------------------------
# 9. Install launchd service
# -----------------------------------------------------------------------------
PLIST_DST="$HOME/Library/LaunchAgents/$PLIST_NAME.plist"
PLIST_SRC="$REPO_DIR/$PLIST_NAME.plist"

# Bootout existing service if running
if launchctl list | grep -q "$PLIST_NAME" 2>/dev/null; then
  echo "→ Removing existing launchd service..."
  launchctl bootout gui/$(id -u) "$PLIST_DST" 2>/dev/null || true
fi

# Write machine-specific plist with absolute paths substituted
sed "s|REPO_DIR_PLACEHOLDER|$REPO_DIR|g" "$PLIST_SRC" > "$PLIST_DST"

# Validate plist was written and substituted correctly
if [[ ! -s "$PLIST_DST" ]]; then
  echo "ERROR: Plist was not written to $PLIST_DST"
  exit 1
fi
if ! grep -q "$REPO_DIR" "$PLIST_DST"; then
  echo "ERROR: Path substitution failed in plist. Check that $PLIST_SRC is not empty."
  exit 1
fi

# Bootstrap the service (modern replacement for launchctl load)
launchctl bootstrap gui/$(id -u) "$PLIST_DST"
echo "✓ launchd service installed and started"

# -----------------------------------------------------------------------------
# 10. Shell profile setup
# -----------------------------------------------------------------------------
SHELL_PROFILE="$HOME/.zshrc"
BREW_INIT='eval "$(/opt/homebrew/bin/brew shellenv)"'
UV_PATH='export PATH="$HOME/.local/bin:$PATH"'

if ! grep -q "brew shellenv" "$SHELL_PROFILE" 2>/dev/null; then
  echo "$BREW_INIT" >> "$SHELL_PROFILE"
fi
if ! grep -q ".local/bin" "$SHELL_PROFILE" 2>/dev/null; then
  echo "$UV_PATH" >> "$SHELL_PROFILE"
fi
echo "✓ Shell profile updated"

# -----------------------------------------------------------------------------
# Done
# -----------------------------------------------------------------------------
echo ""
echo "╔══════════════════════════════════════════╗"
echo "║        Bootstrap Complete ✓               ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "  Model download is starting in the background."
echo "  First run will take several minutes (~38GB for 70B)."
echo ""
echo "  Useful commands:"
echo "    make status   — check service"
echo "    make logs     — tail live logs"
echo "    make test     — run a test completion"
echo "    make stop     — stop service"
echo "    make restart  — restart service"
echo ""
