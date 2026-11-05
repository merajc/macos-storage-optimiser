PREFIX ?= $(HOME)/.local
BINDIR ?= $(PREFIX)/bin
APP_NAME := MacOS Storage Optimiser
APP := dist/$(APP_NAME).app

.PHONY: all lint test test-app app run install uninstall help

all: help

help:
	@echo "macos-system-data build & installation targets:"
	@echo "  make test      - Run automated CLI + JSON contract test suite"
	@echo "  make test-app  - Run Swift unit tests for the desktop app"
	@echo "  make lint      - Validate zsh script syntax"
	@echo "  make app       - Build the desktop app into dist/"
	@echo "  make run       - Build and launch the desktop app"
	@echo "  make install   - Install CLI binary into $(BINDIR)"
	@echo "  make uninstall - Remove CLI binary from $(BINDIR)"

lint:
	zsh -n bin/macos-system-data
	zsh -n tests/test_cli.sh

test: lint
	./tests/test_cli.sh

test-app:
	swift test --package-path app

app:
	./scripts/build-app.sh

run: app
	open "$(APP)"

install:
	@mkdir -p $(BINDIR)
	install -m 755 bin/macos-system-data $(BINDIR)/macos-system-data
	@echo "Successfully installed macos-system-data to $(BINDIR)/macos-system-data"
	@echo "Ensure $(BINDIR) is in your PATH."

uninstall:
	rm -f $(BINDIR)/macos-system-data
	@echo "Successfully uninstalled macos-system-data from $(BINDIR)"
