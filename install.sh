#!/usr/bin/env bash
# gcloud-docker-network installer

set -e

VERSION="1.0.2"
INSTALL_DIR="/usr/local/bin"
BINARY_NAME="gcloud-docker-network"
INSTALL_PATH="$INSTALL_DIR/$BINARY_NAME"

# GitHub repository URL (update this with your actual repository)
REPO_URL="https://raw.githubusercontent.com/sanghaklee-gcloud/gcloud-docker-network/master"
SCRIPT_URL="$REPO_URL/run.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Check if running as root for installation
check_root() {
    if [ "$EUID" -ne 0 ] && [ ! -w "$INSTALL_DIR" ]; then
        echo -e "${YELLOW}⚠️  This script requires sudo privileges to install to $INSTALL_DIR${NC}"
        echo -e "${BLUE}💡 Re-running with sudo...${NC}"
        exec sudo "$0" "$@"
    fi
}

# Uninstall function
uninstall() {
    echo -e "${CYAN}Uninstalling gcloud-docker-network...${NC}"

    if [ -f "$INSTALL_PATH" ]; then
        rm -f "$INSTALL_PATH"
        echo -e "${GREEN}✅ Successfully uninstalled gcloud-docker-network${NC}"
        echo -e "${BLUE}   Removed: $INSTALL_PATH${NC}"
    else
        echo -e "${YELLOW}⚠️  gcloud-docker-network is not installed${NC}"
        exit 1
    fi
}

# Install function
install() {
    echo -e "${CYAN}Installing gcloud-docker-network v${VERSION}...${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Check if curl is installed
    if ! command -v curl &> /dev/null; then
        echo -e "${RED}❌ Error: curl is required but not installed${NC}"
        echo -e "${BLUE}💡 Install curl first: sudo apt-get install curl${NC}"
        exit 1
    fi

    # Create temp directory
    TMP_DIR=$(mktemp -d)
    trap 'rm -rf "$TMP_DIR"' EXIT

    # Download the script
    echo -e "${BLUE}📥 Downloading script...${NC}"
    if ! curl -fsSL "$SCRIPT_URL" -o "$TMP_DIR/run.sh"; then
        echo -e "${RED}❌ Failed to download script from $SCRIPT_URL${NC}"
        echo -e "${YELLOW}💡 Make sure the repository URL is correct${NC}"
        exit 1
    fi

    # Verify download
    if [ ! -s "$TMP_DIR/run.sh" ]; then
        echo -e "${RED}❌ Downloaded file is empty${NC}"
        exit 1
    fi

    # Install to target directory
    echo -e "${BLUE}📦 Installing to $INSTALL_PATH...${NC}"
    cp "$TMP_DIR/run.sh" "$INSTALL_PATH"
    chmod +x "$INSTALL_PATH"

    # Verify installation
    if [ -x "$INSTALL_PATH" ]; then
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo -e "${GREEN}✅ Successfully installed gcloud-docker-network!${NC}"
        echo ""
        echo -e "${YELLOW}Quick Start:${NC}"
        echo -e "  ${CYAN}gcloud-docker-network check 8080${NC}       # Check port status"
        echo -e "  ${CYAN}gcloud-docker-network add 8080${NC}         # Add port rule"
        echo -e "  ${CYAN}gcloud-docker-network list${NC}             # List Docker rules"
        echo -e "  ${CYAN}gcloud-docker-network help${NC}             # Show help"
        echo ""
        echo -e "${BLUE}💡 Run 'gcloud-docker-network help' for more information${NC}"
    else
        echo -e "${RED}❌ Installation failed${NC}"
        exit 1
    fi
}

# Main
main() {
    case "${1:-}" in
        --uninstall|-u)
            check_root "$@"
            uninstall
            ;;
        --help|-h)
            echo "gcloud-docker-network installer v${VERSION}"
            echo ""
            echo "Usage:"
            echo "  $0              Install gcloud-docker-network"
            echo "  $0 --uninstall  Uninstall gcloud-docker-network"
            echo "  $0 --help       Show this help"
            echo ""
            echo "Quick install:"
            echo "  curl -LsSf $REPO_URL/install.sh | sh"
            echo ""
            echo "Uninstall:"
            echo "  curl -LsSf $REPO_URL/install.sh | sh -s -- --uninstall"
            ;;
        *)
            check_root "$@"
            install
            ;;
    esac
}

main "$@"
