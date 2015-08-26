#!/bin/bash

# check whether the gateway has access to the internet using the VPN-tunnel
# interface. if so, turn on the BATMAN server mode and start the dhcp server.
# otherwise, disable server mode and stop the dhcp server.

INTERFACE="fffd.internet"
BANDWIDTH=54MBit/54MBit

shopt -s nullglob

# Test whether gateway is connected to the outer world via VPN
ping -q -I $INTERFACE 8.8.8.8 -c 2 -i 1 -W 5 >/dev/null 2>&1

if test $? -eq 0; then
    NEW_STATE=server
else
    NEW_STATE=off
fi

# Iterate through network interfaces in sys file system
for MESH in /sys/class/net/*/mesh; do
    # Check whether gateway modus needs to be changed
    OLD_STATE="$(cat $MESH/gw_mode)"
    [ "$OLD_STATE" == "$NEW_STATE" ] && continue
    
    echo $NEW_STATE > $MESH/gw_mode
    echo $BANDWIDTH > $MESH/gw_bandwidth
    logger "batman gateway mode changed to $NEW_STATE"

    if [ "$NEW_STATE" == "server" ]; then
        # Restart DHCP server if gateway modus has been activated
        /usr/sbin/service isc-dhcp-server restart
    else
        # Shutdown DHCP server to prevent renewal of leases
        /usr/sbin/service isc-dhcp-server stop
    fi
done
