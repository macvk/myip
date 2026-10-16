#!/usr/bin/env python3

# Public IP address client for bash.ws.
# Project: https://github.com/macvk/myip
# SPDX-License-Identifier: MIT

import http.client
import ipaddress
import platform
import shutil
import socket
import subprocess
import sys
from urllib.parse import quote


VERSION = '1.0.0'
API_DOMAIN = 'bash.ws'
REQUEST_TIMEOUT = 10


class RequestError(Exception):
    pass


def request(host, path='/', source_address=None):
    source = (source_address, 0) if source_address else None
    connection = http.client.HTTPSConnection(host, timeout=REQUEST_TIMEOUT, source_address=source)

    try:
        connection.request('GET', path, headers={'User-Agent': 'bash.ws myip-python/' + VERSION})
        response = connection.getresponse()
        data = response.read().decode('utf-8').strip()

        if response.status < 200 or response.status >= 300:
            raise RequestError('{} returned HTTP {}'.format(host, response.status))

        return data
    except (OSError, UnicodeError, http.client.HTTPException) as error:
        raise RequestError(str(error)) from error
    finally:
        connection.close()


def valid_address(value, family):
    try:
        address = ipaddress.ip_address(value)
    except ValueError:
        return False

    return address.version == family


def usable_address(value, family):
    value = value.split('/', 1)[0].split('%', 1)[0]

    try:
        address = ipaddress.ip_address(value)
    except ValueError:
        return ''

    if address.version != family:
        return ''

    if address.is_loopback or address.is_link_local or address.is_unspecified or address.is_multicast:
        return ''

    return value


def system_address_command(family):
    current_system = platform.system().lower()

    if current_system == 'windows' and shutil.which('powershell'):
        address_family = 'IPv4' if family == 4 else 'IPv6'
        script = "Get-NetIPAddress -AddressFamily {} | Where-Object {{ $_.AddressState -eq 'Preferred' }} | Select-Object -ExpandProperty IPAddress".format(address_family)
        return ['powershell', '-NoProfile', '-Command', script]

    if shutil.which('ip'):
        return ['ip', '-o', '-{}'.format(family), 'address', 'show', 'up']

    if shutil.which('ifconfig'):
        return ['ifconfig']

    return []


def system_addresses(family):
    command = system_address_command(family)

    if not command:
        return []

    try:
        process = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, universal_newlines=True, check=False)
    except OSError:
        return []

    addresses = []

    for line in process.stdout.splitlines():
        tokens = line.split()
        candidates = tokens if len(tokens) == 1 else []

        for index, token in enumerate(tokens[:-1]):
            if token == ('inet' if family == 4 else 'inet6'):
                candidates.append(tokens[index + 1].replace('addr:', '', 1))

        for candidate in candidates:
            value = usable_address(candidate, family)

            if value and value not in addresses:
                addresses.append(value)

    return addresses


def hostname_addresses(family):
    socket_family = socket.AF_INET if family == 4 else socket.AF_INET6
    addresses = []

    try:
        records = socket.getaddrinfo(socket.gethostname(), 0, socket_family, socket.SOCK_STREAM)
    except OSError:
        return addresses

    for record in records:
        value = usable_address(record[4][0], family)

        if value and value not in addresses:
            addresses.append(value)

    return addresses


def local_addresses(family):
    addresses = system_addresses(family)

    for value in hostname_addresses(family):
        if value not in addresses:
            addresses.append(value)

    return addresses


def detect_addresses(family):
    host = 'ipv{}.{}'.format(family, API_DOMAIN)
    addresses = []

    for source in [None] + local_addresses(family):
        try:
            value = request(host, source_address=source)
        except RequestError:
            continue

        if valid_address(value, family) and value not in addresses:
            addresses.append(value)

    return addresses


def address_details(address):
    try:
        response = request(API_DOMAIN, '/geoiplookup/{}?embed=txt'.format(quote(address, safe='')))
    except RequestError:
        return address

    fields = response.split('|')
    location = [value.strip() for value in reversed(fields[2:-1]) if value.strip()]

    if len(fields) > 1 and fields[1].strip():
        location.append(fields[1].strip())

    if len(fields) > 2 and fields[-1].strip():
        location.append(fields[-1].strip())

    if not location:
        return address

    return '{} [{}]'.format(address, ', '.join(location))


def print_addresses(family, addresses):
    if not addresses:
        return

    print('Your IPv{}:'.format(family))

    for address in addresses:
        print(address_details(address))

    print('Found IPv{}: {} {}'.format(family, len(addresses), 'address' if len(addresses) == 1 else 'addresses'))


def run():
    ipv4 = detect_addresses(4)
    ipv6 = detect_addresses(6)

    if not ipv4 and not ipv6:
        raise RequestError('no public IPv4 or IPv6 address was detected')

    print_addresses(4, ipv4)

    if ipv4 and ipv6:
        print()

    print_addresses(6, ipv6)


def main():
    try:
        run()
    except RequestError as error:
        print('My IP failed: {}'.format(error), file=sys.stderr)
        return 1

    return 0


if __name__ == '__main__':
    sys.exit(main())
