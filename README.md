# MeshCore Wi-Fi Firmware Builder

This project provides a Docker-based build system for compiling MeshCore firmware with Wi-Fi capabilities for the Heltec V3 device.

## ⚠️ Disclaimer

This build system was "vibe coded 🤮" with GitHub Copilot based on the excellent work and documentation at [Ottawa Mesh - MeshCore/Heltekv3Wifi](https://ottawamesh.ca/index.php?title=MeshCore/Heltekv3Wifi). All credit for the underlying firmware and Wi-Fi implementation goes to the MeshCore development team and the Ottawa Mesh community.

## ⚠️ Security Warning

**IMPORTANT**: Your Wi-Fi credentials are embedded in the compiled firmware at build time. **Do not share the compiled binary files publicly** if they contain your real Wi-Fi credentials.

## Testing info

Tested with MeshCore 1.9.1 (commit: b2dcb06197897807fafb539c2710b2aa352792ee)
https://github.com/meshcore-dev/MeshCore/commit/b2dcb06197897807fafb539c2710b2aa352792ee


## Features

- **Docker-based**: Clean, reproducible build environment using Ubuntu 24.04
- **Automated Wi-Fi Configuration**: Simple sed-based replacement of Wi-Fi credentials in git repository
- **Git-based Versioning**: Uses whatever version is current in the MeshCore repository
- **Fresh Repository**: Always pulls the latest MeshCore code at build time
- **Safe Output**: Generates firmware files with clear naming and build information
- **Build Caching**: Caches PlatformIO tools and dependencies for subsequent builds

## Quick Start

1. **Build and run with your Wi-Fi credentials:**
   ```bash
   ./run-build.sh --ssid "YourWiFiName" --password "YourWiFiPassword"
   ```

2. **Flash the generated firmware** to your Heltec V3 device using your preferred flashing tool.

## Usage

### Basic Usage
```bash
./run-build.sh --ssid "MyWiFi" --password "MyPassword"
```

### Advanced Usage
```bash
# Enable debug logging
./run-build.sh --ssid "MyWiFi" --password "MyPassword" --enable-debug

# Custom output directory
./run-build.sh --ssid "MyWiFi" --password "MyPassword" --output "/path/to/output"

# Build Docker image only (for testing)
./run-build.sh --build-only

# Run without rebuilding Docker image
./run-build.sh --ssid "MyWiFi" --password "MyPassword" --no-build
```

### All Options
- `-s, --ssid SSID`: Wi-Fi SSID (required)
- `-p, --password PASSWORD`: Wi-Fi password (required)
- `-o, --output DIR`: Output directory (default: ./firmware-output)
- `-c, --cache DIR`: Cache directory (default: ./build-cache)
- `--max-contacts NUM`: Maximum contacts (default: 300)
- `--max-channels NUM`: Maximum group channels (default: 8)
- `--enable-debug`: Enable mesh debug logging
- `--enable-packet-log`: Enable mesh packet logging
- `--build-only`: Only build the Docker image, don't run
- `--no-build`: Skip building Docker image, just run
- `--clear-cache`: Clear the build cache before running
- `-h, --help`: Show help message

## Output Files

The build process generates the following files in the output directory:

- `Heltec_v3_companion_radio_wifi.bin`: Main firmware file
- `Heltec_v3_companion_radio_wifi-merged.bin`: Merged firmware (bootloader + firmware)
- `build-info.txt`: Build information and flashing instructions

## Flashing on Mac

Use the included Mac flashing script:

```bash
# Safe mode (preserves data partition)
./flash-mac.sh

# Full erase mode (destroys all data)
./flash-mac.sh --erase

# Show help
./flash-mac.sh --help
```

The script will:
- Auto-install esptool if needed
- Auto-detect your Heltec V3 device
- Flash the firmware with error handling
- Offer serial monitoring to verify Wi-Fi connection

## Caching System

The build system includes caching for subsequent builds:

### How It Works
- **First build**: Downloads PlatformIO tools and ESP32 toolchain
- **Subsequent builds**: Reuses cached tools, only compiles firmware
- **Cache location**: `./build-cache/` directory (automatically created)

### Cache Management
```bash
# Check cache status (automatically shown during build)
ls -la build-cache/

# Clear cache if needed
./run-build.sh --ssid "MyWiFi" --password "MyPass" --clear-cache

# Use custom cache location
./run-build.sh --ssid "MyWiFi" --password "MyPass" --cache "/path/to/cache"
```

## Requirements

- Docker
- macOS, Linux, or Windows with WSL2
- Internet connection (to clone the latest MeshCore repository)



## Architecture

### Docker Image
- **Base**: Ubuntu 24.04 (opensource alternative to Red Hat)
- **Build Tools**: PlatformIO, Python 3, Git, GCC
- **Process**: Clones latest MeshCore, directly replaces Wi-Fi placeholders, builds firmware

### Build Process
1. Clone/update MeshCore repository from GitHub
2. Replace Wi-Fi placeholders (`myssid`/`mypwd`) in platformio.ini using sed
3. Build firmware using PlatformIO  
4. Generate firmware files with clear naming
5. Create build information file

## Troubleshooting

### Build Failures
- Check Docker is running and accessible
- Ensure you have internet connectivity
- Verify Wi-Fi credentials don't contain special characters that might break the build

### Missing Files
- The build script will show available variants if the expected platformio.ini is not found
- Check the build output for specific error messages

### Docker Issues
- Use `docker system prune` to clean up old images if space is an issue
- Rebuild the Docker image with `./run-build.sh --build-only`

## Manual Docker Usage

If you prefer to run Docker commands manually:

```bash
# Build the image
docker build -t meshcore-builder .

# Run the build
docker run --rm \
    -e WIFI_SSID="YourSSID" \
    -e WIFI_PWD="YourPassword" \
    -v "$(pwd)/firmware-output:/output" \
    -v "$(pwd)/build-cache:/build-cache" \
    meshcore-builder
```

## License

This build system is released under the Creative Commons CC0 1.0 Universal License.

[![CC0](https://licensebuttons.net/p/zero/1.0/88x31.png)](https://creativecommons.org/publicdomain/zero/1.0/)

This work is dedicated to the public domain. You can copy, modify, distribute and perform the work, even for commercial purposes, all without asking permission. See the [LICENSE](LICENSE) file for full legal text.

The MeshCore firmware itself is subject to its own license terms. This build system just automates the compilation process documented by the Ottawa Mesh community.

## Attribution

This build automation was created based on the excellent documentation at:
- **[Ottawa Mesh - MeshCore/Heltekv3Wifi](https://ottawamesh.ca/index.php?title=MeshCore/Heltekv3Wifi)**

All credit for the underlying MeshCore firmware and Wi-Fi implementation goes to:
- The MeshCore development team
- The Ottawa Mesh community
- All contributors to the MeshCore project

This repository just provides Docker-based build automation for convenience. 🤖