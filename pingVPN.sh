#!/bin/bash

INTERFACE="fffd.internet"

ping -q -I $INTERFACE 8.8.8.8 -c 2 -i 1 -W 5 >/dev/null 2>&1

echo $?

