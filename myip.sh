#!/bin/sh

RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'
api_domain='bash.ws'
ips=''

echo_bold() {
    printf '%b\n' "${BOLD}${1}${NC}"
}

echo_error() {
    printf '%b\n' "${RED}${1}${NC}" >&2
}

check_program_exists() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo_error "Please, install \"$1\""
        exit 1
    fi
}

check_internet_connection() {
    if ! curl --silent --head --request GET "https://${api_domain}" |
        grep -q '200 OK'; then
        echo_error 'No internet connection.'
        exit 1
    fi
}

echo_ip() {
    lookup=$(curl --silent "https://${api_domain}/geoiplookup/${1}?embed=txt")
    country=$(printf '%s\n' "$lookup" | cut -d '|' -f 2)
    asn=$(printf '%s\n' "$lookup" | cut -d '|' -f 3)

    if [ -n "$2" ]; then
        echo_bold "$2"
    fi
    printf '%s [%s, %s]\n' "$1" "$country" "$asn"
}

is_local_ipv4() {
    case "$1" in
        127.* | 169.254.*) return 0 ;;
        *) return 1 ;;
    esac
}

has_ip() {
    [ -n "$ips" ] && printf '%s\n' "$ips" | grep -Fqx "$1"
}

add_ip() {
    if [ -z "$ips" ]; then
        ips=$1
    else
        ips=$(printf '%s\n%s' "$ips" "$1")
    fi
}

check_program_exists curl
check_internet_connection

ipv4=$(curl --silent "https://ipv4.${api_domain}/")
ipv6=$(curl --silent "https://ipv6.${api_domain}/")

if command -v ip >/dev/null 2>&1; then
    ipv4_list=$(ip -o -4 addr show 2>/dev/null |
        awk '{split($4, address, "/"); if (address[1] != "0.0.0.0") print address[1]}')
    ipv6_list=$(ip -o -6 addr show 2>/dev/null |
        awk '{split($4, address, "/"); if (address[1] !~ /^::1$/ && address[1] !~ /^fe80:/) print address[1]}')
else
    check_program_exists ifconfig
    ipv4_list=$(ifconfig 2>/dev/null |
        awk '/inet / {address=$2; sub(/^addr:/, "", address); if (address != "0.0.0.0") print address}')
    ipv6_list=$(ifconfig 2>/dev/null |
        awk '/inet6 / {address=$2; sub(/^addr:/, "", address); sub(/%.*/, "", address); if (address !~ /^::1$/ && address !~ /^fe80:/) print address}')
fi

if [ -n "$ipv4" ]; then
    echo_ip "$ipv4" 'Your IPv4:'
    add_ip "$ipv4"
    ipv4_count=1

    for address in $ipv4_list; do
        if is_local_ipv4 "$address"; then
            continue
        fi

        detected_ip=$(curl --silent --interface "$address" "https://ipv4.${api_domain}/")
        if [ -z "$detected_ip" ] || has_ip "$detected_ip"; then
            continue
        fi

        add_ip "$detected_ip"
        ipv4_count=$((ipv4_count + 1))
        echo_ip "$detected_ip" ''
    done

    if [ "$ipv4_count" -gt 1 ]; then
        printf 'Found IPv4: %s addresses\n' "$ipv4_count"
    fi
fi

if [ -n "$ipv6" ]; then
    echo_ip "$ipv6" 'Your IPv6:'
    add_ip "$ipv6"
    ipv6_count=1

    for address in $ipv6_list; do
        detected_ip=$(curl --silent --interface "$address" "https://ipv6.${api_domain}/")
        if [ -z "$detected_ip" ] || has_ip "$detected_ip"; then
            continue
        fi

        add_ip "$detected_ip"
        ipv6_count=$((ipv6_count + 1))
        echo_ip "$detected_ip" ''
    done

    if [ "$ipv6_count" -gt 1 ]; then
        printf 'Found IPv6: %s addresses\n' "$ipv6_count"
    fi
fi

exit 0
