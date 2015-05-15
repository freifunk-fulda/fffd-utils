#!/bin/bash

# Copyright (c) 2015, Sven Reissmann <sven@0x80.io>
# 
# Permission to use, copy, modify, and/or distribute this software for
# any purpose with or without fee is hereby granted, provided that the
# above copyright notice and this permission notice appear in all copies.
# 
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

# Automatically pull from a git repository and reload a service or run a
# script if there were changes to the repository pulled from


GIT="/usr/bin/git"


# display usage
#
display_usage () {
	echo "Usage: $0 [-h] -n <name> -d <directory> -c <command>"
	echo
	echo "Options:"
	echo "  -h   Display this help message and exit"
	echo "  -n   The name of the repository or service"
	echo "  -d   The local directory of the repository"
	echo "  -c   The command to execute after a successfull pull"
}


# get arguments
#
n_set=0
d_set=0
c_set=0

while getopts "hn:d:c:" opt; do
	case $opt in
	n)
		NAME=$OPTARG
		n_set=1
		;;
	d)
		DIR=$OPTARG
		d_set=1
		;;
	c)
		CMD=$OPTARG
		c_set=1
		;;
	h)
		display_usage
		exit 0
		;;
	\?)
		echo "Invalid option: -$OPTARG" >&2
		exit 1
		;;
	:)
		echo "Option -$OPTARG requires an argument." >&2
		exit 1
		;;
        esac
done

if [ $n_set -eq 0 -o $d_set -eq 0 -o $c_set -eq 0 ]; then
	echo "Missing required options"
	display_usage
	exit 1
fi



# switch to repository
#
cd ${DIR} &>/dev/null
if [ $? -ne 0 ]; then
	logger -p local7.err "${NAME}: Repository not found"
	exit 1
fi

# cet HEADs and mergebase
#
${GIT} fetch &>/dev/null
status=$?
LOCAL=$(git rev-parse @)
status=$(($status + $?))
REMOTE=$(git rev-parse @{u})
status=$(($status + $?))
BASE=$(git merge-base @ @{u})
status=$(($status + $?))


# catch stupidity errors
#
if [ $status -ne 0 ]; then
	logger -p local7.err "${NAME}: Unable to get commit objects"
	exit 1
fi

# compare commit objects and update if neccessary

if [ ${LOCAL} == ${REMOTE} ]; then
	logger -p local7.notice "${NAME}: Already up-to-date"
	exit 0

elif [ ${LOCAL} == ${BASE} ]; then
	${GIT} pull &>/dev/null
	gitstatus=$?
	${CMD} &>/dev/null
	reloadstatus=$?

	if [ $gitstatus -eq 0 -a $reloadstatus -eq 0 ]; then
		logger -p local7.notice "${NAME}: Updated successfully"
		exit 0
	else
		logger -p local7.err "${NAME}: Error updating from remote repository"
		exit 1
	fi

else
	logger -p local7.err "${NAME}: Push or manual merge needed"
	exit 1
fi

