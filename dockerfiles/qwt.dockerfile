FROM qt5:dev

# clone
RUN git clone --depth=1 https://github.com/opencor/qwt.git /opt/qwt

# configure
RUN cd /opt/qwt && /build/bin/qmake qwt.pro
RUN sed -i "s/QWT_CONFIG           += QwtDll/#QWT_CONFIG           += QwtDll/g" /opt/qwt/qwtconfig.pri
RUN sed -i -E 's|QWT_INSTALL_PREFIX +=.+|QWT_INSTALL_PREFIX=/build|g' /opt/qwt/qwtconfig.pri

# build/install
RUN cd /opt/qwt && emmake make -j6 install
