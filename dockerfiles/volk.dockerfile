FROM cpython:dev

# install mako (i386 wheel via pip)
RUN /opt/cpython/wasm/bin/python3.11-i386 -m pip install mako

# clone
RUN git clone https://github.com/gnuradio/volk.git /opt/volk && \
    cd /opt/volk && git checkout ce4e4a00fc953f3451bfcdd4310b03785d8b4055
RUN cd /opt/volk && git submodule update --init --recursive

# configure
RUN mkdir -p /opt/volk/build
RUN cd /opt/volk/build && emcmake cmake \
    CFLAGS="${CFLAGS}" \
    -DCMAKE_INSTALL_PREFIX=/build/volk \
    -DPYTHON_EXECUTABLE=/opt/cpython/wasm/bin/python3.11-i386 \
    -DVOLK_CPU_FEATURES=OFF ../
RUN sed -i 's/if(neon_compile_result)/if(0)/g' /opt/volk/lib/CMakeLists.txt
ADD ./volk.patch /opt/volk/volk.patch
RUN cd /opt/volk && git apply ./volk.patch

# build/install
RUN cd /opt/volk/build && emmake make -j4 install
