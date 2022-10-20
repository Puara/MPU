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
    currentHostname = subprocess.getoutput("hostname").upper()
    message = currentHostname+" "+ipAdress
    if len(message) > 20:
        message = message[3:]
    messageOSC = oscbuildparse.OSCMessage("/lcd", ",sii", [message, 4, 21-len(ipAdress)])
    osc_send(messageOSC, "lcd")
    osc_process()
    threading.Timer(30, updateStatus).start() # scheduling event every 30 seconds

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
