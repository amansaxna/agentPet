# ==============================================================================
# AgentPet - Personalized AI Companion & Productivity Suite
# ==============================================================================

SHELL := /bin/bash
export DEVELOPER_DIR = /Library/Developer/CommandLineTools
ROOT_DIR := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
APP_NAME := AgentPet.app
BUILD_DIR := $(ROOT_DIR)/build
APP_BUNDLE := $(BUILD_DIR)/$(APP_NAME)
INSTALL_DIR := $(HOME)/Applications

.PHONY: all help install build build-core build-web build-macos test launch launch-web launch-macos stop clean

all: install build

help:
	@echo "AgentPet Makefile Commands:"
	@echo ""
	@echo "  make install        Install web/cross-platform dependencies (npm install)"
	@echo "  make build          Build core engines (AgentPetCore) and UI assets"
	@echo "  make build-core     Compile Swift AgentPetCore deterministic engines"
	@echo "  make build-web      Typecheck & bundle web UI with Vite (windows/dist)"
	@echo "  make build-macos    Build native macOS menu bar app (requires Xcode.app)"
	@echo "  make launch         Launch AgentPet (native .app if built, or web companion)"
	@echo "  make launch-web     Start local UI dev server and open in default browser"
	@echo "  make launch-macos   Open built macOS native AgentPet.app"
	@echo "  make stop           Stop running AgentPet dev server or processes"
	@echo "  make test           Run verification checks across Swift core and TypeScript"
	@echo "  make clean          Remove build artifacts and caches"
	@echo ""

install:
	@echo "==> Installing frontend dependencies in windows/..."
	@cd "$(ROOT_DIR)/windows" && npm install
	@if [ -d "$(APP_BUNDLE)" ]; then \
		echo "==> Installing $(APP_NAME) to /Applications..."; \
		rm -rf "/Applications/$(APP_NAME)" && cp -R "$(APP_BUNDLE)" "/Applications/$(APP_NAME)"; \
		echo "==> Installed to /Applications/$(APP_NAME)"; \
	fi
	@echo "==> Installation complete."

build: build-core build-web
	@echo "==> Build complete."

build-core:
	@echo "==> Building AgentPetCore (Swift 6 native)..."
	@cd "$(ROOT_DIR)" && DEVELOPER_DIR=/Library/Developer/CommandLineTools swift build --build-system native --target AgentPetCore
	@echo "==> AgentPetCore built successfully."

build-web:
	@echo "==> Building cross-platform UI (TypeScript & Vite)..."
	@cd "$(ROOT_DIR)/windows" && npm run build
	@echo "==> Cross-platform UI bundle built successfully."

build-macos:
	@echo "==> Building native macOS $(APP_NAME)..."
	@cd "$(ROOT_DIR)" && DEVELOPER_DIR=/Library/Developer/CommandLineTools ./scripts/build-app.sh release
	@echo "==> $(APP_NAME) built successfully in $(BUILD_DIR)/$(APP_NAME)"

test:
	@echo "==> Verifying Swift core engines..."
	@cd "$(ROOT_DIR)" && swift build --build-system native --target AgentPetCore
	@echo "==> Verifying Swift app sources syntax..."
	@cd "$(ROOT_DIR)" && swiftc -parse Sources/App/*.swift Sources/AgentPetCore/*.swift
	@echo "==> Verifying TypeScript types & production bundle..."
	@cd "$(ROOT_DIR)/windows" && npm run build
	@echo "==> All test verifications passed."

launch:
	@if [ -d "$(APP_BUNDLE)" ]; then \
		echo "==> Found native $(APP_NAME). Launching native app..."; \
		$(MAKE) launch-macos; \
	elif [ -d "/Applications/$(APP_NAME)" ]; then \
		echo "==> Found /Applications/$(APP_NAME). Launching..."; \
		open "/Applications/$(APP_NAME)"; \
	elif [ -d "$(INSTALL_DIR)/$(APP_NAME)" ]; then \
		echo "==> Found $(INSTALL_DIR)/$(APP_NAME). Launching..."; \
		open "$(INSTALL_DIR)/$(APP_NAME)"; \
	else \
		echo "==> Native $(APP_NAME) not built yet. Launching web companion..."; \
		$(MAKE) launch-web; \
	fi

launch-web:
	@echo "==> Checking if UI server is already active on port 5173..."
	@if lsof -ti:5173 >/dev/null 2>&1; then \
		echo "Server is already running on port 5173."; \
	else \
		echo "Starting Vite dev server in background on http://127.0.0.1:5173 ..."; \
		(cd "$(ROOT_DIR)/windows" && npx vite --port 5173 --host 127.0.0.1 >/dev/null 2>&1 &); \
		sleep 2; \
	fi
	@echo "Opening AgentPet Popover Companion in browser..."
	@open "http://127.0.0.1:5173/popover.html"
	@echo ""
	@echo "Available URLs:"
	@echo "  Popover:   http://127.0.0.1:5173/popover.html"
	@echo "  Settings:  http://127.0.0.1:5173/settings.html"
	@echo "  Analytics: http://127.0.0.1:5173/stats.html"

launch-macos:
	@if [ -d "$(APP_BUNDLE)" ]; then \
		echo "Opening $(APP_BUNDLE)..."; \
		open "$(APP_BUNDLE)"; \
	else \
		echo "Error: $(APP_BUNDLE) not found. Run 'make build-macos' first."; \
		exit 1; \
	fi

stop:
	@echo "==> Stopping any running AgentPet dev servers or processes..."
	@lsof -ti:5173 | xargs kill -9 2>/dev/null || true
	@pkill -f "vite" 2>/dev/null || true
	@pkill -f "AgentPet" 2>/dev/null || true
	@echo "==> Stopped."

clean:
	@echo "==> Cleaning build directories..."
	@rm -rf "$(BUILD_DIR)" "$(ROOT_DIR)/.build" "$(ROOT_DIR)/windows/dist"
	@echo "==> Clean complete."
