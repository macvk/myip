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
    curl --silent --head --request GET "https://${api_domain}" | grep "200 OK" > /dev/null
    if [ $? -ne 0 ]; then
        echo "No internet connection."
        exit 1
    fi
}

function echo_ip {
    j=$(curl --silent "https://${api_domain}/geoiplookup/$1?embed=txt")

    country=$(echo $j | cut -d '|' -f 2)
    asn=$(echo $j | cut -d '|' -f 3)

    if [ ! -z "$2" ]; then
        echo_bold "$2"
    fi
    echo "$1 [$country, $asn]"
}

function ip2long {
    if [ `echo $1 | tr '.' '\n' | wc -l` != "4" ]; then
        echo "0"
        exit
    fi
    echo "$1" | awk -F\. '{print ($4)+($3*256)+($2*256*256)+($1*256*256*256)}'
}

function ipinrange {
    num=$(ip2long $1)
    left=$(ip2long $2)
    right=$(ip2long $3)
    if [[ $num -gt $left && $num -lt $right ]]; then
        echo "1"
    fi
}

function islocalip {
    if [ ! -z $(ipinrange $1 "10.0.0.0" "10.255.255.255") ]; then
        echo "1"
        exit
    fi

    if [ ! -z $(ipinrange $1 "172.16.0.0" "172.31.255.255") ]; then
        echo "1"
        exit
    fi

    if [ ! -z $(ipinrange $1 "192.168.0.0" "192.168.255.255") ]; then
        echo "1"
        exit
    fi

    if [ ! -z $(ipinrange $1 "169.254.0.0" "169.254.255.255") ]; then
        echo "1"
        exit
    fi

    if [ ! -z $(ipinrange $1 "127.0.0.0" "127.255.255.255") ]; then
        echo "1"
        exit
    fi

    if [ ! -z $(ipinrange $1 "100.64.0.0" "100.64.255.255") ]; then
        echo "1"
        exit
    fi
}

check_program_exist curl
check_internet_connection

ips=()

ipv4=$(curl --silent "https://ipv4.${api_domain}/")
ipv6=$(curl --silent "https://ipv6.${api_domain}/")

if command -v ip &> /dev/null; then
    ipv4_list=$(ip -4 addr | grep -Po "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" | grep -v "0\.0\.0\.0")
    ipv6_list=$(ip -6 addr | grep inet6 | awk -F '[ \t]+|/' '{print $3}' | grep -v ^::1 | grep -v ^fe80)
else
    ipv4_list=$(ifconfig | grep inet | awk '{print $2}' | grep -v '%' | grep -v "::" | grep -v "0\.0\.0\.0")
    ipv6_list=$(ifconfig | grep inet | awk '{print $2}' | grep '%' | cut -d'%' -f 1 | grep -v ^::1 | grep -v ^fe80)
fi



if [ ! -z "$ipv4" ]; then
    echo_ip $ipv4 "Your IPv4:"
    ips+=("$ipv4")
    ipv4_count=1

    while IFS= read -r line; do
        if [ ! -z $(islocalip $line) ]; then
            continue
        fi

        ip=$(curl --silent --interface $line "https://ipv4.${api_domain}/")
        if [ -z "$ip" ]; then
            continue
        fi
        if [[ " ${ips[@]} " =~ " ${ip} " ]]; then
            continue
        fi
        ips+=("$ip")
        ipv4_count=$((ipv4_count+1))

        echo_ip $ip ""
    done <<< "$ipv4_list"

    echo "Found IPv4: $ipv4_count addresses"

fi

if [ ! -z "$ipv6" ]; then
    echo_ip $ipv6 "Your IPv6:"

    ipv6_count=1
    ips+=("$ipv6")

    while IFS= read -r line; do
        if [ ! -z $(islocalip $line) ]; then
            continue
        fi

        ip=$(curl --silent --interface $line "https://ipv6.${api_domain}/")
        if [ -z "$ip" ]; then
            continue
        fi
        if [[ " ${ips[@]} " =~ " ${ip} " ]]; then
            continue
        fi
        ips+=("$ip")
        ipv6_count=$((ipv6_count+1))

        echo_ip $ip ""
    done <<< "$ipv6_list"

    echo "Found IPv6: $ipv6_count addresses"
fi

exit 0
