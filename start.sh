#!/bin/zsh
# =============================================================================
# start.sh — MLX server entrypoint
# Called by launchd. Do not run directly in production; use: make start
# =============================================================================
set -euo pipefail

SCRIPT_DIR="${0:A:h}"

# Load secrets from Keychain
source "$SCRIPT_DIR/secrets.sh"

# Load server config
source "$SCRIPT_DIR/config.env"

# Activate virtualenv
source "$SCRIPT_DIR/.venv/bin/activate"

# Set HuggingFace cache to a predictable location
export HF_HOME="$HOME/.cache/huggingface"

echo "[$(date -Iseconds)] Starting MLX server"
echo "[$(date -Iseconds)] Model:  $MLX_MODEL"
echo "[$(date -Iseconds)] Listen: $MLX_HOST:$MLX_PORT"

exec mlx_lm.server \
  --model "$MLX_MODEL" \
  --port "$MLX_PORT" \
  --host "$MLX_HOST"
