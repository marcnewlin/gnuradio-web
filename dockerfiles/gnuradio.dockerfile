FROM cpython:dev

# install pybind11 (built locally to wasm using source from pip)
RUN /opt/cpython/wasm/bin/python3.11-i386 \
    -m pip install --no-deps --no-binary pybind11 pybind11

# build and install mpir
RUN git clone https://github.com/wbhart/mpir.git /opt/mpir && \
    cd /opt/mpir && git checkout b3367eb13eca95b3a204beaca5281a2c3b4c66a6 && \
    git submodule update --init --recursive && \
    cd /opt/mpir && mv -f config.guess configmpir.guess && mv -f config.sub configmpir.sub && emconfigure autoreconf -isv && \
    cd /opt/mpir && emconfigure ./configure CFLAGS="${CFLAGS}" --prefix=/build/ --disable-static --enable-cxx --enable-gmpcompat --host=wasm32 && \
    echo "#undef HAVE_OBSTACK_VPRINTF" >> /opt/mpir/config.h && \
    cd /opt/mpir && emmake make -j install
#
# # build and install libfmt
# RUN git clone https://github.com/fmtlib/fmt.git /opt/fmt
# RUN cd /opt/fmt && \
#     git checkout c65e4286bf862c76e8c2e60b1f92c0edf7d52e31 && \
#     mkdir -p /opt/fmt/build
# RUN cd /opt/fmt/build && emcmake cmake -DCMAKE_INSTALL_PREFIX=/build -DFMT_TEST=OFF ../
# RUN cd /opt/fmt/build && emmake make LDFLAGS="${LDFLAGS} --std=c++17 -s EXPORT_ALL" -j install

# build and install libspdlog
RUN git clone https://github.com/gabime/spdlog.git /opt/spdlog && \
    cd /opt/spdlog && git checkout d7690d8e7eed721d78b52e032e996a5d1ef47d6f
RUN cd /opt/spdlog && git submodule update --init --recursive
RUN mkdir -p /opt/spdlog/build
# RUN cd /opt/spdlog/build && emcmake cmake -DSPDLOG_FMT_EXTERNAL=ON -Dfmt_DIR=/build/lib/cmake/fmt -DCMAKE_CXX_FLAGS="${CFLAGS} -pthread" -DCMAKE_INSTALL_PREFIX=/build -DSPDLOG_BUILD_EXAMPLE=OFF ../
RUN cd /opt/spdlog/build && emcmake cmake -DSPDLOG_FMT_EXTERNAL=OFF -DCMAKE_CXX_FLAGS="${CFLAGS} -pthread" -DCMAKE_INSTALL_PREFIX=/build -DSPDLOG_BUILD_EXAMPLE=OFF ../
RUN cd /opt/spdlog/build && emmake make -j install

# install volk (built by volk.dockerfile)
COPY ./volk /opt/volk
RUN cp -r /opt/volk/. /build/

# install boost (built by boost.dockerfile)
COPY ./boost /opt/boost
RUN cp -r /opt/boost/. /build/

# install pyqt5 (built by pyqt5.dockerfile)
COPY ./pyqt5-static /opt/pyqt5-static
RUN cd opt/pyqt5-static && \
    sed -i "s|/opt/cpython/wasm/lib/python3.11/site-packages/PyQt5|/opt/pyqt5-static|g" Setup.local && \
    sed -i "s|/opt/qt5-wasm/qtbase/lib|/opt/pyqt5-static|g" Setup.local && \
    sed -i "s|/opt/wasm-loader.bc|/opt/pyqt5-static/wasm-loader.bc|g" Setup.local
RUN echo "*static*" >> /opt/cpython/wasm/Modules/Setup.local
RUN cat /opt/pyqt5-static/Setup.local >> /opt/cpython/wasm/Modules/Setup.local
RUN cp -r /opt/pyqt5-static/module /opt/cpython/wasm/lib/python3.11/site-packages/PyQt5

