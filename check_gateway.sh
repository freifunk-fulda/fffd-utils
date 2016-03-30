#!/bin/bash

# check whether the gateway has access to the internet using the VPN-tunnel
# interface. if so, turn on the BATMAN server mode and start the dhcp and
# radvd services.
# if no internet connectivity is available using the vpn uplink, select
# another vpn provider, restart openvpn and test connectivity again until
# no vpn providers are left.

shopt -s nullglob

# vpn interface and advertised bandwidth
#
INTERFACE="fffd.internet"
BANDWIDTH=100MBit/100MBit


# it is possible to manually enable or disable this gateway by using the 
# parameter GATEWAY_ENABLED in /etc/gateway_enabled. if not set to one, 
# the following block will disable the gateway mode and stop services.
#
source /etc/gateway_enabled

if [ ${GATEWAY_ENABLED} -ne 1 ]; then
	for MESH in /sys/class/net/*/mesh; do
		if [ "$(cat $MESH/gw_mode)" != "off" ]; then
			logger "check_gateway: manually disabling gateway mode"

			echo $NEW_STATE > $MESH/gw_mode
			echo $BANDWIDTH > $MESH/gw_bandwidth

			systemctl stop isc-dhcp-server.service
			systemctl stop radvd.service
		fi
	done

	exit 0
fi


# get the currently used vpn provider, which we can detect by looking at
# the symlink /etc/openvpn/openvpn.conf
#
CURRENT_PROVIDER=$(readlink /etc/openvpn/openvpn.conf)


# get all available VPN providers, minus the one we are currently using
#
PROVIDERS=("$(ls -1 /etc/openvpn/pp-* |shuf |xargs -L1 basename |grep -v "^${CURRENT_PROVIDER}$")")


# test internet connectivity via vpn. if we can not ping google dns, select
# another vpn provider and try again.
#
NEW_STATE=off
for p in $PROVIDERS; do
	ping -q -I $INTERFACE 8.8.8.8 -c 2 -i 1 -W 5 &>/dev/null

	if [ $? -eq 0 ]; then
		NEW_STATE=server
		break
	else
		logger "check_gateway: change vpn provider to $p"
		ln -f -s /etc/openvpn/$p /etc/openvpn/openvpn.conf
		systemctl restart openvpn@openvpn
	fi

	sleep 5
done


# iterate through network interfaces in sys file system. if new state is not
# equal old state, change gateway mode accordingly
#
for MESH in /sys/class/net/*/mesh; do
    # Check whether gateway modus needs to be changed
    OLD_STATE="$(cat $MESH/gw_mode)"
    [ "$OLD_STATE" == "$NEW_STATE" ] && continue
    
    logger "check_gateway: changing batman gateway mode to $NEW_STATE"
    echo $NEW_STATE > $MESH/gw_mode
    echo $BANDWIDTH > $MESH/gw_bandwidth

    if [ "$NEW_STATE" == "server" ]; then
        # Restart DHCP server if gateway modus has been activated
	logger "check_gateway: Restarting dhcp and radvd."
        systemctl restart isc-dhcp-server.service
        systemctl restart radvd.service

    else
        # Shutdown DHCP server to prevent renewal of leases
	logger "check_gateway: Stopping dhcp and radvd."
        systemctl stop isc-dhcp-server.service
        systemctl stop radvd.service
    fi
done

