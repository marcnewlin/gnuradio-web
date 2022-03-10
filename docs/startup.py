import time
start = time.time()

import sys, logging
logging.basicConfig(level=logging.DEBUG)

def init_pyqt5():
  print("Loading PyQt5 modules...")
  for m in ['sip', 'QtCore', 'QtGui', 'QtWidgets', 'QtSvg']:
    start = time.time()
    name = 'PyQt5.%s' % m
    sys.modules[name] = __import__(m)
    elapsed = time.time() - start
    print("%-12s\t\t-> %-24s\t\t%dms" % (m, name, int(elapsed*1000)))

import os
os.makedirs("/home/web_user/.gnuradio/prefs", exist_ok=True)
with open("/home/web_user/.gnuradio/config.conf", "w") as f_out:
  with open("/lib/etc/gnuradio/conf.d/grc.conf", "r") as f_in:
    f_out.write(f_in.read())
with open("/home/web_user/.gnuradio/prefs/vmcircbuf_default_factory", "w") as f_out:
  f_out.write("gr::vmcircbuf_mmap_tmpfile_factory")

os.makedirs("/home/web_user/.cache/grc_gnuradio", exist_ok=True)
with open("/lib/python3.11/site-packages/gnuradio/cache_v2.json", "r") as f:
  with open("/home/web_user/.cache/grc_gnuradio/cache_v2.json", "w") as ff:
    ff.write(f.read())

init_pyqt5()

import QtCore
import QtWidgets
QtCore.Qt.QWidget = QtWidgets.QWidget
QtCore.Qt.QTimer = QtCore.QTimer
sys.modules['PyQt5.Qt'] = QtCore.Qt

elapsed = time.time() - start
print("startup.py completed in %dms" % int(elapsed*1000))

# GRC entrypoint
from gnuradio.grc import main as _main
_main.main()
sys.exit(0)
