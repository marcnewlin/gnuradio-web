# WebAssembly build of GNU Radio

### what

Experimental WebAssembly build of GNU Radio that runs in a browser tab

### why

For some reason I thought it would be easy

`narrator: it was not, in fact, easy`

but I eventually got a proof-of-concept ~working, so I thought I'd share :)

### status: experimental proof-of-concept

This is a proof-of-concept WebAssembly build of GNU Radio Companion which can generate and run basic flowgraphs. It includes `gr-qtgui` and supports visualization using the QT GUI sink-blocks.

The GNU Radio Companion UI is running the `feature-grc-qt` branch of GNU Radio, which itself is a work-in-progress, so some basic capabilities (like the ability to edit block properties) are missing.

Support for USB software-defined radios is not yet implemented, but will be possible. (Earlier in the pandemic I published standalone WebUSB proof-of-concepts for USRP B210, HackRF, and PlutoSDR.)

### how to run a simple flowgraph with QT GUI visualization

1. run ```cd webapp && ./server.py```
2. open your web browser (and the F12 developer-tools)
3. navigate to http://localhost:8000

   It will block on the browser UI thread while loading, which takes on the order of 15-30 seconds. If you have the developer console open, you can watch stdout/stderr while it loads.
4. add/connect some blocks (eg. `Signal Source` -> `Throttle` -> `QT GUI Sink`)
5. click `Generate`
6. click `Execute`

### how make gnuradio-web

The repo includes prebuilt binaries, but if you like watching cross-compilation marathons, you can build it from source:

1. install `docker`, `docker-compose`, and `emsdk`

2. run `make base && make webapp` in the repository root

   (I've only tested this on an Ubuntu 20.04 x86_64 host. It probably works in other environments but YMMV.)

### simple flowgraph demo

https://user-images.githubusercontent.com/1245470/157148629-7316bd5b-9deb-4479-946b-1595ab1328af.mp4
