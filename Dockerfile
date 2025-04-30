FROM fedora:latest

# Define build arguments and environment variables
ARG WINHP_HEADER_URL=https://raw.githubusercontent.com/MicrosoftDocs/Virtualization-Documentation/refs/heads/main/virtualization/api/hypervisor-platform/headers/
ARG OUTPUT_DIR=/output
ENV OUTPUT_DIR=${OUTPUT_DIR}

RUN dnf update -y && \
    dnf install -y mingw64-gcc \
                mingw64-glib2 \
                mingw64-pixman \
                mingw64-gtk3 \
                mingw64-SDL2 \
                git \
                make \
                flex \
                bison \
                python \
                python3-pyyaml \
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
                ccache \
                diffutils 

ENV PATH="/usr/lib/ccache:${PATH}"
ENV CCACHE_DIR="/ccache"

COPY angle/include/ /usr/x86_64-w64-mingw32/sys-root/mingw/include/
COPY angle/egl.pc /usr/x86_64-w64-mingw32/sys-root/mingw/lib/pkgconfig/
COPY angle/glesv2.pc /usr/x86_64-w64-mingw32/sys-root/mingw/lib/pkgconfig/

RUN git clone https://github.com/anholt/libepoxy.git --depth 1 && \
    cd libepoxy && \
    mingw64-meson build -Dtests=false -Degl=yes -Dglx=no -Dx11=false && \
    ninja -C build -j`nproc` && \
    ninja -C build install

RUN mkdir -p virglrenderer && \
    cd virglrenderer && \
    curl -L https://gitlab.freedesktop.org/virgl/virglrenderer/-/archive/1.1.1/virglrenderer-1.1.1.tar.gz -o virglrenderer.tar.gz && \
    tar -xzf virglrenderer.tar.gz --strip-components=1 && \
    mingw64-meson build -Dplatforms=egl -Dminigbm_allocation=false && \
    ninja -C build install

RUN git clone https://gitlab.freedesktop.org/slirp/libslirp.git --depth 1 && \
    cd libslirp && \
    mingw64-meson build && \
    ninja -C build -j`nproc` && \
    ninja -C build install

RUN curl -L ${WINHP_HEADER_URL}/WinHvPlatform.h -o /usr/x86_64-w64-mingw32/sys-root/mingw/include/WinHvPlatform.h && \
    curl -L ${WINHP_HEADER_URL}/WinHvPlatformDefs.h -o /usr/x86_64-w64-mingw32/sys-root/mingw/include/WinHvPlatformDefs.h && \
    curl -L ${WINHP_HEADER_URL}/WinHvEmulation.h  -o /usr/x86_64-w64-mingw32/sys-root/mingw/include/WinHvEmulation.h

RUN git clone --branch master --single-branch --depth 1 https://github.com/qemu/qemu.git && \
    cd qemu && \
    sed -i 's/SDL_SetHint(SDL_HINT_ANGLE_BACKEND, "d3d11");/#ifdef SDL_HINT_ANGLE_BACKEND\n            SDL_SetHint(SDL_HINT_ANGLE_BACKEND, "d3d11");\n#endif/' ui/sdl2.c && \
    sed -i 's/SDL_SetHint(SDL_HINT_ANGLE_FAST_PATH, "1");/#ifdef SDL_HINT_ANGLE_FAST_PATH\n            SDL_SetHint(SDL_HINT_ANGLE_FAST_PATH, "1");\n#endif/' ui/sdl2.c && \
    export NOCONFIGURE=1 && \
    ./configure --target-list=x86_64-softmmu \
    --prefix="${OUTPUT_DIR}" \    
    --cross-prefix=x86_64-w64-mingw32- \    
    --enable-whpx \
    --enable-virglrenderer \
    --enable-opengl \
    --enable-gtk \
    --enable-debug \
    --enable-slirp \
    --disable-stack-protector \
    --disable-werror \
    --enable-sdl && \
    make -j`nproc` && make install

RUN cp /usr/x86_64-w64-mingw32/sys-root/mingw/bin/*.dll ${OUTPUT_DIR}/ && \
    curl -L https://raw.githubusercontent.com/mozilla/fxc2/master/dll/d3dcompiler_47.dll -o ${OUTPUT_DIR}/d3dcompiler_47.dll && \
    curl -L https://archlinux.org/packages/extra/any/edk2-ovmf/download/ -o edk2-ovmf.tar.zst && \
    mkdir -p ${OUTPUT_DIR}/share && \
    tar --zstd -xvf edk2-ovmf.tar.zst --wildcards 'usr/share/edk2/*' -C /tmp && \
    cp -r usr/share/edk2 ${OUTPUT_DIR}/share/ && \
    rm -rf /tmp/usr

RUN echo '#!/bin/sh' > /copy-output.sh && \
    echo 'cp -r ${OUTPUT_DIR}/* /mnt/output/' >> /copy-output.sh && \
    echo 'echo "Build artifacts copied to output directory"' >> /copy-output.sh && \
    chmod +x /copy-output.sh

CMD ["/copy-output.sh"]
