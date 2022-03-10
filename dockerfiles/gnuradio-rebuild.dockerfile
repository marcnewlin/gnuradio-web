FROM gnuradio:dev

# add source files from scratch
ADD ./scratch/buffer_double_mapped.cc /opt/gnuradio/gnuradio-runtime/lib/
ADD ./scratch/buffer.cc /opt/gnuradio/gnuradio-runtime/lib/
ADD ./scratch/buffer_double_mapped.h /opt/gnuradio/gnuradio-runtime/include/gnuradio/
ADD ./scratch/buffer.h /opt/gnuradio/gnuradio-runtime/include/gnuradio/
ADD ./scratch/thread.cc /opt/gnuradio/gnuradio-runtime/lib/thread/

# rebuild gnuradio
RUN cd /opt/gnuradio/build/gnuradio-runtime && \
    emmake make -j install
RUN cd /opt/gnuradio/build && \
    emmake make \
    CC="ccache /opt/emsdk/upstream/emscripten/emcc" \
    CXX="ccache /opt/emsdk/upstream/emscripten/em++" \
    HOST_CC="ccache /opt/emsdk/upstream/bin/clang" \
    HOST_CXX="ccache /opt/emsdk/upstream/bin/clang++" \
    GR_PREFIX=/build \
    -j6 install

# final web config for the pytho interpreter
RUN cd /opt/cpython/wasm && rm -f ./python && emmake make FREEZE_MODULE_BOOTSTRAP=/opt/cpython/wasm/bin/python3.11-i386 PYTHON_FOR_FREEZE=/opt/cpython/wasm/bin/python3.11-i386 FREEZE_MODULE="/opt/cpython/wasm/Programs/_freeze_module" -n python | sed "s/\-lnodefs.js \-s NODERAWFS/--bind -s USE_FREETYPE -s USE_PTHREADS -s EXPORTED_RUNTIME_METHODS=['stringToUTF16'] -s PTHREAD_POOL_SIZE_STRICT=0 -g1 --std=c++17 -s LZ4=1 -O3 -s ASSERTIONS/g" | sed "s/\-s INITIAL_MEMORY=1gb//g" > /opt/cpython/wasm/python-build-command.txt

# prepare output directory (static assets)
RUN cd /opt/cpython/wasm && cp -r share lib/ && cp -r etc lib/
RUN echo "[grc] \n\
global_blocks_path = /lib/share/gnuradio/grc/blocks \n\
local_blocks_path = \n\
default_flow_graph = \n\
xterm_executable =  \n\
canvas_font_size = 8 \n\
canvas_default_size = 1280, 1024 \n\
enabled_components = python-support;gnuradio-runtime;gnuradio-companion;gr-blocks;gr-digital;gr-analog;gr-channels;gr-filter;gr-fft;gr-pdu;gr-qtgui \n\
" > /opt/cpython/wasm/lib/etc/gnuradio/conf.d/grc.conf

# final build
RUN cd /opt/cpython/wasm && bash /opt/cpython/wasm/python-build-command.txt
RUN cp /opt/cpython/wasm/python* /opt/cpython/wasm/bin/
RUN mkdir -p /build/base && \
    cp -r /opt/cpython/wasm /build/base/ && \
    cp /build/base/wasm/python /build/base/wasm/python.js
