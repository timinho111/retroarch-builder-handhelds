# Use Debian Buster for ARM64 as the base image, which matches the working build's compiler
FROM arm64v8/debian:buster

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive CMAKE_VERSION=3.26.4

# ==============================================================================
# SECTION 1: INSTALL ALL SYSTEM DEPENDENCIES
# ==============================================================================
# We install a minimal set of required -dev packages validated by your screenshots
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential \
        git \
        wget \
        python3 \
        python3-pip \
        ninja-build \
        pkg-config \
        libudev-dev \
        libdrm-dev \
        libegl1-mesa-dev \
        libgles2-mesa-dev \
        libgl1-mesa-dev \
        libasound2-dev \
        libgbm-dev \
        zlib1g-dev \
        libpng-dev && \
    # Create a symlink for the DRM headers, which RetroArch expects
    ln -s /usr/include/libdrm /usr/include/drm && \
    # Clean up apt cache
    apt-get clean && rm -rf /var/lib/apt/lists/*


# ==============================================================================
# SECTION 2: MANUALLY INSTALL MODERN BUILD TOOLS
# ==============================================================================

# Manually install a modern version of CMake, required for SDL2
RUN cd /tmp && \
    wget https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-linux-aarch64.sh && \
    chmod +x cmake-${CMAKE_VERSION}-linux-aarch64.sh && \
    ./cmake-${CMAKE_VERSION}-linux-aarch64.sh --skip-license --prefix=/usr/local && \
    rm -f cmake-${CMAKE_VERSION}-linux-aarch64.sh

# Manually install a recent version of Meson (Dependency removed as librga is not built)
# RUN pip3 install --upgrade meson


# ==============================================================================
# SECTION 3: MANUALLY BUILD AND INSTALL REQUIRED LIBRARIES
# ==============================================================================

# Manually build and install SDL2 with specific features for our device
RUN cd /tmp && \
    git clone --depth=1 https://github.com/libsdl-org/SDL.git && \
    cd SDL && \
    mkdir build && cd build && \
    cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr -DSDL_STATIC=OFF -DSDL_VIDEO_WAYLAND=OFF -DSDL_VIDEO_X11=OFF -DSDL_VIDEO_KMSDRM=ON && \
    make -j4 && \
    make install && \
    ldconfig && \
    cd / && rm -rf /tmp/SDL

# NOTE: The entire section for building librga has been REMOVED.

# ==============================================================================
# SECTION 4: BUILD RETROARCH V1.21.0 AND PREPARE OUTPUT
# ==============================================================================

# Clone the full repo, checkout the specific v1.21.0 tag, and build RetroArch
# The configuration flags are now tailored to match your working build.
RUN cd /tmp && \
    git clone https://github.com/libretro/RetroArch.git && \
    cd RetroArch && \
    git checkout v1.21.0 && \
    export CFLAGS="-O2 -march=armv8-a -mtune=cortex-a55 -s" && \
    export LDFLAGS="-s" && \
    ./configure \
      --enable-kms \
      --enable-egl \
      --enable-opengles \
      --enable-udev \
      --enable-alsa \
      --disable-x11 \
      --disable-wayland && \
    make -j4

# Create a clean output directory and copy only the essential final files into it
RUN mkdir -p /build_output/bin && \
    cp /tmp/RetroArch/retroarch /build_output/bin/ && \
    cp /tmp/RetroArch/retroarch.cfg /build_output/
