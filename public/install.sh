#!/bin/sh
# Strata installer — https://stratadb.org
# Usage: curl -fsSL https://stratadb.org/install.sh | sh
set -eu

REPO="strata-ai-labs/strata-core"
INSTALL_DIR="${HOME}/.strata/bin"
BINARY_NAME="strata"

main() {
    check_dependencies
    detect_platform
    get_latest_version
    download_and_install
    print_success
}

check_dependencies() {
    if command -v curl >/dev/null 2>&1; then
        DOWNLOAD="curl"
    elif command -v wget >/dev/null 2>&1; then
        DOWNLOAD="wget"
    else
        err "either 'curl' or 'wget' is required to download strata"
    fi
}

detect_platform() {
    OS="$(uname -s)"
    ARCH="$(uname -m)"

    case "$OS" in
        Linux)  OS_TARGET="unknown-linux-gnu" ;;
        Darwin) OS_TARGET="apple-darwin" ;;
        MINGW*|MSYS*|CYGWIN*)
            OS_TARGET="pc-windows-msvc"
            ;;
        *)
            err "unsupported operating system: $OS"
            ;;
    esac

    case "$ARCH" in
        x86_64|amd64)   ARCH_TARGET="x86_64" ;;
        aarch64|arm64)   ARCH_TARGET="aarch64" ;;
        *)
            err "unsupported architecture: $ARCH"
            ;;
    esac

    TARGET="${ARCH_TARGET}-${OS_TARGET}"
    say "detected platform: $TARGET"
}

get_latest_version() {
    say "fetching latest release version..."
    RELEASE_URL="https://api.github.com/repos/${REPO}/releases/latest"

    if [ "$DOWNLOAD" = "curl" ]; then
        VERSION=$(curl -fsSL "$RELEASE_URL" | parse_version)
    else
        VERSION=$(wget -qO- "$RELEASE_URL" | parse_version)
    fi

    if [ -z "$VERSION" ]; then
        err "could not determine latest version. Check https://github.com/${REPO}/releases"
    fi

    say "latest version: v${VERSION}"
}

parse_version() {
    # Extract tag_name value, strip leading 'v'
    sed -n 's/.*"tag_name": *"v\([^"]*\)".*/\1/p'
}

download_and_install() {
    if [ "$OS_TARGET" = "pc-windows-msvc" ]; then
        ARCHIVE_EXT="zip"
    else
        ARCHIVE_EXT="tar.gz"
    fi

    ARCHIVE_NAME="${BINARY_NAME}-v${VERSION}-${TARGET}.${ARCHIVE_EXT}"
    DOWNLOAD_URL="https://github.com/${REPO}/releases/download/v${VERSION}/${ARCHIVE_NAME}"

    TMPDIR=$(mktemp -d)
    trap 'rm -rf "$TMPDIR"' EXIT

    say "downloading ${ARCHIVE_NAME}..."
    if [ "$DOWNLOAD" = "curl" ]; then
        curl -fsSL "$DOWNLOAD_URL" -o "${TMPDIR}/${ARCHIVE_NAME}"
    else
        wget -q "$DOWNLOAD_URL" -O "${TMPDIR}/${ARCHIVE_NAME}"
    fi

    if [ ! -f "${TMPDIR}/${ARCHIVE_NAME}" ]; then
        err "download failed. URL: ${DOWNLOAD_URL}"
    fi

    say "extracting to ${INSTALL_DIR}..."
    mkdir -p "$INSTALL_DIR"

    if [ "$ARCHIVE_EXT" = "tar.gz" ]; then
        tar xzf "${TMPDIR}/${ARCHIVE_NAME}" -C "$TMPDIR"
    else
        unzip -o "${TMPDIR}/${ARCHIVE_NAME}" -d "$TMPDIR" >/dev/null
    fi

    mv "${TMPDIR}/${BINARY_NAME}" "${INSTALL_DIR}/${BINARY_NAME}"
    chmod +x "${INSTALL_DIR}/${BINARY_NAME}"
}

print_success() {
    say ""
    say "strata v${VERSION} installed to ${INSTALL_DIR}/${BINARY_NAME}"
    say ""

    case ":${PATH}:" in
        *":${INSTALL_DIR}:"*)
            say "run 'strata --version' to verify the installation."
            ;;
        *)
            say "add strata to your PATH by adding one of the following to your shell config:"
            say ""
            say "  # bash (~/.bashrc)"
            say "  export PATH=\"${INSTALL_DIR}:\$PATH\""
            say ""
            say "  # zsh (~/.zshrc)"
            say "  export PATH=\"${INSTALL_DIR}:\$PATH\""
            say ""
            say "  # fish (~/.config/fish/config.fish)"
            say "  fish_add_path ${INSTALL_DIR}"
            say ""
            say "then restart your shell and run 'strata --version'."
            ;;
    esac
}

say() {
    printf '%s\n' "$1"
}

err() {
    say "error: $1" >&2
    exit 1
}

main
