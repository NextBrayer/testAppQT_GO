package main

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"time"
)

const commandTimeout = 30 * time.Second

var gpioPortPattern = regexp.MustCompile(`^[a-hA-H]$`)
var gpioReadPattern = regexp.MustCompile(`:\s*([01])\b`)

type gpioReadParams struct {
	Port string `json:"port"`
	Pin  int    `json:"pin"`
}

type gpioWriteParams struct {
	Port  string `json:"port"`
	Pin   int    `json:"pin"`
	Value int    `json:"value"`
}

type gpioValue struct {
	Port  string `json:"port"`
	Pin   int    `json:"pin"`
	Value int    `json:"value"`
}

type wifiConnectParams struct {
	SSID     string `json:"ssid"`
	Password string `json:"password"`
}

type wifiStatus struct {
	Enabled    bool     `json:"enabled"`
	Interface  string   `json:"interface,omitempty"`
	State      string   `json:"state,omitempty"`
	Connection string   `json:"connection,omitempty"`
	IPv4       []string `json:"ipv4"`
}

type powerParams struct {
	Confirm bool `json:"confirm"`
}

func readGPIO(params gpioReadParams) (gpioValue, error) {
	port, pin, err := validateGPIO(params.Port, params.Pin)
	if err != nil {
		return gpioValue{}, err
	}
	output, err := runCommand(gpioCommand(), "r", port, strconv.Itoa(pin))
	if err != nil {
		return gpioValue{}, err
	}
	match := gpioReadPattern.FindStringSubmatch(output)
	if match == nil {
		return gpioValue{}, fmt.Errorf("unexpected GPIO read output: %q", output)
	}
	value, _ := strconv.Atoi(match[1])
	return gpioValue{Port: port, Pin: pin, Value: value}, nil
}

func writeGPIO(params gpioWriteParams) (gpioValue, error) {
	port, pin, err := validateGPIO(params.Port, params.Pin)
	if err != nil {
		return gpioValue{}, err
	}
	if params.Value != 0 && params.Value != 1 {
		return gpioValue{}, fmt.Errorf("GPIO value must be 0 or 1")
	}
	if _, err := runCommand(gpioCommand(), "w", port, strconv.Itoa(pin), strconv.Itoa(params.Value)); err != nil {
		return gpioValue{}, err
	}
	return gpioValue{Port: port, Pin: pin, Value: params.Value}, nil
}

func validateGPIO(port string, pin int) (string, int, error) {
	if !gpioPortPattern.MatchString(port) {
		return "", 0, fmt.Errorf("GPIO port must be a through h")
	}
	if pin < 0 || pin > 31 {
		return "", 0, fmt.Errorf("GPIO pin must be between 0 and 31")
	}
	return strings.ToLower(port), pin, nil
}

func gpioCommand() string {
	if command := os.Getenv("BOARDD_GPIO_COMMAND"); command != "" {
		return command
	}
	return "gpio-test.64"
}

func getWiFiStatus() (wifiStatus, error) {
	interfaceName := wifiInterface()
	statusText, err := runCommand(wpaCLICommand(), "-i", interfaceName, "status")
	if err != nil {
		return wifiStatus{}, err
	}
	properties := keyValueLines(statusText)
	linkText, err := runCommand("ip", "-o", "link", "show", "dev", interfaceName)
	if err != nil {
		return wifiStatus{}, err
	}
	addresses, err := runCommand("ip", "-o", "-4", "addr", "show", "dev", interfaceName)
	if err != nil {
		return wifiStatus{}, err
	}
	return wifiStatus{
		Enabled:    linkIsUp(linkText),
		Interface:  interfaceName,
		State:      properties["wpa_state"],
		Connection: properties["ssid"],
		IPv4:       ipv4Addresses(addresses),
	}, nil
}

func scanWiFi() ([]string, error) {
	interfaceName := wifiInterface()
	if _, err := runCommand(wpaCLICommand(), "-i", interfaceName, "scan"); err != nil {
		return nil, err
	}

	var output string
	var err error
	for attempt := 0; attempt < 5; attempt++ {
		time.Sleep(time.Second)
		output, err = runCommand(wpaCLICommand(), "-i", interfaceName, "scan_results")
		if err == nil && len(strings.Split(strings.TrimSpace(output), "\n")) > 1 {
			break
		}
	}
	if err != nil {
		return nil, err
	}

	unique := make(map[string]struct{})
	for index, line := range strings.Split(strings.TrimSpace(output), "\n") {
		if index == 0 {
			continue
		} // bssid / frequency / signal / flags / ssid header
		fields := strings.SplitN(line, "\t", 5)
		if len(fields) != 5 {
			continue
		}
		ssid := strings.TrimSpace(fields[4])
		if ssid != "" {
			unique[ssid] = struct{}{}
		}
	}
	ssids := make([]string, 0, len(unique))
	for ssid := range unique {
		ssids = append(ssids, ssid)
	}
	sort.Strings(ssids)
	return ssids, nil
}

