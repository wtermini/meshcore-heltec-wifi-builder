#!/bin/bash

# MeshCore Wi-Fi Firmware Builder
# This script builds the Docker image and runs the firmware build process

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
DOCKER_IMAGE="meshcore-builder"
OUTPUT_DIR="$(pwd)/firmware-output"
CACHE_DIR="$(pwd)/build-cache"

# Function to display usage
usage() {
    echo -e "${BLUE}MeshCore Wi-Fi Firmware Builder${NC}"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -s, --ssid SSID         Wi-Fi SSID (required)"
    echo "  -p, --password PASSWORD Wi-Fi password (required)"
    echo "  -v, --version VERSION   Firmware version (default: 1.7.3)"
    echo "  -o, --output DIR        Output directory (default: ./firmware-output)"
    echo "  -c, --cache DIR         Cache directory (default: ./build-cache)"
    echo "  --max-contacts NUM      Maximum contacts (default: 300)"
    echo "  --max-channels NUM      Maximum group channels (default: 8)"
    echo "  --enable-debug          Enable mesh debug logging"
    echo "  --enable-packet-log     Enable mesh packet logging"
    echo "  --build-only            Only build the Docker image, don't run"
    echo "  --no-build              Skip building Docker image, just run"
    echo "  --clear-cache           Clear the build cache before running"
    echo "  -h, --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --ssid MyWiFi --password MyPassword"
    echo "  $0 -s MyWiFi -p MyPassword -v 1.8.0"
    echo "  $0 --ssid MyWiFi --password MyPassword --output /tmp/firmware"
    echo ""
    echo -e "${YELLOW}Warning: Your Wi-Fi credentials will be embedded in the firmware.${NC}"
    echo -e "${YELLOW}Do not share the compiled binaries publicly!${NC}"
}

# Parse command line arguments
WIFI_SSID=""
WIFI_PWD=""
FIRMWARE_VERSION="1.9.1"
BUILD_ONLY=false
NO_BUILD=false
CLEAR_CACHE=false
MAX_CONTACTS=""
MAX_GROUP_CHANNELS=""
MESH_DEBUG=""
MESH_PACKET_LOGGING=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--ssid)
            WIFI_SSID="$2"
            shift 2
            ;;
        -p|--password)
            WIFI_PWD="$2"
            shift 2
            ;;
        -v|--version)
            FIRMWARE_VERSION="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -c|--cache)
            CACHE_DIR="$2"
            shift 2
            ;;
        --max-contacts)
            MAX_CONTACTS="$2"
            shift 2
            ;;
        --max-channels)
            MAX_GROUP_CHANNELS="$2"
            shift 2
            ;;
        --enable-debug)
            MESH_DEBUG="1"
            shift
            ;;
        --enable-packet-log)
            MESH_PACKET_LOGGING="1"
            shift
            ;;
        --build-only)
            BUILD_ONLY=true
            shift
            ;;
        --no-build)
            NO_BUILD=true
            shift
            ;;
        --clear-cache)
            CLEAR_CACHE=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            usage
            exit 1
            ;;
    esac
done

# Validate required parameters (unless build-only)
if [ "$BUILD_ONLY" = false ]; then
    if [ -z "$WIFI_SSID" ] || [ -z "$WIFI_PWD" ]; then
        echo -e "${RED}Error: Wi-Fi SSID and password are required${NC}"
        echo ""
        usage
        exit 1
    fi
fi

echo -e "${BLUE}=== MeshCore Wi-Fi Firmware Builder ===${NC}"
echo ""

# Handle cache clearing if requested
if [ "$CLEAR_CACHE" = true ]; then
    echo -e "${YELLOW}Clearing build cache...${NC}"
    rm -rf "$CACHE_DIR"
    echo -e "${GREEN}Cache cleared${NC}"
fi

# Create output and cache directories
mkdir -p "$OUTPUT_DIR" "$CACHE_DIR"
echo -e "${GREEN}Output directory: $OUTPUT_DIR${NC}"
echo -e "${GREEN}Cache directory: $CACHE_DIR${NC}"

# Show cache status
if [ -d "$CACHE_DIR/.platformio" ] && [ "$(ls -A "$CACHE_DIR/.platformio" 2>/dev/null)" ]; then
    CACHE_SIZE=$(du -sh "$CACHE_DIR" 2>/dev/null | cut -f1 || echo "unknown")
    echo -e "${GREEN}Cache exists (${CACHE_SIZE}) - build will be faster!${NC}"
else
    echo -e "${YELLOW}No cache found - first build will download tools${NC}"
fi

# Build Docker image (unless --no-build is specified)
if [ "$NO_BUILD" = false ]; then
    echo -e "${YELLOW}Building Docker image: $DOCKER_IMAGE${NC}"
    docker build -t "$DOCKER_IMAGE" .
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Docker image built successfully${NC}"
    else
        echo -e "${RED}Failed to build Docker image${NC}"
        exit 1
    fi
fi

# Exit if build-only was requested
if [ "$BUILD_ONLY" = true ]; then
    echo -e "${GREEN}Docker image build completed. Use --no-build to run without rebuilding.${NC}"
    exit 0
fi

echo ""
echo -e "${YELLOW}Starting firmware build process...${NC}"
echo "SSID: $WIFI_SSID"
echo "Password: [REDACTED]"
echo "Version: $FIRMWARE_VERSION"
echo ""

# Run the Docker container with cache volume and gomplate environment variables
echo -e "${YELLOW}Mounting cache directory for faster subsequent builds...${NC}"
docker run --rm \
    -e WIFI_SSID="$WIFI_SSID" \
    -e WIFI_PWD="$WIFI_PWD" \
    -e FIRMWARE_VERSION="$FIRMWARE_VERSION" \
    ${MAX_CONTACTS:+-e MAX_CONTACTS="$MAX_CONTACTS"} \
    ${MAX_GROUP_CHANNELS:+-e MAX_GROUP_CHANNELS="$MAX_GROUP_CHANNELS"} \
    ${MESH_DEBUG:+-e MESH_DEBUG="$MESH_DEBUG"} \
    ${MESH_PACKET_LOGGING:+-e MESH_PACKET_LOGGING="$MESH_PACKET_LOGGING"} \
    -v "$OUTPUT_DIR:/output" \
    -v "$CACHE_DIR:/build-cache" \
    "$DOCKER_IMAGE"

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}=== Build Completed Successfully! ===${NC}"
    echo -e "${GREEN}Firmware files are available in: $OUTPUT_DIR${NC}"
    echo ""
    echo -e "${YELLOW}Generated files:${NC}"
    ls -la "$OUTPUT_DIR"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "1. Flash the firmware to your Heltec V3 device"
    echo "2. Monitor serial output to confirm Wi-Fi connectivity"
    echo "3. Remember: This is experimental firmware"
    echo ""
    echo -e "${RED}WARNING: Do not share these binaries publicly as they contain your Wi-Fi credentials!${NC}"
else
    echo -e "${RED}Build failed! Check the output above for errors.${NC}"
    exit 1
fi