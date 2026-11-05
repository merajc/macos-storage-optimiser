PREFIX ?= $(HOME)/.local
BINDIR ?= $(PREFIX)/bin

.PHONY: all lint test install uninstall help

all: help

help:
	@echo "macos-system-data build & installation targets:"
	@echo "  make test      - Run automated CLI test suite"
	@echo "  make lint      - Validate zsh script syntax"
	@echo "  make install   - Install binary into $(BINDIR)"
	@echo "  make uninstall - Remove binary from $(BINDIR)"

lint:
	zsh -n bin/macos-system-data
	zsh -n tests/test_cli.sh

test: lint
	./tests/test_cli.sh

install:
	@mkdir -p $(BINDIR)
	install -m 755 bin/macos-system-data $(BINDIR)/macos-system-data
	@echo "Successfully installed macos-system-data to $(BINDIR)/macos-system-data"
	@echo "Ensure $(BINDIR) is in your PATH."

uninstall:
	rm -f $(BINDIR)/macos-system-data
	@echo "Successfully uninstalled macos-system-data from $(BINDIR)"