# install numpy (built by numpy.dockerfile)
COPY ./numpy-static /opt/numpy-static
RUN cd /opt/numpy-static && \
    sed -i "s|/build/numpy-static/module/random|/opt/numpy-static|g" /opt/numpy-static/Setup.local && \
    sed -i "s|/build/numpy-static/module/fft|/opt/numpy-static|g" /opt/numpy-static/Setup.local && \
    sed -i "s|/build/numpy-static/module/linalg|/opt/numpy-static|g" /opt/numpy-static/Setup.local && \
    sed -i "s|/build/numpy-static/module/core|/opt/numpy-static|g" /opt/numpy-static/Setup.local && \
    sed -i "s|/opt/numpy/build/temp.linux-x86_64-3.11|/opt/numpy-static|g" /opt/numpy-static/Setup.local
RUN echo "*static*" >> /opt/cpython/wasm/Modules/Setup.local
RUN cat /opt/numpy-static/Setup.local >> /opt/cpython/wasm/Modules/Setup.local
RUN cp -r /opt/numpy-static/module /opt/cpython/wasm/lib/python3.11/site-packages/numpy

# build and install libyaml
RUN git clone https://github.com/yaml/libyaml.git /opt/libyaml && \
    mkdir -p /opt/libyaml/build && \
    cd /opt/libyaml/build && \
    emcmake cmake -DCMAKE_INSTALL_PREFIX=/build ../ && \
    emmake make install

# build and install pyyaml w/ libyaml
RUN /opt/cpython/wasm/bin/python3.11-i386 -m pip install cython
RUN git clone https://github.com/yaml/pyyaml.git /opt/pyyaml && \
    sed -i "s/from yaml\._yaml/from _yaml/g" /opt/pyyaml/lib/yaml/cyaml.py
RUN cd /opt/pyyaml && \
    CFLAGS="-I/build/include -L/build/lib" LDFLAGS="--no-entry" \
    /opt/cpython/wasm/bin/python3.11-i386 setup.py --with-libyaml install

# add pyyaml to the next cpython rebuild
RUN echo "_yaml \
/opt/pyyaml/build/temp.linux-x86_64-3.11/yaml/_yaml.o /build/lib/libyaml.a" >> /opt/cpython/wasm/Modules/Setup.local

