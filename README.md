# mlx-server

Production-grade MLX-LM inference server for Apple Silicon Macs.

Serves an OpenAI-compatible API via [mlx-lm](https://github.com/ml-explore/mlx-examples/tree/main/llms), managed as a persistent launchd service. Designed to sit behind a LiteLLM proxy with Cloudflare Tunnel exposure.

## Requirements

- Apple Silicon Mac (M1/M2/M3/M4)
- macOS 13 Ventura or later
- HuggingFace account + token (for gated models)
- Internet access on first run (model download)

## Fresh Mac Setup

```zsh
git clone git@github.com:YOUR_ORG/mlx-server.git ~/mlx-server
cd ~/mlx-server
chmod +x bootstrap.sh
./bootstrap.sh
```

The bootstrap script will:
1. Verify Apple Silicon
2. Install Xcode CLT if missing
3. Install Homebrew if missing
4. Install uv if missing
5. Create the Python 3.11 virtualenv
6. Install dependencies from `uv.lock`
7. Verify MLX can access the GPU via Metal
8. Store your HuggingFace token in macOS Keychain (never on disk)
9. Install and start the launchd service

## Configuration

Edit `config.env` to change the model or server settings:

```env
MLX_MODEL=mlx-community/Meta-Llama-3.1-70B-Instruct-4bit
MLX_HOST=0.0.0.0
MLX_PORT=8080
MLX_MAX_TOKENS=8192
```

Then apply: `make restart`

Or interactively: `make model-switch`

## Operations

```zsh
make status     # check service health
make logs       # tail stdout
make errors     # tail stderr
make test       # send a test completion
make restart    # restart service
make stop       # stop service
make update     # upgrade deps + restart
make uninstall  # remove launchd service
```

## Secrets

HuggingFace token is stored in macOS Keychain only — never on disk or in env files.

To update the token:
```zsh
security delete-generic-password -a "huggingface" -s "HF_TOKEN"
security add-generic-password -a "huggingface" -s "HF_TOKEN" -w "hf_newtoken"
make restart
```

## API

The server exposes an OpenAI-compatible API on port 8080:

```zsh
curl http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "default",
    "messages": [{"role": "user", "content": "Hello"}]
  }'
```

## Architecture

```
Coworkers
    │
    ▼
Cloudflare Tunnel
    │
    ▼
LiteLLM Proxy  (API key management, load balancing, routing)
    │
    ├──▶ This Mac  :8080  (MLX — Apple Silicon)
    ├──▶ Mac 2     :8080  (MLX — Apple Silicon)
    └──▶ Windows   :8080  (llama.cpp — CUDA)
```

## Replicating to Additional Macs

Same three commands on each machine:
```zsh
git clone git@github.com:YOUR_ORG/mlx-server.git ~/mlx-server
cd ~/mlx-server
./bootstrap.sh
```

The `uv.lock` file ensures identical dependency versions across all machines.

## Updating Dependencies

```zsh
make update
```

This runs `uv sync --upgrade`, updates `uv.lock`, and restarts the service. Commit the updated lockfile to propagate to other machines.
