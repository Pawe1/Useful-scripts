#! /usr/bin/python

# Wake on LAN
#
# Use:
# wol computer1
# wol computer1 computer2
# wol 00:11:22:33:44:55
#
# Based on scripy written by San Bergmans (www.sbprojects.net)

import sys
import struct
import socket

# Configuration variables
broadcast = ['192.168.0.255', '192.168.1.255']
wol_port = 9

known_computers = {
    'mercury' : '00:1C:55:35:12:BF',
    'venus' : '00:1d:39:55:5c:df',
    'earth' : '00:10:60:15:97:fb',
    'mars' : '00:10:DC:34:B2:87',
}

def WakeOnLan(ethernet_address):

    # Construct 6 byte hardware address
    add_oct = ethernet_address.split(':')
    if len(add_oct) != 6:
        print("*** \"" + ethernet_address + "\" is not a valid MAC address\n", end='', flush=True)
        print("MAC should be written as 00:11:22:33:44:55\n", end='', flush=True)
        return
    hwa = struct.pack('BBBBBB', int(add_oct[0], 16),
        int(add_oct[1], 16),
        int(add_oct[2], 16),
        int(add_oct[3], 16),
        int(add_oct[4], 16),
        int(add_oct[5], 16))

    magic_packet = b'\xff' * 6 + hwa * 16

    # Send packet to broadcast address using UDP port 9
    soc = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    soc.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST,1)
    for i in broadcast:
        soc.sendto(magic_packet, (i, wol_port))
    soc.close()

if len(sys.argv) == 1:
    print("*** No computer given to power up\n", end='', flush=True)
    print("Use: 'wol computername' or 'wol 00:11:22:33:44:55'")
else:
    for i in sys.argv[1:]:
        if i[0] != '/':
            if ":" in i:
                # Wake up using MAC address
                WakeOnLan(i)
            else:
                # Wake up known computers
                if i in known_computers:
                    WakeOnLan(known_computers[i])
                else:
                    print("*** Unknown computer \"" + i + "\"\n", end='', flush=True)

    if len(sys.argv) == 2:
        print("\nDone! The computer should be up and running in a short while.")
    else:
        print("\nDone! The computers should be up and running in a short while.")
        print