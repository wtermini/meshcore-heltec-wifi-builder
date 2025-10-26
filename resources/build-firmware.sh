#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting MeshCore firmware build process...${NC}"

# Default values
WIFI_SSID="${WIFI_SSID:-YourSSID}"
WIFI_PWD="${WIFI_PWD:-YourPassword}"

# Check if cache directory exists and has content
if [ -d "/build-cache/.platformio" ] && [ "$(ls -A /build-cache/.platformio 2>/dev/null)" ]; then
    echo -e "${GREEN}Using cached PlatformIO tools - build will be faster!${NC}"
else
    echo -e "${YELLOW}First run - downloading and caching PlatformIO tools...${NC}"
    echo -e "${YELLOW}Subsequent builds will be much faster!${NC}"
fi

echo -e "${YELLOW}Configuration:${NC}"
echo "WIFI_SSID: $WIFI_SSID"
echo "WIFI_PWD: [REDACTED]"
echo ""

# Clone or update the MeshCore repository
if [ -d "MeshCore" ]; then
    echo -e "${YELLOW}Updating existing MeshCore repository...${NC}"
    cd MeshCore
    git pull origin main || git pull origin master
    cd ..
else
    echo -e "${YELLOW}Cloning MeshCore repository...${NC}"
    git clone https://github.com/ripplebiz/MeshCore.git
fi

cd MeshCore

# Check if the platformio.ini file exists
PLATFORMIO_FILE="variants/heltec_v3/platformio.ini"
if [ ! -f "$PLATFORMIO_FILE" ]; then
    echo -e "${RED}Error: $PLATFORMIO_FILE not found!${NC}"
    echo "Available variants:"
    ls -la variants/ || echo "No variants directory found"
    exit 1
fi

# Backup original platformio.ini
cp "$PLATFORMIO_FILE" "${PLATFORMIO_FILE}.backup"

# Replace Wi-Fi credentials in the existing platformio.ini
echo -e "${YELLOW}Updating Wi-Fi credentials in platformio.ini...${NC}"

# Use sed to directly replace the SSID and password placeholders in the existing file
sed -i "s/myssid/$WIFI_SSID/g" "$PLATFORMIO_FILE"
sed -i "s/mypwd/$WIFI_PWD/g" "$PLATFORMIO_FILE"

# Verify the configuration was updated
echo -e "${YELLOW}Verifying Wi-Fi configuration...${NC}"
echo "Wi-Fi section in platformio.ini:"
grep -A 15 "\[env:Heltec_v3_companion_radio_wifi\]" "$PLATFORMIO_FILE" || echo "No Wi-Fi section found"

# Verify credentials are properly embedded - check for the actual Wi-Fi lines
WIFI_SSID_LINE=$(grep "WIFI_SSID=" "$PLATFORMIO_FILE" || echo "")
WIFI_PWD_LINE=$(grep "WIFI_PWD=" "$PLATFORMIO_FILE" || echo "")

if [[ "$WIFI_SSID_LINE" == *"\"$WIFI_SSID\""* ]] && [[ "$WIFI_PWD_LINE" == *"\"$WIFI_PWD\""* ]]; then
    echo -e "${GREEN}✓ Wi-Fi configuration successfully updated${NC}"
    echo "✓ SSID: $WIFI_SSID"
    echo "✓ Password: [REDACTED for security]"
    echo "✓ Method: Direct replacement in git repository"
else
    echo -e "${RED}✗ Wi-Fi configuration update failed${NC}"
    echo "Expected to find credentials embedded, but got:"
    echo "  WIFI_SSID line: $WIFI_SSID_LINE"
    echo "  WIFI_PWD line: [REDACTED]"
    echo ""
    echo "All WIFI lines found:"
    grep "WIFI_" "$PLATFORMIO_FILE" || echo "No WIFI lines found"
    exit 1
fi

# Build the firmware
echo -e "${YELLOW}Building firmware...${NC}"
./build.sh build-firmware Heltec_v3_companion_radio_wifi

# Check if build was successful
BUILD_DIR=".pio/build/Heltec_v3_companion_radio_wifi"
if [ ! -d "$BUILD_DIR" ]; then
    echo -e "${RED}Error: Build directory not found! Build may have failed.${NC}"
    exit 1
fi

cd "$BUILD_DIR"

# Check if firmware files exist
if [ ! -f "firmware.bin" ]; then
    echo -e "${RED}Error: firmware.bin not found! Build may have failed.${NC}"
    ls -la
    exit 1
fi

# Rename and prepare firmware files
echo -e "${YELLOW}Preparing firmware files...${NC}"
FIRMWARE_BASE="Heltec_v3_companion_radio_wifi"

# Copy firmware files with version naming
if [ -f "firmware-merged.bin" ]; then
    cp "firmware-merged.bin" "/output/${FIRMWARE_BASE}-merged.bin"
    echo -e "${GREEN}Created: ${FIRMWARE_BASE}-merged.bin${NC}"
fi

if [ -f "firmware.bin" ]; then
    cp "firmware.bin" "/output/${FIRMWARE_BASE}.bin"
    echo -e "${GREEN}Created: ${FIRMWARE_BASE}.bin${NC}"
fi

# Create a build info file
echo -e "${YELLOW}Creating build info...${NC}"
cat > "/output/build-info.txt" << EOF
Build Information
=================
Timestamp: $(date)
WIFI_SSID: $WIFI_SSID
Target: Heltec_v3_companion_radio_wifi

Files Generated:
- ${FIRMWARE_BASE}.bin (main firmware)
- ${FIRMWARE_BASE}-merged.bin (merged firmware, if available)

Flash Instructions:
1. Use your preferred flashing tool (esptool, Arduino IDE, etc.)
2. Flash the .bin file to your Heltec V3 device
3. Monitor serial output to confirm Wi-Fi connectivity
4. Remember: This is experimental firmware

WARNING: Do not share these binaries publicly as they contain your Wi-Fi credentials!
EOF

echo -e "${GREEN}Build completed successfully!${NC}"
echo -e "${YELLOW}Output files available in /output/${NC}"
ls -la /output/