func connectWiFi(params wifiConnectParams) (wifiStatus, error) {
	if len(params.SSID) == 0 || len(params.SSID) > 32 {
		return wifiStatus{}, fmt.Errorf("Wi-Fi SSID must contain 1 to 32 bytes")
	}
	if len(params.Password) > 0 && (len(params.Password) < 8 || len(params.Password) > 63) {
		return wifiStatus{}, fmt.Errorf("WPA password must contain 8 to 63 bytes")
	}
	interfaceName := wifiInterface()
	networkIDText, err := runCommand(wpaCLICommand(), "-i", interfaceName, "add_network")
	if err != nil {
		return wifiStatus{}, err
	}
	networkID, err := strconv.Atoi(strings.TrimSpace(networkIDText))
	if err != nil {
		return wifiStatus{}, fmt.Errorf("invalid network id from wpa_cli: %q", networkIDText)
	}
	network := strconv.Itoa(networkID)
	if _, err := runCommand(wpaCLICommand(), "-i", interfaceName, "set_network", network, "ssid", strconv.Quote(params.SSID)); err != nil {
		return wifiStatus{}, err
	}
	if params.Password != "" {
		if _, err := runCommand(wpaCLICommand(), "-i", interfaceName, "set_network", network, "psk", strconv.Quote(params.Password)); err != nil {
			return wifiStatus{}, err
		}
	} else if _, err := runCommand(wpaCLICommand(), "-i", interfaceName, "set_network", network, "key_mgmt", "NONE"); err != nil {
		return wifiStatus{}, err
	}
	if _, err := runCommand(wpaCLICommand(), "-i", interfaceName, "enable_network", network); err != nil {
		return wifiStatus{}, err
	}
	if _, err := runCommand(wpaCLICommand(), "-i", interfaceName, "select_network", network); err != nil {
		return wifiStatus{}, err
	}
	if _, err := runCommand(udhcpcCommand(), "-i", interfaceName, "-q", "-n"); err != nil {
		return wifiStatus{}, err
	}
	return getWiFiStatus()
}

func setWiFiEnabled(enabled bool) (wifiStatus, error) {
	state := "down"
	if enabled {
		state = "up"
	}
	if _, err := runCommand("ip", "link", "set", "dev", wifiInterface(), state); err != nil {
		return wifiStatus{}, err
	}
	return getWiFiStatus()
}

func wpaCLICommand() string {
	if command := os.Getenv("BOARDD_WPA_CLI_COMMAND"); command != "" {
		return command
	}
	return "wpa_cli"
}

func udhcpcCommand() string {
	if command := os.Getenv("BOARDD_UDHCPC_COMMAND"); command != "" {
		return command
	}
	return "udhcpc"
}

func wifiInterface() string {
	if name := os.Getenv("BOARDD_WIFI_INTERFACE"); name != "" {
		return name
	}
	return "wlan0"
}

func performPowerAction(method string) error {
	switch method {
	case "power.suspend":
		return os.WriteFile("/sys/power/state", []byte("mem\n"), 0200)
	case "power.reboot":
		_, err := runCommand("reboot")
		return err
	case "power.poweroff":
		_, err := runCommand("poweroff")
		return err
	default:
		return fmt.Errorf("unsupported power action: %s", method)
	}
}

func runCommand(command string, args ...string) (string, error) {
	ctx, cancel := context.WithTimeout(context.Background(), commandTimeout)
	defer cancel()
	output, err := exec.CommandContext(ctx, command, args...).CombinedOutput()
	if ctx.Err() == context.DeadlineExceeded {
		return "", fmt.Errorf("%s timed out", command)
	}
	if err != nil {
		return "", fmt.Errorf("%s failed: %s", command, strings.TrimSpace(string(output)))
	}
	return string(output), nil
}

func ipv4Addresses(output string) []string {
	addresses := make([]string, 0)
	for _, line := range strings.Split(output, "\n") {
		fields := strings.Fields(line)
		for index, field := range fields {
			if field == "inet" && index+1 < len(fields) {
				addresses = append(addresses, fields[index+1])
			}
		}
	}
	return addresses
}

func keyValueLines(output string) map[string]string {
	values := make(map[string]string)
	for _, line := range strings.Split(output, "\n") {
		key, value, found := strings.Cut(line, "=")
		if found {
			values[key] = value
		}
	}
	return values
}

func linkIsUp(output string) bool {
	start := strings.Index(output, "<")
	end := strings.Index(output, ">")
	if start < 0 || end <= start {
		return false
	}
	for _, flag := range strings.Split(output[start+1:end], ",") {
		if flag == "UP" {
			return true
		}
	}
	return false
}