# add Qt/Qwt build output
ADD ./qwt /opt/qwt
RUN cp -r /opt/qwt/build/* /build/

# rebuild cpython with the following statically-linked modules:
# - pyqt5
# - numpy
# - pyyaml
RUN cd /opt/cpython/wasm && emmake make LDFLAGS="${LDFLAGS} --bind" -j4 install
RUN cp /opt/cpython/wasm/python* /opt/cpython/wasm/bin/

# install remaining requisite python modules (wasm)
# - six
# - markupsafe
# - mako
# - packaging
RUN for PACKAGE in markupsafe mako six packaging; do \
      CFLAGS="${CFLAGS} -shared" \
      /opt/cpython/wasm/bin/python3.11-i386 \
      -m pip install \
      --no-deps \
      --no-binary $PACKAGE \
      $PACKAGE; \
    done

# grab the GNU Radio source from github
# - branch: feature-qt-gui
RUN git clone --branch=feature-grc-qt https://github.com/gnuradio/gnuradio.git /opt/gnuradio && \
    cd /opt/gnuradio && git checkout 739103692cfdc4dbd74c304a0443a0e896b1112d && \
    cd /opt/gnuradio && git submodule update --init --recursive

# build/install fftw3f
RUN cd /opt && wget http://fftw.org/fftw-3.3.10.tar.gz && tar -xf fftw-3.3.10.tar.gz
RUN cd /opt/fftw-3.3.10 && \
    emconfigure ./configure --prefix=/build --host=wasm32 --with-slow-timer --enable-float && \
    emmake make -j6 install

RUN     cd /opt/gnuradio && git checkout bb2f782e755fd08d03316a4cf43094c10ed7eb23 && \
    cd /opt/gnuradio && git submodule update --init --recursive

# patch GNU Radio
ADD ./gnuradio.patch /opt/gnuradio/gnuradio.patch
RUN cd /opt/gnuradio && git apply ./gnuradio.patch
RUN sed -i "s/\${PYTHON_EXECUTABLE}/\${PYTHON_EXECUTABLE}-i386/g" /opt/gnuradio/cmake/Modules/GrPybind.cmake

# configure GNU Radio
ENV GR_PREFIX=/build
RUN apt-get install -y pkg-config
RUN mkdir -p /opt/gnuradio/build && \
    cd /opt/gnuradio/build && emcmake cmake \
    -DCMAKE_INSTALL_PREFIX=/opt/cpython/wasm/ \
    -DCMAKE_CXX_FLAGS="${CFLAGS} --std=c17 -I/build/include" \
    -DCMAKE_SHARED_LINKER_FLAGS="${LDFLAGS} -s USE_ZLIB -s USE_FREETYPE -s MAX_WEBGL_VERSION=2" \
    -DPYTHON_EXECUTABLE=/opt/cpython/wasm/bin/python3.11 \
    -DPYTHON_LIBRARIES=/opt/cpython/wasm/lib/python3.11 \
    -DPYTHON_INCLUDE_DIR=/opt/cpython/wasm/include/python3.11 \
    -DPYTHON_LIBRARY=/opt/cpython/wasm/lib/libpython3.11.a \
    -DENABLE_DEFAULT=OFF \
    -DMPIRXX_LIBRARY=/build/lib/libmpirxx.a \
    -DMPIR_LIBRARY=/build/lib/libmpir.a \
    -DMPIR_INCLUDE_DIR=/build/include \
    -Dspdlog_DIR=/build/lib/cmake/spdlog \
    -DENABLE_PYTHON=ON \
    -DENABLE_GNURADIO_RUNTIME=ON \
    -DENABLE_GRC=ON \
    -DENABLE_GR_BLOCKS=ON \
    -DENABLE_GR_QTGUI=ON \
    -DENABLE_GR_FFT=ON \
    -DENABLE_GR_FILTER=ON \
    -DENABLE_GR_ANALOG=ON \
    -DENABLE_GR_DIGITAL=ON \
    -DENABLE_GR_CHANNELS=ON \
    -DENABLE_GR_PDU=ON \
    -DENABLE_EXAMPLES=OFF \
    -DTRY_SHM_VMCIRCBUF=OFF \
    -DFFTW3f_LIBRARIES=/build/lib/libfftw3f.a \
    -DQWT_LIBRARIES=/build/lib/libqwt.a \
    -DQt5Widgets_DIR=/build/lib/cmake/Qt5Widgets \
    -DQt5Gui_DIR=/build/lib/cmake/Qt5Gui \
    -DQt5Core_DIR=/build/lib/cmake/Qt5Core \
    -DQt5FontDatabaseSupport_DIR=/build/lib/cmake/Qt5FontDatabaseSupport \
    -DQt5EglSupport_DIR=/build/lib/cmake/Qt5EglSupport \
    -DQt5Zlib_DIR=/build/lib/cmake/Qt5Zlib \
    -DQt5EventDispatcherSupport_DIR=/build/lib/cmake/Qt5EventDispatcherSupport \
    -DQWT_INCLUDE_DIRS=/build/include \
    -DFFTW3f_INCLUDE_DIRS=/build/include \
    -DBoost_NO_SYSTEM_PATHS=ON \
    -DBoost_USE_STATIC_LIBS=ON/ \
    -DBoost_USE_STATIC_RUNTIME=OFF \
    -DBoost_USE_MULTITHREADED=ON \
    -DCMAKE_EXECUTABLE_SUFFIX='' \
    -Dpybind11_DIR=/opt/cpython/wasm/lib/python3.11/site-packages/pybind11/share/cmake/pybind11 \
    -Dfmt_DIR=/build/lib/cmake/fmt \
    -DVolk_DIR=/build/lib/cmake/volk \
    -DBoost_INCLUDE_DIR=/build/include \
    -DBoost_LIBRARY_DIR=/build/lib/ \
    ../

# update GNU Radio python libraries to point to the statically-linked extensions
RUN cd /opt/gnuradio/gnuradio-runtime/python/pmt && \
    find . -name "*.py" | xargs sed -i "s/from \.pmt_python/from pmt_python/g" && \
    find . -name "*.py" | xargs sed -i "s/from \. import pmt_python/import pmt_python/g"
RUN cd  /opt/gnuradio/gnuradio-runtime/python/gnuradio/gr && \
    find . -name "*.py" | xargs sed -i "s/from \.gr_python/from gr_python/g" && \
    find . -name "*.py" | xargs sed -i "s/from \. import gr_python/import gr_python/g"
RUN for m in analog digital channels fft filter pdu qtgui; do \
    cd /opt/gnuradio/gr-$m/python && \
    find . -name "*.py" | xargs sed -i "s/from \.\${m}_python /from \${m}_python /g" && \
    find . -name "*.py" | xargs sed -i "s/from \. import \${m}_python/import \${m}_python/g"; \
    done
RUN sed -i "s/import filter_python as filter, fft/import filter_python as filter/g" /opt/gnuradio/gr-filter/python/filter/pfb.py

# build GNU Radio
RUN cp -r /opt/numpy-static/include /build/include/numpy
RUN cd /opt/gnuradio/build && \
    emmake make \
    CC="ccache /opt/emsdk/upstream/emscripten/emcc" \
    CXX="ccache /opt/emsdk/upstream/emscripten/em++" \
    HOST_CC="ccache /opt/emsdk/upstream/bin/clang" \
    HOST_CXX="ccache /opt/emsdk/upstream/bin/clang++" \
    GR_PREFIX=/build \
    -j6 install

# update cpython config to statically-link the GR native libs
RUN echo "pmt_python \
/opt/gnuradio/build/gnuradio-runtime/python/pmt/bindings/pmt_python.cpython-311.bc \
/opt/cpython/wasm/lib/libgnuradio-pmt.a" >> /opt/cpython/wasm/Modules/Setup.local && \
echo "gr_python \
/opt/gnuradio/build/gnuradio-runtime/python/gnuradio/gr/bindings/gr_python.cpython-311.bc \
/build/lib/libboost_program_options.a \
/build/lib/libspdlog.a \
/build/lib/libboost_thread.a \
/opt/cpython/wasm/lib/libgnuradio-runtime.a \
/build/lib/libmpir.a" >> /opt/cpython/wasm/Modules/Setup.local && \
echo "blocks_python \
/opt/cpython/wasm/lib/python3.11/site-packages/gnuradio/blocks/blocks_python.cpython-311.bc \
/opt/cpython/wasm/lib/libgnuradio-blocks.a \
/build/lib/libvolk.a" >> /opt/cpython/wasm/Modules/Setup.local && \
echo "qtgui_python \
/opt/cpython/wasm/lib/python3.11/site-packages/gnuradio/qtgui/qtgui_python.cpython-311.bc \
/opt/cpython/wasm/lib/libgnuradio-qtgui.a \
/build/lib/libQt5Svg.a \
/build/lib/libqwt.a" >> /opt/cpython/wasm/Modules/Setup.local && \
echo "fft_python \
/opt/cpython/wasm/lib/python3.11/site-packages/gnuradio/fft/fft_python.cpython-311.bc \
/opt/cpython/wasm/lib/libgnuradio-fft.a \
/build/lib/libfftw3f.a" >> /opt/cpython/wasm/Modules/Setup.local && \
echo "filter_python \
/opt/cpython/wasm/lib/python3.11/site-packages/gnuradio/filter/filter_python.cpython-311.bc \
/opt/cpython/wasm/lib/libgnuradio-filter.a" >> /opt/cpython/wasm/Modules/Setup.local && \
echo "analog_python \
/opt/cpython/wasm/lib/python3.11/site-packages/gnuradio/analog/analog_python.cpython-311.bc \
/opt/cpython/wasm/lib/libgnuradio-analog.a" >> /opt/cpython/wasm/Modules/Setup.local && \
echo "digital_python \
/opt/cpython/wasm/lib/python3.11/site-packages/gnuradio/digital/digital_python.cpython-311.bc \
/opt/cpython/wasm/lib/libgnuradio-digital.a" >> /opt/cpython/wasm/Modules/Setup.local && \
echo "channels_python \
/opt/cpython/wasm/lib/python3.11/site-packages/gnuradio/channels/channels_python.cpython-311.bc \
/opt/cpython/wasm/lib/libgnuradio-channels.a" >> /opt/cpython/wasm/Modules/Setup.local && \
echo "pdu_python \
/opt/cpython/wasm/lib/python3.11/site-packages/gnuradio/pdu/pdu_python.cpython-311.bc \
/opt/cpython/wasm/lib/libgnuradio-pdu.a" >> /opt/cpython/wasm/Modules/Setup.local

# rebuild cpython with the following statically-linked modules:
# - pyqt5
# - numpy
# - gnuradio-python
# - gr-qtgui
# - gr-pdu
# - gr-analog
# - gr-digital
# - gr-channels
# - gr-filter
# - gr-fft
# - pyyaml
RUN cd /opt/cpython/wasm && emmake make LDFLAGS="${LDFLAGS} --bind" -j6 install
RUN cp /opt/cpython/wasm/python* /opt/cpython/wasm/bin/

# update the python interpreter build flags for the web build
RUN cd /opt/cpython/wasm && rm -f ./python && emmake make FREEZE_MODULE_BOOTSTRAP=/opt/cpython/wasm/bin/python3.11-i386 PYTHON_FOR_FREEZE=/opt/cpython/wasm/bin/python3.11-i386 FREEZE_MODULE="/opt/cpython/wasm/Programs/_freeze_module" -n python | sed "s/\-lnodefs.js \-s NODERAWFS/--bind -s USE_FREETYPE -s USE_PTHREADS -s EXPORTED_RUNTIME_METHODS=['stringToUTF16'] -s PTHREAD_POOL_SIZE_STRICT=0 --std=c++17 -s EVAL_CTORS/g" | sed "s/\-s INITIAL_MEMORY=1gb//g" > /opt/cpython/wasm/python-build-command.txt

# add cpython's /etc and /share to the final filesystem bundle
RUN cd /opt/cpython/wasm && cp -r share lib/ && cp -r etc lib/

# generate a basic grc config
RUN echo "[grc] \n\
global_blocks_path = /lib/share/gnuradio/grc/blocks \n\
local_blocks_path = \n\
default_flow_graph = \n\
xterm_executable =  \n\
canvas_font_size = 8 \n\
canvas_default_size = 1280, 1024 \n\
enabled_components = python-support;gnuradio-runtime;gnuradio-companion;gr-blocks;gr-digital;gr-analog;gr-channels;gr-filter;gr-fft;gr-pdu;gr-qtgui \n\
" > /opt/cpython/wasm/lib/etc/gnuradio/conf.d/grc.conf

# patch pyyaml to load the statically-linked module
RUN sed -i "s/from yaml\._yaml/from _yaml/g" /opt/cpython/wasm/lib/python3.11/site-packages/PyYAML-6.0-py3.11-linux-x86_64.egg/yaml/cyaml.py

# copy over grc/gui_qt to the build output & remaining patches
RUN cp -r /opt/gnuradio/grc/gui_qt /opt/cpython/wasm/lib/python3.11/site-packages/gnuradio/grc/gui_qt
RUN sed -E -i "s/_\(('.+?')\)/\1/g" /opt/cpython/wasm/lib/python3.11/site-packages/gnuradio/grc/gui_qt/components/window.py
RUN sed -i "s/self.resize(screen.width() \* 0.50, screen.height())/self.resize(int(screen.width() * 0.50), screen.height())/g" /opt/cpython/wasm/lib/python3.11/site-packages/gnuradio/grc/gui_qt/components/window.py

# final cpython rebuild/relink & copy to build output
RUN cd /opt/cpython/wasm && bash /opt/cpython/wasm/python-build-command.txt && \
    cp /opt/cpython/wasm/python* /opt/cpython/wasm/bin/ && \
    mkdir -p /build/base && cp -r /opt/cpython/wasm /build/base/ && \
    cp /build/base/wasm/python /build/base/wasm/python.js
