FROM build-base:dev

# pull down the qt5 repos
RUN git clone --branch=5.15 https://github.com/qt/qt5.git /opt/qt5 && \
    cd /opt/qt5 && git checkout b78a4dc89344bd3069f75496b5978500ed124828 && \
    cd /opt/qt5 && git submodule update --init --recursive

# configure
RUN mkdir -p /build && mkdir -p /opt/qt5-wasm
RUN sed -i "s/\-O2/-O3/g" /opt/qt5/qtbase/mkspecs/wasm-emscripten/qmake.conf
RUN cd /opt/qt5-wasm && \
    emconfigure ../qt5/configure \
      -xplatform wasm-emscripten \
      -feature-thread \
      -gui \
      -widgets \
      -opengl \
      -opensource \
      -confirm-license \
      -ccache \
      -qt-zlib \
      -qt-freetype \
      -egl \
      -extprefix /build 2>&1 | tee /opt/qt5.configure.log

# patch
ADD ./qt5.qtbase.patch /opt/qt5.qtbase.patch
RUN cd /opt/qt5/qtbase && git apply /opt/qt5.qtbase.patch

# build/install
RUN cd /opt/qt5-wasm && emmake make -j6 install 2>&1 | tee /opt/qt5.make.log
