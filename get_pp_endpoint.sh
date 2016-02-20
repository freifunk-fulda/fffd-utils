#!/bin/bash

# a gateway may choose its uplink out of four perfect privacy endpoints.
# this script returns a numeric representation of the active endpoint.

case `/bin/readlink /etc/openvpn/openvpn.conf` in
	*amsterdam*)
		return 1
		;;
	*erfurt*)
		return 2
		;;
	*frankfurt*)
		return 3
		;;
	*nuremberg*)
		return 4
		;;
esac

return -1

