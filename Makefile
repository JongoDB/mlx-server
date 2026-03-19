PLIST_NAME   := com.mlx.server
PLIST_DST    := $(HOME)/Library/LaunchAgents/$(PLIST_NAME).plist
REPO_DIR     := $(shell pwd)
LOG_FILE     := $(REPO_DIR)/logs/mlx-server.log
ERR_FILE     := $(REPO_DIR)/logs/mlx-server.err
GUI_UID      := $(shell id -u)

.DEFAULT_GOAL := help

.PHONY: help bootstrap install uninstall start stop restart status logs errors test update model-switch

help:
	@echo ""
	@echo "  MLX Server — available commands"
	@echo ""
	@echo "  make bootstrap      Full setup on a new machine (runs bootstrap.sh)"
	@echo "  make install        Install launchd service (after bootstrap)"
	@echo "  make uninstall      Remove launchd service"
	@echo "  make start          Start the service"
	@echo "  make stop           Stop the service"
	@echo "  make restart        Restart the service"
	@echo "  make status         Show service status"
	@echo "  make logs           Tail stdout log"
	@echo "  make errors         Tail stderr log"
	@echo "  make test           Send a test completion request"
	@echo "  make update         Upgrade deps and restart"
	@echo "  make model-switch   Interactively change the model in config.env"
	@echo ""

bootstrap:
	@chmod +x bootstrap.sh start.sh secrets.sh
	@./bootstrap.sh

install:
	@mkdir -p logs
	@sed "s|REPO_DIR_PLACEHOLDER|$(REPO_DIR)|g" $(PLIST_NAME).plist > $(PLIST_DST)
	@if [ ! -s "$(PLIST_DST)" ]; then echo "ERROR: Plist write failed"; exit 1; fi
	@launchctl bootstrap gui/$(GUI_UID) $(PLIST_DST)
	@echo "✓ Service installed"

uninstall:
	-@launchctl bootout gui/$(GUI_UID) $(PLIST_DST) 2>/dev/null
	@rm -f $(PLIST_DST)
	@echo "✓ Service removed"

start:
	launchctl kickstart -k gui/$(GUI_UID)/$(PLIST_NAME)

stop:
	launchctl kill SIGTERM gui/$(GUI_UID)/$(PLIST_NAME)

restart:
	launchctl kickstart -k gui/$(GUI_UID)/$(PLIST_NAME)
	@echo "✓ Restarted"

status:
	@launchctl print gui/$(GUI_UID)/$(PLIST_NAME) 2>/dev/null | grep -E "state|pid|path" || echo "⚠ MLX server not running"
	@echo ""
	@echo "Last 5 log lines:"
	@tail -5 $(LOG_FILE) 2>/dev/null || echo "(no log yet)"

logs:
	tail -f $(LOG_FILE)

errors:
	tail -f $(ERR_FILE)

test:
	@echo "→ Sending test completion..."
	@source config.env && curl -sf http://localhost:$$MLX_PORT/v1/chat/completions \
		-H "Content-Type: application/json" \
		-d '{"model":"default","messages":[{"role":"user","content":"Reply with exactly three words: server is working"}],"max_tokens":20}' \
		| python3 -m json.tool
	@echo ""

update:
	@echo "→ Upgrading dependencies..."
	uv sync --upgrade
	@$(MAKE) restart
	@echo "✓ Updated and restarted"

model-switch:
	@echo "Available models for 128GB unified memory:"
	@echo "  1) mlx-community/Meta-Llama-3.1-70B-Instruct-4bit   (recommended, ~38GB)"
	@echo "  2) mlx-community/Llama-3.3-70B-Instruct-4bit         (newest 70B, ~38GB)"
	@echo "  3) mlx-community/Meta-Llama-3.1-8B-Instruct-4bit     (fast, ~5GB)"
	@echo "  4) mlx-community/Mistral-7B-Instruct-v0.3-4bit        (fast, ~4GB)"
	@echo "  5) mlx-community/Qwen2.5-Coder-7B-Instruct-4bit       (code, ~4GB)"
	@echo ""
	@read -p "Enter model string (or pick 1-5): " MODEL && \
	case $$MODEL in \
		1) MODEL="mlx-community/Meta-Llama-3.1-70B-Instruct-4bit" ;; \
		2) MODEL="mlx-community/Llama-3.3-70B-Instruct-4bit" ;; \
		3) MODEL="mlx-community/Meta-Llama-3.1-8B-Instruct-4bit" ;; \
		4) MODEL="mlx-community/Mistral-7B-Instruct-v0.3-4bit" ;; \
		5) MODEL="mlx-community/Qwen2.5-Coder-7B-Instruct-4bit" ;; \
	esac && \
	sed -i '' "s|^MLX_MODEL=.*|MLX_MODEL=$$MODEL|" config.env && \
	echo "✓ Model set to: $$MODEL" && \
	$(MAKE) restart
