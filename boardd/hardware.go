package main

import (
	"fmt"
	"net"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
)

const powerSupplyPath = "/sys/class/power_supply"
const usbDevicesPath = "/sys/bus/usb/devices"

type batteryStatus struct {
	Device             string            `json:"device"`
	ModelName          string            `json:"modelName,omitempty"`
	Present            bool              `json:"present"`
	Online             bool              `json:"online"`
	Capacity           *int              `json:"capacityPercent"`
	State              string            `json:"state"`
	Health             string            `json:"health,omitempty"`
	Technology         string            `json:"technology,omitempty"`
	TemperatureC       *float64          `json:"temperatureC"`
	ChargeCounterAmpHr *float64          `json:"chargeCounterAmpHours"`
	ChargeFullAmpHr    *float64          `json:"chargeFullAmpHours"`
	VoltageNowVolts    *float64          `json:"voltageNowVolts"`
	VoltageMaxVolts    *float64          `json:"voltageMaxDesignVolts"`
	VoltageMinVolts    *float64          `json:"voltageMinDesignVolts"`
	CurrentNowAmps     *float64          `json:"currentNowAmps"`
	Properties         map[string]string `json:"properties"`
}

type networkStatus struct {
	Interfaces []networkInterface `json:"interfaces"`
}

type networkInterface struct {
	Name      string   `json:"name"`
	Up        bool     `json:"up"`
	Loopback  bool     `json:"loopback"`
	MAC       string   `json:"mac"`
	Addresses []string `json:"addresses"`
}

type usbDevice struct {
	Path         string `json:"path"`
	VendorID     string `json:"vendorId"`
	ProductID    string `json:"productId"`
	Manufacturer string `json:"manufacturer,omitempty"`
	Product      string `json:"product,omitempty"`
	Serial       string `json:"serial,omitempty"`
	BusNumber    string `json:"busNumber,omitempty"`
	DeviceNumber string `json:"deviceNumber,omitempty"`
}

func getBattery() (batteryStatus, error) {
	entries, err := os.ReadDir(powerSupplyPath)
	if err != nil {
		return batteryStatus{}, fmt.Errorf("read power supplies: %w", err)
	}

	for _, entry := range entries {
		// /sys/class/power_supply entries are normally symbolic links to the
		// physical device, so DirEntry.IsDir reports false even though the
		// target has the files we need.
		base := filepath.Join(powerSupplyPath, entry.Name())
		properties := readPowerSupplyProperties(filepath.Join(base, "uevent"))
		isBattery := readSysfsString(filepath.Join(base, "type")) == "Battery" ||
			strings.Contains(strings.ToLower(entry.Name()), "battery") ||
			(properties["CAPACITY"] != "" && properties["TECHNOLOGY"] != "")
		if !isBattery {
			continue
		}

		capacity := intProperty(properties, "CAPACITY")
		tempRaw := int64Property(properties, "TEMP")
		var temperature *float64
		if tempRaw != nil {
			value := float64(*tempRaw) / 10
			temperature = &value
		}

		present := properties["PRESENT"] != "0"
		return batteryStatus{
			Device:             entry.Name(),
			ModelName:          properties["MODEL_NAME"],
			Present:            present,
			Online:             properties["ONLINE"] == "1",
			Capacity:           capacity,
			State:              strings.ToLower(properties["STATUS"]),
			Health:             properties["HEALTH"],
			Technology:         properties["TECHNOLOGY"],
			TemperatureC:       temperature,
			ChargeCounterAmpHr: microToBaseUnit(int64Property(properties, "CHARGE_COUNTER")),
			ChargeFullAmpHr:    microToBaseUnit(int64Property(properties, "CHARGE_FULL")),
			VoltageNowVolts:    microToBaseUnit(int64Property(properties, "VOLTAGE_NOW")),
			VoltageMaxVolts:    microToBaseUnit(int64Property(properties, "VOLTAGE_MAX_DESIGN")),
			VoltageMinVolts:    microToBaseUnit(int64Property(properties, "VOLTAGE_MIN_DESIGN")),
			CurrentNowAmps:     microToBaseUnit(int64Property(properties, "CURRENT_NOW")),
			Properties:         properties,
		}, nil
	}

	return batteryStatus{}, fmt.Errorf("no battery found in %s", powerSupplyPath)
}

