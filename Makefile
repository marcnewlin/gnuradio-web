UID=$(shell id -u)
ROOT=$(shell pwd)

.PHONY: webapp

clean:
	rm -rf build/*
	rm -rf build-output/*

build-output:
	mkdir -p build-output

build-output/boost: build-output ./dockerfiles/boost.dockerfile
	$(MAKE) boost
	docker-compose run -u ${UID}:${UID} boost cp -r /build/boost /build-output/

build-output/cpython: build-output ./dockerfiles/cpython.dockerfile ./patches/cpython.wasm.patch ./patches/cpython.i386.patch
	$(MAKE) cpython
	docker-compose run -u ${UID}:${UID} cpython cp -r /build/cpython /build-output/

build-output/pyqt5: build-output ./dockerfiles/pyqt5.dockerfile
	$(MAKE) pyqt5
	mkdir -p build-output/pyqt5
	docker-compose run -u ${UID}:${UID} pyqt5 cp -r /build/pyqt5-static /build-output/pyqt5/

build-output/numpy: build-output ./dockerfiles/numpy.dockerfile
	$(MAKE) numpy
	mkdir -p build-output/numpy
	docker-compose run -u ${UID}:${UID} numpy cp -r /build/numpy-static /build-output/numpy/

build-output/volk: build-output ./dockerfiles/volk.dockerfile
		$(MAKE) volk
		mkdir -p build-output/volk
		docker-compose run -u ${UID}:${UID} volk cp -r /build/volk/. /build-output/volk/

build-output/qwt: build-output ./dockerfiles/qwt.dockerfile
	$(MAKE) qwt
	mkdir -p build-output/qwt
	docker-compose run -u ${UID}:${UID} qwt cp -r /build /build-output/qwt

boost: build-output/cpython
	mkdir -p ./.context/boost
	cp ./dockerfiles/boost.dockerfile ./.context/boost/dockerfile
	docker-compose build boost

cpython:
	mkdir -p ./.context/cpython/patches
	cp ./patches/cpython.wasm.patch ./.context/cpython/patches/cpython.wasm.patch
	cp ./patches/cpython.i386.patch ./.context/cpython/patches/cpython.i386.patch
	cp ./dockerfiles/cpython.dockerfile ./.context/cpython/dockerfile
	docker-compose build cpython

qt5:
	mkdir -p ./.context/qt5
	cp ./dockerfiles/qt5.dockerfile ./.context/qt5/dockerfile
	cp ./patches/qt5.qtbase.patch ./.context/qt5/qt5.qtbase.patch
	docker-compose build qt5

pyqt5: qt5 build-output/cpython
	rm -rf ./.context/pyqt5
	mkdir -p ./.context/pyqt5
	cp -r build-output/cpython ./.context/pyqt5/
	cp ./dockerfiles/pyqt5.dockerfile ./.context/pyqt5/dockerfile
	docker-compose build pyqt5

numpy: build-output/cpython
	rm -rf ./.context/numpy
	mkdir -p ./.context/numpy
	cp ./patches/numpy.patch ./.context/numpy/numpy.patch
	cp ./dockerfiles/numpy.dockerfile ./.context/numpy/dockerfile
	cp ./generate-numpy-setup-local.py ./.context/numpy/generate-numpy-setup-local.py
	docker-compose build numpy

volk:
	rm -rf ./.context/volk
	mkdir -p ./.context/volk
	cp ./patches/volk.patch ./.context/volk/volk.patch
	cp ./dockerfiles/volk.dockerfile ./.context/volk/dockerfile
	docker-compose build volk

qwt: qt5
	rm -rf ./.context/qwt
	mkdir -p ./.context/qwt
	cp ./dockerfiles/qwt.dockerfile ./.context/qwt/dockerfile
	docker-compose build qwt

gnuradio: build-output/volk build-output/boost build-output/pyqt5 build-output/numpy build-output/qwt
	rm -rf ./.context/gnuradio
	mkdir -p ./.context/gnuradio
	cp ./patches/gnuradio.patch ./.context/gnuradio/
	cp ./dockerfiles/gnuradio.dockerfile ./.context/gnuradio/dockerfile
	cp -r ./build-output/volk ./.context/gnuradio/
	cp -r ./build-output/boost ./.context/gnuradio/
	cp -r ./build-output/pyqt5/pyqt5-static ./.context/gnuradio/
	cp -r ./build-output/numpy/numpy-static ./.context/gnuradio/
	cp -r ./build-output/qwt ./.context/gnuradio/
	docker-compose build gnuradio
	rm -rf ./build-output/gnuradio
	docker-compose run -u 1000:1000 gnuradio cp -r /build/base/wasm /build-output/gnuradio
	mv build-output/gnuradio/lib build-output/gnuradio/_lib

gnuradio-rebuild: gnuradio
	cp -r ./scratch ./.context/gnuradio-rebuild/
	cp ./dockerfiles/gnuradio-rebuild.dockerfile ./.context/gnuradio-rebuild/dockerfile
	cp -r ./build-output/pyqt5/pyqt5-static ./.context/gnuradio-rebuild/
	docker-compose build gnuradio-rebuild
	rm -rf ./build-output/gnuradio
	docker-compose run -u 1000:1000 gnuradio-rebuild cp -r /build/base/wasm /build-output/gnuradio
	mv build-output/gnuradio/lib build-output/gnuradio/_lib

./build/wasm:
	docker-compose run -u ${UID}:${UID} pyqt5 cp -r /opt/cpython/wasm /build/

./build/qt5:
	docker-compose run -u ${UID}:${UID} qt5 cp -r /opt/qt5 /build/

./build/qt5-wasm:
	docker-compose run -u ${UID}:${UID} qt5 cp -r /opt/qt5-wasm /build/

webapp: gnuradio-rebuild

	mkdir -p ./webapp

	cd ~/git/gnuradio-web/grc-dev && find . -name "*.py" | xargs ../build-output/cpython/wasm/bin/python3.11-i386 -m compileall

	cp ./cache_v2.json grc-dev/gnuradio/

	if [ ! -d "./build-output/gnuradio/_lib" ]; then \
		mv ./build-output/gnuradio/lib ./build-output/gnuradio/_lib; \
	fi

	rsync -zar \
	--exclude="*.a" \
	--exclude="*.bc" \
	--exclude="*.so" \
	--exclude="*.dll" \
	--exclude="*.exe" \
	--exclude="*.pyo" \
	./build-output/gnuradio/_lib/* \
	./build-output/gnuradio/lib

	rm -rf ./build-output/gnuradio/lib/python3.11/test
	rm -rf ./build-output/gnuradio/lib/python3.11/ensurepip
	rm -rf ./build-output/gnuradio/lib/python3.11/site-packages/pip

	cp -r ./grc-dev/gnuradio ./build-output/gnuradio/lib/python3.11/site-packages/

	cd build-output/gnuradio && \
	$$EMSDK/upstream/emscripten/tools/file_packager.py \
	python.data --preload lib --no-node --js-output=python.data.js --lz4

	cp ./build-output/gnuradio/python* ./webapp/



base:
	mkdir -p .context
	mkdir -p .context/qt5
	mkdir -p .context/qwt
	mkdir -p .context/pyqt5
	mkdir -p .context/boost
	mkdir -p .context/numpy
	mkdir -p .context/volk
	mkdir -p .context/cpython
	mkdir -p .context/gnuradio
	mkdir -p .context/gnuradio-rebuild
	docker-compose build build-base
