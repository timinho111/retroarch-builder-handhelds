FROM arm64v8/debian:buster

ENV DEBIAN_FRONTEND=noninteractive CMAKE_VERSION=3.26.4
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
        libgbm-dev && \
    # Create a symlink for the DRM headers, which RetroArch expects
    ln -s /usr/include/libdrm /usr/include/drm && \
    # Clean up apt cache
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN cd /tmp && \
    wget https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-linux-aarch64.sh && \
    chmod +x cmake-${CMAKE_VERSION}-linux-aarch64.sh && \
    ./cmake-${CMAKE_VERSION}-linux-aarch64.sh --skip-license --prefix=/usr/local && \
    rm -f cmake-${CMAKE_VERSION}-linux-aarch64.sh

RUN pip3 install --upgrade meson

RUN cd /tmp && \
    git clone --depth=1 https://github.com/libsdl-org/SDL.git && \
    cd SDL && \
    mkdir build && cd build && \
    cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr -DSDL_STATIC=OFF -DSDL_VIDEO_WAYLAND=OFF -DSDL_VIDEO_X11=OFF -DSDL_VIDEO_KMSDRM=ON && \
    make -j4 && \
    make install && \
    ldconfig && \
    cd / && rm -rf /tmp/SDL

RUN cd /tmp && \
    git clone --depth=1 https://github.com/amarula/rockchip-linux-rga.git && \
    cd rockchip-linux-rga && \
    meson setup build && \
    ninja -C build && \
    cp build/librga.so /usr/local/lib/ && \
    mkdir -p /usr/local/include/rga && \
    cp *.h /usr/local/include/rga/ && \
    ldconfig && \
    cd / && rm -rf /tmp/rockchip-linux-rga

RUN cd /tmp && \
    git clone --depth=1 https://github.com/libretro/RetroArch.git && \
    cd RetroArch && \
    ./configure --enable-kms --enable-egl --disable-x11 --disable-wayland --enable-rga && \
    make -j4

RUN mkdir -p /build_output/bin && \
    cp /tmp/RetroArch/retroarch /build_output/bin/ && \
    cp /tmp/RetroArch/retroarch.cfg /build_output/
