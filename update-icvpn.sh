#!/bin/bash
#
# Depending on cli parameter $1, this script will
#  1) update tinc and bird configuration for ICVPN peerings
#  2) updates DNS delegations to other freifunk communities
#     and generate a ROA table
#
# It needs to run by cron.
# Parameter $1 may be "icvpn" or "ice"
#

[ "$(whoami)" != 'root' ] && (
	logger "update-icvpn: error: please execute as user root"
	exit 1
)

# Get mode (see decription at top; ice == 2, icvpn == 1 & 2)
MODE=ice
[ $# -eq 1 ] && MODE=$1


TINC_NETWORK=icvpn

ICVPN_META=/opt/icvpn-meta
ICVPN_SCRIPTS=/opt/icvpn-scripts

BIRD_ROOT=/etc/bird
BIRD4_ROA=$BIRD_ROOT/icvpn/bird4-roa-icvpn.conf
BIRD4_PEERS=$BIRD_ROOT/icvpn/bird4-peers-icvpn.conf
BIRD6_ROA=$BIRD_ROOT/icvpn/bird6-roa-icvpn.conf
BIRD6_PEERS=$BIRD_ROOT/icvpn/bird6-peers-icvpn.conf

BIND_ROOT=/etc/bind
BIND_CONFIG=$BIND_ROOT/named.conf.icvpn


update_roa() (
	$ICVPN_SCRIPTS/mkroa -4 -m 24 -f bird -x fulda -s $ICVPN_META > $BIRD4_ROA
	$ICVPN_SCRIPTS/mkroa -6 -m 64 -f bird -x fulda -s $ICVPN_META > $BIRD6_ROA
)

update_bgp_peers() (
	$ICVPN_SCRIPTS/mkbgp -4 -f bird -p icvpn_ -s $ICVPN_META -x fulda -d bgp_icvpn > $BIRD4_PEERS
	birdc configure check
	birdc configure
)

update_bgp6_peers() (
	$ICVPN_SCRIPTS/mkbgp -6 -f bird -p icvpn_ -s $ICVPN_META -x fulda -d bgp_icvpn > $BIRD6_PEERS
	birdc6 configure check
	birdc6 configure
)

update_bind() (
	$ICVPN_SCRIPTS/mkdns -f bind -s $ICVPN_META -x fulda > $BIND_CONFIG
	named-checkconf $BIND_CONFIG
	rndc reload
)


PATH=/usr/sbin:$PATH

# depending on $MODE, update tinc peers
#
if [ "$MODE" == "icvpn" ]; then
	cd /etc/tinc/$TINC_NETWORK/
	git remote update >/dev/null
	
	if [ $FORCE_VPN ] || [ $(git rev-parse HEAD) != $(git rev-parse @{u}) ]; then
		logger "update-icvpn: repo icvpn: update available"
		git pull origin master
		# post-merge hook handles configuration update
	fi
fi

# depending on $MODE, update bird peers, ROA and DNS delegations
#
cd $ICVPN_META
git remote update >/dev/null

if [ $FORCE_META ] || [ $(git rev-parse HEAD) != $(git rev-parse @{u}) ]; then
	logger "update-icvpn: repo icvpn-meta: update available"
	git pull origin master

	# update bird peers
	if [ "$MODE" == "icvpn" ]; then
		update_bgp_peers
		update_bgp6_peers
	fi

	# update ROA and DNS delegations
	update_roa
	update_bind
fi

