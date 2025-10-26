# Use Ubuntu as the base image instead of Red Hat
FROM ubuntu:24.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV PATH="/root/.platformio/penv/bin:${PATH}"

# Install system dependencies
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    curl \
    git \
    build-essential \
    vim \
    wget \
    && rm -rf /var/lib/apt/lists/*

# No additional templating tools needed - we'll do simple replacements

# Install PlatformIO
RUN curl -fsSL -o get-platformio.py https://raw.githubusercontent.com/platformio/platformio-core-installer/master/get-platformio.py && \
    python3 get-platformio.py

# Create working directory
WORKDIR /workspace

# Create output directory for firmware and build cache
RUN mkdir -p /output /build-cache

# Set PlatformIO environment variables to use cache directory
ENV PLATFORMIO_CORE_DIR="/build-cache/.platformio"
ENV PLATFORMIO_PLATFORMS_DIR="/build-cache/.platformio/platforms"
ENV PLATFORMIO_PACKAGES_DIR="/build-cache/.platformio/packages"

# Copy the build script from resources folder
COPY resources/build-firmware.sh /usr/local/bin/build-firmware.sh
RUN chmod +x /usr/local/bin/build-firmware.sh

# Set the default command
CMD ["/usr/local/bin/build-firmware.sh"]