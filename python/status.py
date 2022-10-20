# Python code to update the LCD with SPU info
# Edu Meneses, 2021, IDMIL, CIRMMT, McGill University

# Import needed modules from osc4py3
from osc4py3.as_eventloop import *
from osc4py3 import oscbuildparse
import subprocess
import threading
import sys

# Start the system.
osc_startup()

# Make client channels to send packets.
osc_udp_client("0.0.0.0", 20000, "lcd")

def updateStatus():
    ipAdress = subprocess.getoutput("ip -4 addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}'")
    msgIP = oscbuildparse.OSCMessage("/lcd", ",sii", [ipAdress, 4, 20-len(ipAdress)])
    currentHostname = subprocess.getoutput("hostname").upper()
    if len(ipAdress) >= 15:
        currentHostname = currentHostname[3:]
    msgHostname = oscbuildparse.OSCMessage("/lcd", ",sii", [currentHostname, 4, 1])
    
    bun = oscbuildparse.OSCBundle(oscbuildparse.OSC_IMMEDIATELY,[msgIP,msgHostname])
    osc_send(bun, "lcd")
    osc_process()
    threading.Timer(5, updateStatus).start() # scheduling event every 5 seconds

updateStatus()

def main():
    while True:
        forever = threading.Event(); forever.wait()


if __name__ == '__main__':

    try:
        main()
    except KeyboardInterrupt:
        pass
    finally:
        osc_terminate()
        sys.exit(0)
