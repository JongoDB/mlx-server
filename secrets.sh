#!/bin/zsh
# =============================================================================
# secrets.sh — retrieves secrets from macOS Keychain
# Never store actual values here. This file is safe to commit.
# =============================================================================

HF_TOKEN=$(security find-generic-password -a "huggingface" -s "HF_TOKEN" -w 2>/dev/null || true)

if [[ -z "$HF_TOKEN" ]]; then
  echo "ERROR: HF_TOKEN not found in macOS Keychain." >&2
  echo "  Run: security add-generic-password -a 'huggingface' -s 'HF_TOKEN' -w 'hf_yourtoken'" >&2
  echo "  Or re-run: ./bootstrap.sh" >&2
  exit 1
fi

export HF_TOKEN
