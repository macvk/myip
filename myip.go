// Public IP address client for bash.ws.
// Project: https://github.com/macvk/myip
// SPDX-License-Identifier: MIT

package main

import (
	"context"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/url"
	"os"
	"strings"
	"time"
)

const (
	version      = "1.0.0"
	apiDomain    = "bash.ws"
	requestLimit = 10 * time.Second
)

func request(host, path string, source net.IP) (string, error) {
	transport := http.DefaultTransport.(*http.Transport).Clone()

	if source != nil {
		dialer := &net.Dialer{LocalAddr: &net.TCPAddr{IP: source}}
		transport.DialContext = func(ctx context.Context, network, address string) (net.Conn, error) {
			return dialer.DialContext(ctx, network, address)
		}
	}

	defer transport.CloseIdleConnections()
	client := &http.Client{Transport: transport, Timeout: requestLimit}
	request, err := http.NewRequest(http.MethodGet, "https://"+host+path, nil)

	if err != nil {
		return "", err
	}

	request.Header.Set("User-Agent", "bash.ws myip-go/"+version)
	response, err := client.Do(request)

	if err != nil {
		return "", err
	}

	defer response.Body.Close()

	data, err := io.ReadAll(response.Body)

	if err != nil {
		return "", err
	}

	if response.StatusCode < 200 || response.StatusCode >= 300 {
		return "", fmt.Errorf("%s returned HTTP %d", host, response.StatusCode)
	}

	return strings.TrimSpace(string(data)), nil
}

func addressFamily(address net.IP) int {
	if address.To4() != nil {
		return 4
	}

	return 6
}

func localAddresses(family int) []net.IP {
	var result []net.IP
	seen := make(map[string]bool)
	interfaces, err := net.Interfaces()

	if err != nil {
		return result
	}

	for _, device := range interfaces {
		if device.Flags&net.FlagUp == 0 || device.Flags&net.FlagLoopback != 0 {
			continue
		}

		addresses, err := device.Addrs()

		if err != nil {
			continue
		}

		for _, value := range addresses {
			address, _, err := net.ParseCIDR(value.String())

			if err != nil || addressFamily(address) != family || address.IsLoopback() || address.IsLinkLocalUnicast() || address.IsUnspecified() || address.IsMulticast() {
				continue
			}

			key := address.String()

			if seen[key] {
				continue
			}

			seen[key] = true
			result = append(result, address)
		}
	}

	return result
}

func detectAddresses(family int) []string {
	host := fmt.Sprintf("ipv%d.%s", family, apiDomain)
	sources := append([]net.IP{nil}, localAddresses(family)...)
	result := []string{}
	seen := make(map[string]bool)

	for _, source := range sources {
		value, err := request(host, "/", source)

		if err != nil {
			continue
		}

		address := net.ParseIP(value)

		if address == nil || addressFamily(address) != family {
			continue
		}

		key := address.String()

		if seen[key] {
			continue
		}

		seen[key] = true
		result = append(result, key)
	}

	return result
}

func addressDetails(address string) string {
	value, err := request(apiDomain, "/geoiplookup/"+url.PathEscape(address)+"?embed=txt", nil)

	if err != nil {
		return address
	}

	fields := strings.Split(value, "|")
	var country, asn string

	if len(fields) > 1 {
		country = strings.TrimSpace(fields[1])
	}

	if len(fields) > 2 {
		asn = strings.TrimSpace(fields[2])
	}

	if country == "" {
		return address
	}

	if asn == "" {
		return fmt.Sprintf("%s [%s]", address, country)
	}

	return fmt.Sprintf("%s [%s, %s]", address, country, asn)
}

func printAddresses(family int, addresses []string) {
	if len(addresses) == 0 {
		return
	}

	fmt.Printf("Your IPv%d:\n", family)

	for _, address := range addresses {
		fmt.Println(addressDetails(address))
	}

	noun := "addresses"

	if len(addresses) == 1 {
		noun = "address"
	}

	fmt.Printf("Found IPv%d: %d %s\n", family, len(addresses), noun)
}

func run() error {
	ipv4 := detectAddresses(4)
	ipv6 := detectAddresses(6)

	if len(ipv4) == 0 && len(ipv6) == 0 {
		return errors.New("no public IPv4 or IPv6 address was detected")
	}

	printAddresses(4, ipv4)

	if len(ipv4) != 0 && len(ipv6) != 0 {
		fmt.Println()
	}

	printAddresses(6, ipv6)
	return nil
}

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, "My IP failed:", err)
		os.Exit(1)
	}
}
