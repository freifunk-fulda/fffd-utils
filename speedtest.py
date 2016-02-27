#!/usr/bin/env python

# perform a speedtest using the speedtest-cli of speedtest.net
# and send the results to carbon

from contextlib import contextmanager
import time
import socket
import logging
import subprocess
import sys
import getopt

logger = logging.getLogger(__name__)

@contextmanager
def get_socket(host, port):
    sock = socket.socket()
    sock.settimeout(1)
    sock.connect((host, port))
    yield sock
    sock.close()


def write_to_graphite(data, carbon, prefix='speedtest'):
    now = time.time()
    with get_socket(carbon, 2003) as s:
        for key, value in data.items():
            line = "%s.%s %s %s\n" % (prefix, key, float(value), now)
            s.sendall(line.encode('latin-1'))

def parseargs(argv):
    self_ipv4 = ''
    carbon_ipv4 = '10.185.0.12'

    try:
        opts, args = getopt.getopt(argv, "hi:c:", ["ip=", "carbon="])
    except getopt.GetoptError:
        print 'speedtest.py -i <source IPv4 address> -c <carbon IPv4 address>'
        sys.exit(2)

    for opt, arg in opts:
        if opt == '-h':
            print 'speedtest.py -i <source IPv4 address> -c <carbon IPv4 address>'
            sys.exit()
        elif opt in ("-i", "--ip"):
            self_ipv4 = arg
        elif opt in ("-c", "--carbon"):
            carbon_ipv4 = arg

    if self_ipv4 == '':
        print 'speedtest.py -i <source IPv4 address> -c <carbon IPv4 address>'
        sys.exit()

    return [self_ipv4, carbon_ipv4]


def main(argv):
    logging.basicConfig(level=logging.WARN)

    hostname = socket.gethostname()
    update = {}

    params = parseargs(argv)

    result = subprocess.check_output(["speedtest-cli", "--source", params[0], "--simple", "--secure"])

    lines = result.splitlines()

    update['%s.ping' % hostname] = lines[0].split()[1]
    update['%s.down' % hostname] = lines[1].split()[1]
    update['%s.up' % hostname] = lines[2].split()[1]

    try:
        write_to_graphite(update, params[1])
    except Exception:
        raise


if __name__ == "__main__":
    main(sys.argv[1:])

