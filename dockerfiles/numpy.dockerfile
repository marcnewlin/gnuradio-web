FROM cpython:dev

# install cython for the i386 interpreter
RUN /opt/cpython/i386/bin/python3.11 -m pip install Cython
RUN cp /opt/cpython/i386/lib/python3.11/site-packages/cython.py /opt/cpython/wasm/lib/python3.11/site-packages/
RUN cp -r /opt/cpython/i386/lib/python3.11/site-packages/Cython /opt/cpython/wasm/lib/python3.11/site-packages/

# clone and patch numpy
ARG NUMPY_TAG="v1.22.0"
RUN git clone --branch=main https://github.com/numpy/numpy.git /opt/numpy
COPY ./numpy.patch /opt/numpy/numpy.patch
RUN cd /opt/numpy && \
    git checkout tags/${NUMPY_TAG} && \
    git submodule update --init --recursive && \
    git apply /opt/numpy/numpy.patch
RUN sed -i '1i import platform; platform.machine = lambda: "wasm32"; platform.architecture = lambda: ("32bit","");' /opt/numpy/setup.py
RUN mkdir -p /build/numpy-static

# build numpy
RUN cd /opt/cpython/wasm/ && \
    LDFLAGS="${LDFLAGS} --no-entry -shared" \
    CFLAGS="${CFLAGS}" /opt/cpython/wasm/bin/python3.11-i386 /opt/numpy/setup.py build --disable-optimization

# install numpy
RUN cp -r /opt/numpy/numpy/core/include/* /build/numpy-static/include/
RUN cp -r /opt/numpy/build/src.*-3.11/numpy/core/include/numpy/* /build/numpy-static/include/
RUN cp -r /opt/numpy/build/lib.*-3.11/numpy /build/numpy-static/module

# prepare static modules which later get linked into cpython/wasm32
COPY ./generate-numpy-setup-local.py /opt/numpy/generate-numpy-setup-local.py
RUN chmod +x /opt/numpy/generate-numpy-setup-local.py && \
    /opt/numpy/generate-numpy-setup-local.py
RUN cd /build/numpy-static && \
    grep -Po " /.+?\.(bc|a)" Setup.local | tr -d ' ' | xargs -I{} cp {} .
