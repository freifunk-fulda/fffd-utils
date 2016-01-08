#!/bin/bash

# run ffmap backend to create .json files in a temporary location
# and copy the new files to the actual location afterwards.

# further, create a backup once per day, keep 14 days

date=$(date +%Y%d%m)
time=$(date +%H%M)

dst="/var/www/meshviewer.freifunk-fulda.de/data"

cd /opt/ffmap-backend

./backend.py -a aliases.json --with-hidden-ownership --vpn 26:13:9d:b4:31:a7 26:13:9d:75:c2:51 26:13:9d:ea:e1:1b -d ${dst}/tmp --prune 14 -m fffd.bat &>/dev/null

cp ${dst}/tmp/nodes.json ${dst}
cp ${dst}/tmp/nodelist.json ${dst}
cp ${dst}/tmp/graph.json ${dst}

if [ "${time}" == "0420" ]; then
	find ${dst}/bak/* -mtime +14 -exec rm {} \;

	cp ${dst}/tmp/nodes.json ${dst}/bak/nodes.json-${date}${time}
	cp ${dst}/tmp/nodelist.json ${dst}/bak/nodelist.json-${date}${time}
	cp ${dst}/tmp/graph.json ${dst}/bak/graph.json-${date}${time}
fi

exit 0

