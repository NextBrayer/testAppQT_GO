package main

import (
	"os"
	"path/filepath"
	"testing"
)

func TestReadUptimeSeconds(t *testing.T) {
	path := filepath.Join(t.TempDir(), "uptime")
	if err := os.WriteFile(path, []byte("93784.62 123.45\n"), 0600); err != nil {
		t.Fatal(err)
	}

	got, err := readUptimeSeconds(path)
	if err != nil {
		t.Fatal(err)
	}
	if got != 93784 {
		t.Fatalf("got %d, want 93784", got)
	}
}

func TestFormatUptime(t *testing.T) {
	if got, want := formatUptime(93784), "1d 02h 03m 04s"; got != want {
		t.Fatalf("got %q, want %q", got, want)
	}
}

func TestListenUnixSocket(t *testing.T) {
	socketPath := filepath.Join(t.TempDir(), "boardd.sock")
	listener, err := listenUnixSocket(socketPath)
	if err != nil {
		t.Fatal(err)
	}
	defer listener.Close()

	info, err := os.Stat(socketPath)
	if err != nil {
		t.Fatal(err)
	}
	if info.Mode()&os.ModeSocket == 0 {
		t.Fatalf("%s is not a Unix socket", socketPath)
	}
}

func TestReadPowerSupplyProperties(t *testing.T) {
	path := filepath.Join(t.TempDir(), "uevent")
	data := "POWER_SUPPLY_STATUS=Discharging\nPOWER_SUPPLY_CAPACITY=67\nOTHER=value\n"
	if err := os.WriteFile(path, []byte(data), 0600); err != nil {
		t.Fatal(err)
	}

	properties := readPowerSupplyProperties(path)
	if properties["STATUS"] != "Discharging" || properties["CAPACITY"] != "67" {
		t.Fatalf("unexpected properties: %#v", properties)
	}
	if _, exists := properties["OTHER"]; exists {
		t.Fatalf("non-power-supply key should not be returned: %#v", properties)
	}
}

func TestMicroToBaseUnit(t *testing.T) {
	value := int64(-956000)
	result := microToBaseUnit(&value)
	if result == nil || *result != -0.956 {
		t.Fatalf("got %v, want -0.956", result)
	}
}

func TestValidateGPIO(t *testing.T) {
	port, pin, err := validateGPIO("H", 31)
	if err != nil || port != "h" || pin != 31 {
		t.Fatalf("valid GPIO rejected: port=%q pin=%d err=%v", port, pin, err)
	}
	if _, _, err := validateGPIO("i", 0); err == nil {
		t.Fatal("invalid GPIO port accepted")
	}
	if _, _, err := validateGPIO("a", 32); err == nil {
		t.Fatal("invalid GPIO pin accepted")
	}
}

func TestIPv4Addresses(t *testing.T) {
	output := "2: wlan0    inet 192.168.10.100/24 brd 192.168.10.255 scope global wlan0\n"
	addresses := ipv4Addresses(output)
	if len(addresses) != 1 || addresses[0] != "192.168.10.100/24" {
		t.Fatalf("unexpected addresses: %#v", addresses)
	}
}

func TestLinkIsUp(t *testing.T) {
	if !linkIsUp("3: wlan0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500") {
		t.Fatal("admin-up interface reported as down")
	}
	if linkIsUp("3: wlan0: <BROADCAST,MULTICAST,LOWER_UP> mtu 1500") {
		t.Fatal("admin-down interface reported as up")
	}
}
