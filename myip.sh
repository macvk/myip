#!/bin/sh

# Public IP address client for bash.ws.
# Project: https://github.com/macvk/myip
# SPDX-License-Identifier: MIT

BOLD='\033[1m'
NC='\033[0m'
api_domain='bash.ws'
request_timeout=10
seen_ips=''
total_found=0

echo_bold() {
    printf '%b\n' "${BOLD}${1}${NC}"
}

echo_error() {
    printf '%s\n' "$1" >&2
}

require_command() {
    if ! command -v "$1" > /dev/null 2>&1; then
        echo_error "Please, install \"$1\""
        exit 1
    fi
}

remember_ip() {
    if [ -n "$seen_ips" ]; then
        seen_ips="${seen_ips}
$1"
    else
        seen_ips=$1
    fi
}

ip_seen() {
    [ -n "$seen_ips" ] && printf '%s\n' "$seen_ips" | grep -F -x "$1" > /dev/null 2>&1
}

valid_address() {
    address=$1
    family=$2

    if [ "$family" -eq 4 ]; then
        printf '%s\n' "$address" | awk -F. '
            NF != 4 { exit 1 }
            {
                for (i = 1; i <= 4; i++) {
                    if ($i !~ /^[0-9]+$/ || $i < 0 || $i > 255) exit 1
                }
            }
        '
        return
    fi

    case "$address" in
        *[!0-9A-Fa-f:.]*) return 1 ;;
        *:*) return 0 ;;
        *) return 1 ;;
    esac
}

usable_source() {
    source_address=$1
    family=$2

    if ! valid_address "$source_address" "$family"; then
        return 1
    fi

    if [ "$family" -eq 4 ]; then
        case "$source_address" in
            0.*|127.*|169.254.*|22[4-9].*|23[0-9].*) return 1 ;;
        esac
    else
        source_lower=$(printf '%s\n' "$source_address" | tr 'A-F' 'a-f')

        case "$source_lower" in
            ::|::1|fe8*|fe9*|fea*|feb*|ff*) return 1 ;;
        esac
    fi

    return 0
}

local_addresses() {
    family=$1

    if command -v ip > /dev/null 2>&1; then
        ip -o "-${family}" address show up 2>/dev/null | awk '
            {
                address = $4
                sub(/\/.*/, "", address)
                print address
            }
        '
        return
    fi

    if command -v ifconfig > /dev/null 2>&1; then
        if [ "$family" -eq 4 ]; then
            ifconfig 2>/dev/null | awk '
                /inet / {
                    for (i = 1; i < NF; i++) {
                        if ($i == "inet") {
                            address = $(i + 1)
                            sub(/^addr:/, "", address)
                            print address
                        }
                    }
                }
            '
        else
            ifconfig 2>/dev/null | awk '
                /inet6 / {
                    for (i = 1; i < NF; i++) {
                        if ($i == "inet6") {
                            address = $(i + 1)
                            sub(/^addr:/, "", address)
                            sub(/%.*/, "", address)
                            print address
                        }
                    }
                }
            '
        fi
    fi
}

request_address() {
    family=$1
    source_address=$2
    endpoint="https://ipv${family}.${api_domain}/"

    if [ -n "$source_address" ]; then
        curl --silent --show-error --fail --max-time "$request_timeout" --interface "$source_address" "$endpoint" 2>/dev/null
    else
        curl --silent --show-error --fail --max-time "$request_timeout" "$endpoint" 2>/dev/null
    fi
}

address_details() {
    address=$1
    details=$(curl --silent --show-error --fail --max-time "$request_timeout" "https://${api_domain}/geoiplookup/${address}?embed=txt" 2>/dev/null || :)
    country=$(printf '%s\n' "$details" | cut -d '|' -f 2)
    asn=$(printf '%s\n' "$details" | cut -d '|' -f 3)

    if [ -z "$country" ]; then
        printf '%s\n' "$address"
    elif [ -z "$asn" ]; then
        printf '%s [%s]\n' "$address" "$country"
    else
        printf '%s [%s, %s]\n' "$address" "$country" "$asn"
    fi
}

scan_family() {
    family=$1
    sources=$(local_addresses "$family")
    count=0

    for source_address in '' $sources; do
        if [ -n "$source_address" ] && ! usable_source "$source_address" "$family"; then
            continue
        fi

        address=$(request_address "$family" "$source_address" || :)

        if ! valid_address "$address" "$family" || ip_seen "$address"; then
            continue
        fi

        if [ "$count" -eq 0 ]; then
            if [ "$total_found" -ne 0 ]; then
                printf '\n'
            fi

            echo_bold "Your IPv${family}:"
        fi

        remember_ip "$address"
        address_details "$address"
        count=$((count + 1))
        total_found=$((total_found + 1))
    done

    if [ "$count" -eq 1 ]; then
        printf 'Found IPv%s: 1 address\n' "$family"
    elif [ "$count" -gt 1 ]; then
        printf 'Found IPv%s: %s addresses\n' "$family" "$count"
    fi
}

require_command curl
require_command awk
require_command cut
require_command grep
require_command tr

scan_family 4
scan_family 6

if [ "$total_found" -eq 0 ]; then
    echo_error 'My IP failed: no public IPv4 or IPv6 address was detected.'
    exit 1
fi

exit 0
