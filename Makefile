# Zoomies — build, run & test helpers.
# Run `make` (or `make help`) to list every command.

APP_NAME     := Zoomies
PROJECT      := $(APP_NAME).xcodeproj
SCHEME       := $(APP_NAME)
CONFIG       := Debug
DERIVED      := build
APP_PATH     := $(DERIVED)/Build/Products/$(CONFIG)/$(APP_NAME).app
GENERATOR    := Tools/SpriteGenerator/main.swift

# Common xcodebuild flags. Unsigned local build (CODE_SIGNING_ALLOWED=NO),
# output to ./build so paths are predictable.
XCFLAGS := -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIG) \
           -destination 'platform=macOS' -derivedDataPath $(DERIVED) \
           CODE_SIGNING_ALLOWED=NO

# Use bash with pipefail so a failed xcodebuild fails the make target
# (even though its output is piped through grep for readability).
SHELL := /bin/bash
.SHELLFLAGS := -o pipefail -c

.DEFAULT_GOAL := help
.PHONY: help project build test run stop sprites install clean

help: ## List available commands
	@echo "Zoomies — available commands:"
	@awk 'BEGIN{FS=":.*## "} /^[a-zA-Z_-]+:.*## /{printf "  make %-9s %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "First time? Run:  make build  then  make run"

project: ## Generate Zoomies.xcodeproj from project.yml (run after cloning or adding files)
	@command -v xcodegen >/dev/null || { echo "❌ xcodegen not found. Install with: brew install xcodegen"; exit 1; }
	@echo "📦 Generating $(PROJECT)…"
	@xcodegen generate

build: project ## Build the app (Debug, unsigned)
	@echo "🔨 Building $(APP_NAME)…"
	@xcodebuild build $(XCFLAGS) | grep -E "(BUILD SUCCEEDED|BUILD FAILED|error:)"

test: project ## Run the unit test suite
	@echo "🧪 Testing $(APP_NAME)…"
	@xcodebuild test $(XCFLAGS) | grep -E "(Executed [0-9]+ test|TEST SUCCEEDED|TEST FAILED)"

run: build ## Build, then launch Zoomies (look in your menu bar, top-right)
	@killall $(APP_NAME) 2>/dev/null || true
	@open "$(APP_PATH)"
	@echo "✅ $(APP_NAME) is running — check the right side of your menu bar."
	@echo "   Click the animal to switch it, see CPU %, or quit."
	@echo "   Tip: run  yes > /dev/null &  on a few cores to watch it sprint (then: killall yes)."

stop: ## Quit the running app
	@killall $(APP_NAME) 2>/dev/null && echo "🛑 Stopped $(APP_NAME)." || echo "$(APP_NAME) was not running."

sprites: ## Regenerate the animal sprite frames into the asset catalog
	@echo "🎨 Generating sprite frames…"
	@swift $(GENERATOR)

install: build ## Copy Zoomies.app into /Applications and launch it
	@killall $(APP_NAME) 2>/dev/null || true
	@rm -rf "/Applications/$(APP_NAME).app"
	@cp -R "$(APP_PATH)" /Applications/
	@open "/Applications/$(APP_NAME).app"
	@echo "✅ Installed to /Applications/$(APP_NAME).app and launched."

clean: ## Remove build artifacts and the generated Xcode project
	@rm -rf $(DERIVED) $(PROJECT)
	@echo "🧹 Removed $(DERIVED)/ and $(PROJECT)."
