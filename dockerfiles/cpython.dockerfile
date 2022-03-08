FROM build-base:dev

# clone cpython 3.11
ARG CPYTHON_COMMIT="d81182b8ec3b1593daf241d44757a9fa68fd14cc"
RUN git clone https://github.com/python/cpython.git /opt/cpython && \
    cd /opt/cpython && git checkout ${CPYTHON_COMMIT}

# patch i386 python
RUN mkdir -p /opt/cpython/i386
COPY ./patches/cpython.i386.patch /opt/cpython/cpython.i386.patch
RUN cd /opt/cpython && \
    git reset --hard && \
    git apply ./cpython.i386.patch

# configure
RUN mkdir -p /opt/cpython/i386 && cd /opt/cpython/i386 && \
    ../configure CFLAGS="-m32 -march=i386 -static" \
                 LDFLAGS="-m32 -march=i386" \
                 --prefix=$(pwd)

# build/install i386 python interpreter w/ pip
RUN cd /opt/cpython/i386 && make -j install
RUN /opt/cpython/i386/bin/python3.11 -m pip install --upgrade pip

# build/install libffi-emscripten
RUN git clone --depth=1 https://github.com/hoodmane/libffi-emscripten /opt/libffi-emscripten
RUN cd /opt/libffi-emscripten && ./build.sh
RUN mkdir -p /build/libffi-emscripten && cp -r /opt/libffi-emscripten/target/* /build/

# build flags for the wasm python interpreter (and for builds in child containers)
ENV CFLAGS="-pthread -O3 -static"
ENV LDFLAGS="-pthread \
-s USE_ZLIB \
-s WASM_BIGINT \
-s USE_PTHREADS \
-s ALLOW_MEMORY_GROWTH \
-s LLD_REPORT_UNDEFINED \
-s ERROR_ON_UNDEFINED_SYMBOLS=0 \
-s EXIT_RUNTIME \
-lnodefs.js -s NODERAWFS -s FORCE_FILESYSTEM"
ENV LINKFORSHARED="${LDFLAGS}"

# patch cpython for the wasm build
RUN mkdir -p /opt/cpython/wasm
COPY ./patches/cpython.wasm.patch /opt/cpython/cpython.wasm.patch
RUN cd /opt/cpython && \
    git reset --hard && \
    git apply ./cpython.wasm.patch

# configure
RUN cd /opt/cpython/wasm && \
    emconfigure ../configure \
    CONFIG_SITE=/opt/cpython/wasm/config.site \
    SHLIB_SUFFIX=".bc" \
    --with-static-libpython \
    --disable-shared \
    --without-ensurepip \
    --without-pymalloc \
    --prefix=/opt/cpython/wasm

# build/install the wasm interpreter (w/ NodeFS support)
RUN cd /opt/cpython/wasm && make -j install && \
    cp /opt/cpython/wasm/python.wasm /opt/cpython/wasm/bin/ && \
    cp /opt/cpython/wasm/python.worker.js /opt/cpython/wasm/bin/

# configure the i386 python interpreter to ues the wasm python configuration
# - used for eg. freezing wasm python modules
RUN cp /opt/cpython/i386/bin/python3.11 /opt/cpython/wasm/bin/python3.11-i386
RUN cp /opt/cpython/wasm/lib/python3.11/_sysconfigdata__linux_.py /opt/cpython/wasm/lib/python3.11/_sysconfigdata__linux_x86_64-linux-gnu.py
RUN cp -r /opt/cpython/i386/lib/python3.11/lib-dynload/. /opt/cpython/wasm/lib/python3.11/lib-dynload/

# install pip for i386 python
# - i386 python wheel
# - used to cross-compile wasm python modules w/ source from pip
RUN /opt/cpython/wasm/bin/python3.11-i386 -m ensurepip
RUN /opt/cpython/wasm/bin/python3.11-i386 -m pip install --upgrade pip

# copy source and build output w/o the .git directory
RUN rm -rf /opt/cpython/.git && \
    cp -r /opt/cpython /build/cpython
