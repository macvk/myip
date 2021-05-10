#!/usr/bin/env bash

RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'
api_domain='bash.ws'

function echo_bold {
    echo -e "${BOLD}${1}${NC}"
}

function check_program_exist {
    command -v $1 > /dev/null
    if [ $? -ne 0 ]; then
        echo "Please, install \"$1\""
        exit 1
    fi
}

function check_internet_connection {
    curl --silent --head  --request GET "https://${api_domain}" | grep "200 OK" > /dev/null
    if [ $? -ne 0 ]; then
        echo "No internet connection."
        exit 1
    fi
}

check_program_exist curl
check_internet_connection

ipv4=$(curl --silent "https://ipv4.${api_domain}/")
ipv6=$(curl --silent "https://ipv6.${api_domain}/")

if [ ! -z "$ipv4" ]; then
        echo_bold "Your IPv4:"
        echo $ipv4
fi

if [ ! -z "$ipv6" ]; then
        echo_bold "Your IPv6:"
        echo $ipv6
fi

exit 0