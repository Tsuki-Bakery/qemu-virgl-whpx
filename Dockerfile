FROM fedora:latest

# Define build arguments and environment variables
ARG OUTPUT_DIR=/output
ENV OUTPUT_DIR=${OUTPUT_DIR}

# Set optimal number of build jobs based on available cores
ENV BUILD_JOBS=4

RUN dnf update -y && \
    dnf install -y mingw64-gcc \
                mingw64-glib2 \
                mingw64-pixman \
                mingw64-SDL2 \
                git \
                make \
                flex \
                bison \
                python \
                autoconf \
                automake \
                libtool \
                pkg-config \
                xorg-x11-util-macros \
                meson \
                ninja-build \
                mingw64-meson \
                mingw64-cmake \
                cmake \
                ccache

# Set up ccache
ENV PATH="/usr/lib/ccache:${PATH}"
ENV CCACHE_DIR="/ccache"

COPY angle/include/ /usr/x86_64-w64-mingw32/sys-root/mingw/include/
COPY angle/egl.pc /usr/x86_64-w64-mingw32/sys-root/mingw/lib/pkgconfig/
COPY angle/glesv2.pc /usr/x86_64-w64-mingw32/sys-root/mingw/lib/pkgconfig/
COPY WinHv*.h /usr/x86_64-w64-mingw32/sys-root/mingw/include/

RUN git clone https://github.com/anholt/libepoxy.git && \
    cd libepoxy && \
    mingw64-meson builddir -Dtests=false -Degl=yes -Dglx=no -Dx11=false && \
    ninja -C builddir -j4 && \
    ninja -C builddir install

RUN git clone https://github.com/matthias-prangl/virglrenderer.git && \
    cd virglrenderer && \
    export NOCONFIGURE=1 && \
    ./autogen.sh && \
    mingw64-configure --disable-egl && \
    make -j${BUILD_JOBS} && \
    make install

RUN git clone https://github.com/matthias-prangl/qemu.git && \
    cd qemu && \
    export NOCONFIGURE=1 && \
    ./configure --target-list=x86_64-softmmu \
    --prefix=/qemu_win \
    --cross-prefix=x86_64-w64-mingw32- \    
    --enable-whpx \
    --enable-virglrenderer \
    --enable-opengl \
    --enable-debug \
    --disable-stack-protector \
    --enable-sdl && \
    make -j${BUILD_JOBS} && make install

# Copy required libraries to output directory
RUN mkdir -p ${OUTPUT_DIR}/bin && \
    cp /usr/x86_64-w64-mingw32/sys-root/mingw/bin/*.dll ${OUTPUT_DIR}/bin/ || true

# Create a script to copy files to the mounted volume
RUN echo '#!/bin/sh' > /copy-output.sh && \
    echo 'cp -r ${OUTPUT_DIR}/* /mnt/output/' >> /copy-output.sh && \
    echo 'echo "Build artifacts copied to output directory"' >> /copy-output.sh && \
    chmod +x /copy-output.sh

# Set the default command to copy outputs
CMD ["/copy-output.sh"]