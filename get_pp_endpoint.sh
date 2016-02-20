#!/bin/bash

# a gateway may choose its uplink out of four perfect privacy endpoints.
# this script returns a numeric representation of the active endpoint.

case `/bin/readlink /etc/openvpn/openvpn.conf` in
	*amsterdam*)
		exit 1
		;;
	*erfurt*)
		exit 2
		;;
	*frankfurt*)
		exit 3
		;;
	*nuremberg*)
		exit 4
		;;
esac

exit -1

