FROM build-base:dev

# clone
ARG BOOST_VER=1.71.0
RUN git clone --branch=boost-${BOOST_VER} --depth=1 https://github.com/boostorg/boost /opt/boost
RUN cd /opt/boost && git submodule update --init --recursive --depth=1

# patch
RUN cd /opt/boost && \
    sed -i "s/emcc/em++/g" tools/build/src/tools/emscripten.jam && \
    sed -i "s/\$(AROPTIONS) -o /\$(AROPTIONS) -r -o /g" tools/build/src/tools/emscripten.jam && \
    sed -i "s/\-L\"\$(LINKPATH)\" -o /-L\"\$(LINKPATH)\" -c -o /g" tools/build/src/tools/emscripten.jam && \
    sed -i "s/generators.register/#generators.register/g" tools/build/src/tools/generators/searched-lib-generator.jam

# configure
RUN cd /opt/boost && \
    ./bootstrap.sh \
    --with-libraries="chrono,date_time,filesystem,log,headers,math,program_options,random,regex,system,serialization,thread" \
    --prefix="/build/boost"

# build
RUN	cd /opt/boost && ./b2 toolset=emscripten \
                     threading=multi \
                     link=static \
                     runtime-link=shared \
                     cflags="-pthread -O3" \
                     cxxflags="-pthread -O3 --std=c++17" \
                     linkflags="-s WASM_BIGINT" \
                     define=BOOST_BIND_GLOBAL_PLACEHOLDERS \
                     install

# package objects into static libraries
RUN for f in $(ls /build/boost/lib/libboost*.bc); do emar rcs $(echo $f | sed s/\.bc\$/.a/) $f; rm $f; done
