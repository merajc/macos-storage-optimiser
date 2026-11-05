#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="${HOME}/.local/bin"
RAW_URL="https://raw.githubusercontent.com/merajc/macos-storage-optimiser/main/bin/macos-system-data"

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "Error: macos-system-data is designed exclusively for macOS." >&2
    exit 1
fi

mkdir -p "${INSTALL_DIR}"
echo "Downloading macos-system-data..."
curl -fsSL "${RAW_URL}" -o "${INSTALL_DIR}/macos-system-data"
chmod +x "${INSTALL_DIR}/macos-system-data"

echo "✔ Successfully installed to ${INSTALL_DIR}/macos-system-data"

if [[ ":$PATH:" != *":${INSTALL_DIR}:"* ]]; then
    echo ""
    echo "Note: ${INSTALL_DIR} is not in your PATH."
    echo "Add this to your ~/.zshrc or ~/.bash_profile:"
    echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
fi
