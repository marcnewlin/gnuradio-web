#!/opt/cpython/wasm/bin/python3.11-i386

import os
import glob

template = ""

def rename_module(file, name=None, extra=""):

  file_root = file.split("/")[-1].split(".")[0]
  package = file.split("/")[4]
  if name is None:
    name = file_root
  mod_name = name

  os.system("sed -ri 's/Py_InitModule4\(\"(.+?)\",/Py_InitModule4(\"%s\",/' %s" % (mod_name, file))
  os.system('sed -ri "s/PyInit_(.+?)\(/PyInit_%s\(/" %s'%(mod_name, file))
  os.system("echo \"%s /build/numpy-static/module/%s/%s.cpython-311.bc %s\" >> /build/numpy-static/Setup.local" % (mod_name, package, name, extra))

os.system("mkdir -p /build/numpy-static")
os.system("echo \"*static*\" >> /build/numpy-static/Setup.local")

first_random = True
for file in glob.glob("/opt/numpy/numpy/random/*.c"):
  if first_random:
    extra = "/opt/numpy/build/temp.linux-x86_64-3.11/libnpyrandom.a"
    first_random = False
    extra=""
  else:
    extra = ""
  rename_module(file, extra=extra)

rename_module("/opt/numpy/numpy/core/src/multiarray/multiarraymodule.c", "_multiarray_umath", extra="/opt/numpy/build/temp.linux-x86_64-3.11/libnpymath.a")
rename_module("/opt/numpy/numpy/fft/_pocketfft.c", "_pocketfft_internal")
rename_module("/opt/numpy/numpy/linalg/umath_linalg.c.src", "_umath_linalg")
