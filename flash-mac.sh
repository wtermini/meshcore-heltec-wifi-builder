#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== MeshCore Firmware Flasher for Mac ===${NC}"
echo ""

# Parse command line arguments
ERASE_FLASH=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --erase)
            ERASE_FLASH=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [--erase]"
            echo "  --erase    Erase flash before flashing (WARNING: destroys all data)"
            echo "  --help     Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Configuration
FIRMWARE_DIR="./firmware-output"
MERGED_FIRMWARE=$(ls ${FIRMWARE_DIR}/*-merged.bin 2>/dev/null | head -1)
BAUD_RATE=921600
FALLBACK_BAUD=115200

# Check if firmware exists
if [ ! -f "$MERGED_FIRMWARE" ]; then
    echo -e "${RED}❌ Error: No merged firmware found in ${FIRMWARE_DIR}${NC}"
    echo "Expected to find: *-merged.bin"
    echo "Available files:"
    ls -la ${FIRMWARE_DIR}/ 2>/dev/null || echo "Directory not found"
    exit 1
fi

echo -e "${GREEN}📦 Found firmware: $(basename "$MERGED_FIRMWARE")${NC}"
if [ "$ERASE_FLASH" = true ]; then
    echo -e "${RED}⚠️  ERASE MODE: Will erase all data before flashing${NC}"
else
    echo -e "${BLUE}ℹ️  SAFE MODE: Will preserve data partition (use --erase to change)${NC}"
fi
echo ""

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install esptool
install_esptool() {
    echo -e "${YELLOW}🔧 Installing esptool...${NC}"
    
    # Try pip3 first (most common on macOS)
    if command_exists pip3; then
        echo "Installing via pip3 (user installation)..."
        if pip3 install --user esptool; then
            echo -e "${GREEN}✅ pip3 installation completed${NC}"
        else
            echo -e "${YELLOW}⚠️  pip3 installation failed, trying alternatives...${NC}"
        fi
    # Try python3 -m pip (more reliable on some systems)
    elif command_exists python3; then
        echo "Installing via python3 -m pip..."
        if python3 -m pip install --user esptool; then
            echo -e "${GREEN}✅ python3 -m pip installation completed${NC}"
        else
            echo -e "${YELLOW}⚠️  python3 -m pip installation failed, trying alternatives...${NC}"
        fi
    # Try regular pip
    elif command_exists pip; then
        echo "Installing via pip..."
        if pip install --user esptool; then
            echo -e "${GREEN}✅ pip installation completed${NC}"
        else
            echo -e "${YELLOW}⚠️  pip installation failed, trying alternatives...${NC}"
        fi
    # Try Homebrew as fallback
    elif command_exists brew; then
        echo "Installing via Homebrew..."
        if brew install esptool; then
            echo -e "${GREEN}✅ Homebrew installation completed${NC}"
        else
            echo -e "${YELLOW}⚠️  Homebrew installation failed${NC}"
        fi
    else
        echo -e "${RED}❌ Error: No package manager found (pip3, pip, or brew)${NC}"
        echo "Please install Python pip or Homebrew first:"
        echo "  Homebrew: https://brew.sh/"
        echo "  Python: https://www.python.org/downloads/"
        exit 1
    fi
    
    # Check if installation was successful
    if command_exists esptool.py; then
        echo -e "${GREEN}✅ esptool installed successfully${NC}"
    else
        echo -e "${YELLOW}⚠️  esptool may need PATH update. Trying common locations...${NC}"
        # Add common pip install locations to PATH for this session
        export PATH="$PATH:$HOME/.local/bin"
        
        # Also try Python user site packages (common on macOS)
        if command -v python3 >/dev/null 2>&1; then
            PYTHON_USER_BASE=$(python3 -m site --user-base 2>/dev/null || echo "")
            if [ -n "$PYTHON_USER_BASE" ]; then
                export PATH="$PATH:$PYTHON_USER_BASE/bin"
            fi
        fi
        
        # Try Homebrew locations
        if [ -d "/opt/homebrew/bin" ]; then
            export PATH="$PATH:/opt/homebrew/bin"
        fi
        if [ -d "/usr/local/bin" ]; then
            export PATH="$PATH:/usr/local/bin"
        fi
        
        # Check again
        if command_exists esptool.py; then
            echo -e "${GREEN}✅ esptool found in user directory${NC}"
        else
            echo -e "${RED}❌ Error: esptool installation may have failed${NC}"
            echo ""
            echo -e "${YELLOW}Manual installation options:${NC}"
            echo "1. Try: pip3 install --user esptool"
            echo "2. Try: brew install esptool"
            echo "3. Or install via: python3 -m pip install --user esptool"
            echo ""
            echo "Then run this script again."
            exit 1
        fi
    fi
}

# Check for esptool
echo -e "${YELLOW}🔍 Checking for esptool...${NC}"
if ! command_exists esptool.py; then
    echo "esptool.py not found."
    read -p "Install esptool? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        install_esptool
    else
        echo -e "${RED}❌ esptool is required for flashing. Exiting.${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✅ esptool.py found${NC}"
fi

echo ""

# Function to find ESP32 device
find_esp32_device() {
    echo -e "${YELLOW}🔍 Scanning for ESP32 devices...${NC}"
    
    # Common ESP32 device patterns on Mac
    DEVICES=$(ls /dev/cu.usbserial-* /dev/cu.SLAB_USBtoUART* /dev/cu.usbmodem* /dev/cu.wchusbserial* 2>/dev/null || true)
    
    if [ -z "$DEVICES" ]; then
        echo -e "${RED}❌ No ESP32 devices found${NC}"
        echo ""
        echo -e "${YELLOW}Troubleshooting:${NC}"
        echo "1. Connect your Heltec V3 via USB-C cable"
        echo "2. Install CP210x or CH340 drivers if needed"
        echo "3. Put device in download mode:"
        echo "   - Hold BOOT button"
        echo "   - Press and release RESET button"
        echo "   - Release BOOT button"
        echo ""
        echo "Available USB devices:"
        system_profiler SPUSBDataType | grep -A 5 -B 5 -i "esp32\|heltec\|ch340\|cp210\|silicon labs" || echo "No relevant USB devices found"
        exit 1
    fi
    
    echo -e "${GREEN}📱 Found potential devices:${NC}"
    echo "$DEVICES" | nl -w2 -s') '
    
    DEVICE_COUNT=$(echo "$DEVICES" | wc -l | tr -d ' ')
    
    if [ "$DEVICE_COUNT" -eq 1 ]; then
        SELECTED_DEVICE="$DEVICES"
        echo -e "${GREEN}✅ Using: $SELECTED_DEVICE${NC}"
    else
        echo ""
        read -p "Select device number (1-$DEVICE_COUNT): " DEVICE_NUM
        SELECTED_DEVICE=$(echo "$DEVICES" | sed -n "${DEVICE_NUM}p")
        if [ -z "$SELECTED_DEVICE" ]; then
            echo -e "${RED}❌ Invalid selection${NC}"
            exit 1
        fi
        echo -e "${GREEN}✅ Selected: $SELECTED_DEVICE${NC}"
    fi
}

# Function to flash firmware
flash_firmware() {
    echo ""
    echo -e "${BLUE}🚀 Starting firmware flash...${NC}"
    echo -e "${YELLOW}📋 Flash details:${NC}"
    echo "  Device: $SELECTED_DEVICE"
    echo "  Firmware: $(basename "$MERGED_FIRMWARE")"
    echo "  Baud rate: $BAUD_RATE"
    if [ "$ERASE_FLASH" = true ]; then
        echo "  Erase flash: YES (⚠️  Will destroy all data)"
    else
        echo "  Erase flash: NO (preserves data partition)"
    fi
    echo ""
    
    echo -e "${YELLOW}⚠️  Make sure your device is in download mode:${NC}"
    echo "   - Hold BOOT button"
    echo "   - Press and release RESET button"
    echo "   - Release BOOT button"
    echo ""
    
    read -p "Press Enter to continue with flashing..."
    
    # Erase flash if requested
    if [ "$ERASE_FLASH" = true ]; then
        echo -e "${YELLOW}🧹 Erasing flash memory...${NC}"
        echo -e "${RED}⚠️  WARNING: This will destroy all data on the device!${NC}"
        if esptool.py --chip esp32s3 --port "$SELECTED_DEVICE" --baud "$BAUD_RATE" erase_flash; then
            echo -e "${GREEN}✅ Flash erased successfully${NC}"
            sleep 1
        else
            echo -e "${RED}❌ Flash erase failed${NC}"
            return 1
        fi
    fi
    
    # Try high-speed flash first
    echo -e "${YELLOW}🔥 Attempting high-speed flash (${BAUD_RATE} baud)...${NC}"
    if esptool.py --chip esp32s3 --port "$SELECTED_DEVICE" --baud "$BAUD_RATE" write_flash 0x0 "$MERGED_FIRMWARE"; then
        echo -e "${GREEN}✅ Firmware flashed successfully!${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠️  High-speed flash failed. Trying slower speed...${NC}"
        
        # Try slower flash
        echo -e "${YELLOW}🐌 Attempting low-speed flash (${FALLBACK_BAUD} baud)...${NC}"
        if esptool.py --chip esp32s3 --port "$SELECTED_DEVICE" --baud "$FALLBACK_BAUD" write_flash 0x0 "$MERGED_FIRMWARE"; then
            echo -e "${GREEN}✅ Firmware flashed successfully!${NC}"
            return 0
        else
            echo -e "${RED}❌ Flash failed at both speeds${NC}"
            echo ""
            echo -e "${YELLOW}💡 Troubleshooting tips:${NC}"
            echo "1. Ensure device is in download mode (BOOT + RESET sequence)"
            echo "2. Try holding BOOT button during entire flash process"
            echo "3. Try a different USB cable"
            echo "4. Check USB drivers (CP210x/CH340) are installed"
            echo "5. Try different USB port or restart computer"
            echo ""
            echo -e "${BLUE}ℹ️  Note: This flash preserves your data partition and settings${NC}"
            return 1
        fi
    fi
}

# Function to monitor serial output
monitor_serial() {
    echo ""
    echo -e "${BLUE}📺 Serial Monitor${NC}"
    echo -e "${YELLOW}Press Ctrl+C to exit monitor${NC}"
    echo ""
    
    # Reset device first
    echo -e "${YELLOW}🔄 Resetting device... Press RESET button now${NC}"
    sleep 2
    
    if command_exists screen; then
        echo -e "${GREEN}Starting serial monitor (screen)...${NC}"
        echo "Commands: Ctrl+A then K to exit"
        sleep 1
        screen "$SELECTED_DEVICE" 115200
    elif command_exists minicom; then
        echo -e "${GREEN}Starting serial monitor (minicom)...${NC}"
        minicom -D "$SELECTED_DEVICE" -b 115200
    else
        echo -e "${YELLOW}⚠️  No serial monitor found (screen/minicom)${NC}"
        echo "Install with: brew install screen"
        echo "Or use Arduino IDE Serial Monitor"
        echo ""
        echo "Manual connection:"
        echo "  Device: $SELECTED_DEVICE"
        echo "  Baud rate: 115200"
    fi
}

# Main execution
echo -e "${YELLOW}🔍 Step 1: Finding ESP32 device...${NC}"
find_esp32_device

echo ""
echo -e "${YELLOW}🔥 Step 2: Flashing firmware...${NC}"
if flash_firmware; then
    echo ""
    echo -e "${GREEN}🎉 SUCCESS! Firmware flashed successfully${NC}"
    echo ""
    echo -e "${BLUE}📋 Next steps:${NC}"
    echo "1. Press RESET button on device"
    echo "2. Monitor serial output to verify Wi-Fi connection"
    echo "3. Look for connection to 'wifi' network"
    echo ""
    
    read -p "Monitor serial output now? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        monitor_serial
    else
        echo -e "${YELLOW}💡 To monitor later:${NC}"
        echo "  screen $SELECTED_DEVICE 115200"
        echo "  (Press Ctrl+A then K to exit)"
    fi
    
    echo ""
    echo -e "${GREEN}✅ Flashing complete!${NC}"
    echo -e "${YELLOW}⚠️  Remember: This firmware contains your Wi-Fi credentials${NC}"
    
else
    echo ""
    echo -e "${RED}❌ Flashing failed${NC}"
    echo "Check troubleshooting tips above and try again"
    exit 1
fi