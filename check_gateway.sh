#!/bin/bash

# check whether the gateway has access to the internet using the VPN-tunnel
# interface. if so, turn on the BATMAN server mode and start services like
# dhcp server, router advertisement daemon, and so on. otherwise, disable 
# server mode and stop the services.

source /etc/gateway_enabled

INTERFACE="fffd.internet"
BANDWIDTH=54MBit/54MBit

shopt -s nullglob

# Test whether gateway is connected to the outer world via VPN
ping -q -I $INTERFACE 8.8.8.8 -c 2 -i 1 -W 5 >/dev/null 2>&1

if [ ${GATEWAY_ENABLED} -eq 1 -a $? -eq 0 ]; then
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
    logger "check_gateway: batman gateway mode changed to $NEW_STATE"

    if [ "$NEW_STATE" == "server" ]; then
        # Restart DHCP server if gateway modus has been activated
        systemctl restart isc-dhcp-server.service
        systemctl restart radvd.service

    else
        # Shutdown DHCP server to prevent renewal of leases
        systemctl stop isc-dhcp-server.service
        systemctl stop radvd.service
    fi
done
