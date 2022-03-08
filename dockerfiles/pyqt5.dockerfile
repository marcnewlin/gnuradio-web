FROM qt5:dev

# grab the cpython build assets
COPY ./cpython /opt/cpython

# install cpython/i386 build-dependencies for PyQt5
RUN CFLAGS="" LDFLAGS="" /opt/cpython/i386/bin/pip3 install PyQt-builder PyQt5-sip

# install cpython/wasm32 build-dependencies for PyQt5
RUN for PACKAGE in pyparsing packaging toml sip PyQt-builder PyQt5-sip; do \
      CFLAGS="${CFLAGS} -shared" \
      /opt/cpython/wasm/bin/python3.11-i386 \
      -m pip install \
      --no-deps \
      --no-binary $PACKAGE \
      $PACKAGE; \
    done

# download and patch PyQt5
RUN mkdir -p /opt/pyqt5 && \
    cd /opt/pyqt5 && \
    wget https://files.pythonhosted.org/packages/3b/27/fd81188a35f37be9b3b4c2db1654d9439d1418823916fe702ac3658c9c41/PyQt5-5.15.6.tar.gz \
    -O /opt/pyqt5/PyQt5-5.15.6.tar.gz && \
    cd /opt/pyqt5 && \
    tar -xf PyQt5-5.15.6.tar.gz && \
    rm PyQt5-5.15.6.tar.gz && \
    cp -r PyQt5-5.15.6/. . && \
    rm -rf PyQt5-5.15.6 && \
    mv /opt/cpython/wasm/lib/python3.11/site-packages/sipbuild/code_generator.abi3.so \
       /opt/cpython/wasm/lib/python3.11/site-packages/sipbuild/code_generator.bc && \
    cp /opt/cpython/i386/lib/python3.11/site-packages/sipbuild/code_generator.abi3.so \
       /opt/cpython/wasm/lib/python3.11/site-packages/sipbuild/ && \
    cp /opt/cpython/i386/lib/python3.11/site-packages/PyQt5/sip.cpython-311-x86_64-linux-gnu.so \
       /opt/cpython/wasm/lib/python3.11/site-packages/PyQt5/ && \
    ln -s /opt/cpython/i386/bin/sip-distinfo /opt/cpython/wasm/lib/python3.11/site-packages/sipbuild/tools/ && \
    sed -i "s|%Include qopengltimerquery.sip|// %Include qopengltimerquery.sip|g" /opt/pyqt5/sip/QtGui/QtGuimod.sip && \
    sed -i 's/SIP_FEATURE_PyQt_Desktop_OpenGL/SIP_FEATURE_PyQt_Desktop_OpenGL__/g' /opt/pyqt5/sip/QtGui/qguiapplication.sip && \
    sed -i "s/    def get_module_extension(self):/    def get_module_extension(self):\n        return '.bc'\n/g" /opt/cpython/wasm/lib/python3.11/site-packages/sipbuild/buildable.py && \
    sed -i '1i #define GL_DOUBLE 0x140A' /opt/pyqt5/qpy/QtGui/qpyopengl_value_array.cpp && \
    rm /opt/pyqt5/sip/QtGui/qopengltimerquery.sip

# build pyqt5
# - QtCore
# - QtGui
# - QtWidgets
# - QtSvg
RUN cd /opt/pyqt5 && \
        /opt/cpython/wasm/bin/python3.11-i386 \
        -m sipbuild.tools.build \
        --qmake /build/bin/qmake \
        --confirm-license \
        --pep484-pyi \
        --verbose \
        --jobs 7 \
        --qt-shared \
        --enable QtCore \
        --enable QtGui \
        --enable QtWidgets \
        --enable QtSvg && \
    cd /opt/pyqt5 && \
       /opt/cpython/wasm/bin/python3.11-i386 \
       -m sipbuild.tools.install \
       --qmake /build/bin/qmake \
       --confirm-license \
       --pep484-pyi \
       --verbose \
       --jobs 7 \
       --qt-shared \
       --enable QtCore \
       --enable QtGui \
       --enable QtWidgets \
       --enable QtSvg

# prepare static libraries for later linking into cpython/wasm32
RUN mkdir -p /build/pyqt5-static
RUN echo "#include <QtPlugin> \n\
Q_IMPORT_PLUGIN (QWasmIntegrationPlugin)" > /opt/wasm-loader.cpp && \
em++ -shared -I/opt/qt5-wasm/qtbase/include/QtCore \
-I/opt/qt5-wasm/qtbase/include \
/opt/wasm-loader.cpp \
/opt/qt5-wasm/qtbase/plugins/platforms/libqwasm.a \
/opt/qt5-wasm/qtbase/lib/libQt5FontDatabaseSupport.a \
/opt/qt5-wasm/qtbase/lib/libQt5EventDispatcherSupport.a \
-o /opt/wasm-loader.bc && \
echo "QtCore \
/opt/cpython/wasm/lib/python3.11/site-packages/PyQt5/QtCore.bc \
/build/lib/libQt5Core.a \
/build/lib/libqtpcre2.a \
/opt/wasm-loader.bc" >> /build/pyqt5-static/Setup.local && \
echo "sip \
/opt/cpython/wasm/lib/python3.11/site-packages/PyQt5/sip.cpython-311.bc" >> /build/pyqt5-static/Setup.local && \
echo "QtGui \
/opt/cpython/wasm/lib/python3.11/site-packages/PyQt5/QtGui.bc \
/build/lib/libQt5Gui.a \
/build/lib/libqtharfbuzz.a \
/build/lib/libqtlibpng.a" >> /build/pyqt5-static/Setup.local && \
echo "QtWidgets \
/opt/cpython/wasm/lib/python3.11/site-packages/PyQt5/QtWidgets.bc \
/build/lib/libQt5Widgets.a" >> /build/pyqt5-static/Setup.local && \
echo "QtSvg \
/opt/cpython/wasm/lib/python3.11/site-packages/PyQt5/QtSvg.bc \
/build/lib/libQt5Svg.a" >> /build/pyqt5-static/Setup.local

# rebuild qt5 to enable exceptions and retain function names
RUN cd /opt/qt5-wasm && emmake make CFLAGS="-fexceptions -g2" LDFLAGS="-fexceptions -g2" -j6 install 2>&1 | tee /opt/qt5.make.log

# prepare build output
RUN cd /build/pyqt5-static && \
    grep -Po " /.+?\.(bc|a)" Setup.local | tr -d ' ' | xargs -I{} cp -vf {} .
RUN cp -r /opt/cpython/wasm/lib/python3.11/site-packages/PyQt5 /build/pyqt5-static/module
