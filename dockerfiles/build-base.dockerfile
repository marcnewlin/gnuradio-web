FROM ubuntu:20.04

RUN apt-get update && apt-get upgrade -y

# set the locale to en_US / UTF-8
RUN DEBIAN_FRONTEND="noninteractive" apt-get -y install tzdata locales
RUN locale-gen en_US.UTF-8
ENV LANG='en_US.UTF-8' LANGUAGE='en_US:en' LC_ALL='en_US.UTF-8'

# install build dependencies
RUN dpkg --add-architecture i386 && apt-get update
RUN apt-get install -y git build-essential make cmake gcc-multilib g++-multilib \
                       uuid-runtime yasm file texinfo autoconf m4 libtool wget vim \
                       python3 ccache
RUN apt-get install -y libbz2-dev:i386 libexpat-dev:i386 libffi-dev:i386 libgpm-dev:i386 \
                       liblzma-dev:i386 libmpdec-dev:i386 libreadline-dev:i386 \
                       libssl-dev:i386 zlib1g-dev:i386

# install emsdk
ARG EMSDK_VER=3.1.1
RUN git clone --branch=${EMSDK_VER} --depth=1 https://github.com/emscripten-core/emsdk.git /opt/emsdk
RUN cd /opt/emsdk && git submodule update --init --recursive
RUN cd /opt/emsdk && ./emsdk install ${EMSDK_VER} && ./emsdk activate ${EMSDK_VER}

# set environment variables normally set by emsdk_env.sh
ENV PATH=/opt/emsdk:/opt/emsdk/upstream/emscripten:${PATH}
ENV EMSDK=/opt/emsdk
ENV EM_CONFIG=/opt/emsdk/.emscripten
RUN emcc --clear-cache

# install node
ARG NODE_VER=17.6.0
RUN mkdir -p /opt/node
RUN wget https://nodejs.org/dist/v${NODE_VER}/node-v${NODE_VER}-linux-x64.tar.xz -O /opt/node/node.tar.xz
RUN cd /opt/node && tar -xf node.tar.xz
RUN cp -r /opt/node/node*/. /usr/local/

# install recent cmake from the kitware ppa
RUN wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc 2>/dev/null | gpg --dearmor - | tee /usr/share/keyrings/kitware-archive-keyring.gpg >/dev/null
RUN echo 'deb [signed-by=/usr/share/keyrings/kitware-archive-keyring.gpg] https://apt.kitware.com/ubuntu/ focal main' | tee /etc/apt/sources.list.d/kitware.list >/dev/null
RUN apt-get update && apt-get install -y cmake