func getNetworkStatus() (networkStatus, error) {
	interfaces, err := net.Interfaces()
	if err != nil {
		return networkStatus{}, fmt.Errorf("list network interfaces: %w", err)
	}

	result := networkStatus{Interfaces: make([]networkInterface, 0, len(interfaces))}
	for _, iface := range interfaces {
		addresses, err := iface.Addrs()
		if err != nil {
			return networkStatus{}, fmt.Errorf("read addresses for %s: %w", iface.Name, err)
		}

		values := make([]string, 0, len(addresses))
		for _, address := range addresses {
			values = append(values, address.String())
		}
		sort.Strings(values)
		result.Interfaces = append(result.Interfaces, networkInterface{
			Name:      iface.Name,
			Up:        iface.Flags&net.FlagUp != 0,
			Loopback:  iface.Flags&net.FlagLoopback != 0,
			MAC:       iface.HardwareAddr.String(),
			Addresses: values,
		})
	}
	sort.Slice(result.Interfaces, func(i, j int) bool {
		return result.Interfaces[i].Name < result.Interfaces[j].Name
	})
	return result, nil
}

func getUSBDevices() ([]usbDevice, error) {
	entries, err := os.ReadDir(usbDevicesPath)
	if err != nil {
		return nil, fmt.Errorf("read USB devices: %w", err)
	}

	devices := make([]usbDevice, 0)
	for _, entry := range entries {
		// /sys/bus/usb/devices also uses symbolic links.  Physical devices are
		// identified by idVendor/idProduct below; USB interface entries lack them.
		base := filepath.Join(usbDevicesPath, entry.Name())
		vendorID := readSysfsString(filepath.Join(base, "idVendor"))
		productID := readSysfsString(filepath.Join(base, "idProduct"))
		if vendorID == "" || productID == "" {
			continue // USB interface directories do not identify a physical device.
		}
		devices = append(devices, usbDevice{
			Path:         entry.Name(),
			VendorID:     vendorID,
			ProductID:    productID,
			Manufacturer: readSysfsString(filepath.Join(base, "manufacturer")),
			Product:      readSysfsString(filepath.Join(base, "product")),
			Serial:       readSysfsString(filepath.Join(base, "serial")),
			BusNumber:    readSysfsString(filepath.Join(base, "busnum")),
			DeviceNumber: readSysfsString(filepath.Join(base, "devnum")),
		})
	}
	sort.Slice(devices, func(i, j int) bool { return devices[i].Path < devices[j].Path })
	return devices, nil
}

func readSysfsString(path string) string {
	data, err := os.ReadFile(path)
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(data))
}

func readPowerSupplyProperties(path string) map[string]string {
	properties := make(map[string]string)
	data, err := os.ReadFile(path)
	if err != nil {
		return properties
	}
	for _, line := range strings.Split(string(data), "\n") {
		key, value, found := strings.Cut(line, "=")
		if !found || !strings.HasPrefix(key, "POWER_SUPPLY_") {
			continue
		}
		properties[strings.TrimPrefix(key, "POWER_SUPPLY_")] = value
	}
	return properties
}

func intProperty(properties map[string]string, key string) *int {
	value := int64Property(properties, key)
	if value == nil || *value > int64(^uint(0)>>1) || *value < -int64(^uint(0)>>1)-1 {
		return nil
	}
	result := int(*value)
	return &result
}

func int64Property(properties map[string]string, key string) *int64 {
	value, err := strconv.ParseInt(properties[key], 10, 64)
	if err != nil {
		return nil
	}
	return &value
}

func microToBaseUnit(value *int64) *float64 {
	if value == nil {
		return nil
	}
	converted := float64(*value) / 1_000_000
	return &converted
}
