// boardd is the board-level hardware API service. Local applications interact
// with this process through a Unix-domain socket; they never execute board
// commands themselves.
package main

import (
	"bufio"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net"
	"os"
	"os/signal"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
)

const serviceVersion = "0.1.0"

type healthResponse struct {
	Status        string `json:"status"`
	Service       string `json:"service"`
	Version       string `json:"version"`
	Hostname      string `json:"hostname"`
	UptimeSeconds uint64 `json:"uptimeSeconds"`
	Uptime        string `json:"uptime"`
}

// request and response form the native IPC contract.  Each message is one JSON
// object followed by a newline, allowing clients to keep a socket open for
// multiple requests without needing HTTP, a web server, or a TCP port.
type request struct {
	ID     json.RawMessage `json:"id"`
	Method string          `json:"method"`
	Params json.RawMessage `json:"params,omitempty"`
}

type response struct {
	ID     json.RawMessage `json:"id"`
	OK     bool            `json:"ok"`
	Result any             `json:"result,omitempty"`
	Error  string          `json:"error,omitempty"`
}

func main() {
	socketPath := os.Getenv("BOARDD_SOCKET")
	if socketPath == "" {
		socketPath = "/run/boardd/boardd.sock"
	}

	listener, err := listenUnixSocket(socketPath)
	if err != nil {
		log.Fatal(err)
	}
	defer func() {
		if err := os.Remove(socketPath); err != nil && !errors.Is(err, os.ErrNotExist) {
			log.Printf("could not remove socket %s: %v", socketPath, err)
		}
	}()

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGINT, syscall.SIGTERM)
	go func() {
		<-stop
		_ = listener.Close()
	}()

	log.Printf("boardd %s listening on unix://%s", serviceVersion, socketPath)
	if err := serve(listener); err != nil && !errors.Is(err, net.ErrClosed) {
		log.Fatal(err)
	}
}

func serve(listener net.Listener) error {
	for {
		connection, err := listener.Accept()
		if err != nil {
			return err
		}
		go handleConnection(connection)
	}
}

func handleConnection(connection net.Conn) {
	defer connection.Close()
	decoder := json.NewDecoder(bufio.NewReader(connection))
	encoder := json.NewEncoder(connection)

	for {
		var req request
		if err := decoder.Decode(&req); err != nil {
			if !errors.Is(err, io.EOF) && !errors.Is(err, net.ErrClosed) {
				log.Printf("IPC client disconnected or sent invalid JSON: %v", err)
			}
			return
		}
		if err := encoder.Encode(dispatch(req)); err != nil {
			log.Printf("IPC response failed: %v", err)
			return
		}
	}
}

func dispatch(req request) response {
	if len(req.ID) == 0 {
		return response{OK: false, Error: "request id is required"}
	}

	switch req.Method {
	case "health.get":
		value, err := health()
		if err != nil {
			return response{ID: req.ID, OK: false, Error: err.Error()}
		}
		return response{ID: req.ID, OK: true, Result: value}
	case "battery.get":
		value, err := getBattery()
		if err != nil {
			return response{ID: req.ID, OK: false, Error: err.Error()}
		}
		return response{ID: req.ID, OK: true, Result: value}
	case "network.status":
		value, err := getNetworkStatus()
		if err != nil {
			return response{ID: req.ID, OK: false, Error: err.Error()}
		}
		return response{ID: req.ID, OK: true, Result: value}
	case "usb.devices":
		value, err := getUSBDevices()
		if err != nil {
			return response{ID: req.ID, OK: false, Error: err.Error()}
		}
		return response{ID: req.ID, OK: true, Result: value}
	case "gpio.read":
		var params gpioReadParams
		if err := decodeParams(req, &params); err != nil {
			return response{ID: req.ID, OK: false, Error: err.Error()}
		}
		value, err := readGPIO(params)
		if err != nil {
			return response{ID: req.ID, OK: false, Error: err.Error()}
		}
		return response{ID: req.ID, OK: true, Result: value}
	case "gpio.write":
		var params gpioWriteParams
		if err := decodeParams(req, &params); err != nil {
			return response{ID: req.ID, OK: false, Error: err.Error()}
		}
		value, err := writeGPIO(params)
		if err != nil {
			return response{ID: req.ID, OK: false, Error: err.Error()}
		}
		return response{ID: req.ID, OK: true, Result: value}
	case "wifi.status":
		value, err := getWiFiStatus()
		if err != nil {
			return response{ID: req.ID, OK: false, Error: err.Error()}
		}
		return response{ID: req.ID, OK: true, Result: value}
	case "wifi.scan":
		value, err := scanWiFi()
		if err != nil {
			return response{ID: req.ID, OK: false, Error: err.Error()}
		}
		return response{ID: req.ID, OK: true, Result: value}
	case "wifi.connect":
		var params wifiConnectParams
		if err := decodeParams(req, &params); err != nil {
			return response{ID: req.ID, OK: false, Error: err.Error()}
		}
		value, err := connectWiFi(params)
		if err != nil {
			return response{ID: req.ID, OK: false, Error: err.Error()}
		}
		return response{ID: req.ID, OK: true, Result: value}
	case "wifi.disconnect":
		value, err := disconnectWiFi()
		if err != nil {
			return response{ID: req.ID, OK: false, Error: err.Error()}
		}
		return response{ID: req.ID, OK: true, Result: value}
	case "wifi.enable":
		value, err := setWiFiEnabled(true)
		if err != nil {
			return response{ID: req.ID, OK: false, Error: err.Error()}
		}
		return response{ID: req.ID, OK: true, Result: value}
	case "wifi.disable":
		value, err := setWiFiEnabled(false)
		if err != nil {
			return response{ID: req.ID, OK: false, Error: err.Error()}
		}
		return response{ID: req.ID, OK: true, Result: value}
	case "power.suspend", "power.reboot", "power.poweroff":
		var params powerParams
		if err := decodeParams(req, &params); err != nil {
			return response{ID: req.ID, OK: false, Error: err.Error()}
		}
		if !params.Confirm {
			return response{ID: req.ID, OK: false, Error: "power action requires confirm: true"}
		}
		if err := performPowerAction(req.Method); err != nil {
			return response{ID: req.ID, OK: false, Error: err.Error()}
		}
		return response{ID: req.ID, OK: true, Result: map[string]string{"action": req.Method}}
	default:
		return response{ID: req.ID, OK: false, Error: "unknown method: " + req.Method}
	}
}

func decodeParams(req request, destination any) error {
	if len(req.Params) == 0 || string(req.Params) == "null" {
		return fmt.Errorf("params are required for %s", req.Method)
	}
	if err := json.Unmarshal(req.Params, destination); err != nil {
		return fmt.Errorf("invalid params for %s: %w", req.Method, err)
	}
	return nil
}

// listenUnixSocket creates a local-only API endpoint.  Removal before listen is
// safe because the socket path is fixed/configured by the administrator; stale
// sockets are left behind after unclean shutdowns.
func listenUnixSocket(socketPath string) (net.Listener, error) {
	directory := filepath.Dir(socketPath)
	if err := os.MkdirAll(directory, 0755); err != nil {
		return nil, fmt.Errorf("create socket directory %s: %w", directory, err)
	}
	if err := os.Remove(socketPath); err != nil && !errors.Is(err, os.ErrNotExist) {
		return nil, fmt.Errorf("remove stale socket %s: %w", socketPath, err)
	}

	listener, err := net.Listen("unix", socketPath)
	if err != nil {
		return nil, fmt.Errorf("listen on unix socket %s: %w", socketPath, err)
	}
	// Owner and group retain access; all other local users are denied.
	if err := os.Chmod(socketPath, 0660); err != nil {
		_ = listener.Close()
		return nil, fmt.Errorf("set socket permissions for %s: %w", socketPath, err)
	}
	return listener, nil
}

func health() (healthResponse, error) {
	uptimeSeconds, err := readUptimeSeconds("/proc/uptime")
	if err != nil {
		return healthResponse{}, fmt.Errorf("could not read Linux uptime: %w", err)
	}

	hostname, err := os.Hostname()
	if err != nil {
		hostname = "unknown"
	}

	return healthResponse{
		Status:        "ok",
		Service:       "boardd",
		Version:       serviceVersion,
		Hostname:      hostname,
		UptimeSeconds: uptimeSeconds,
		Uptime:        formatUptime(uptimeSeconds),
	}, nil
}

func readUptimeSeconds(file string) (uint64, error) {
	data, err := os.ReadFile(file)
	if err != nil {
		return 0, err
	}

	fields := strings.Fields(string(data))
	if len(fields) == 0 {
		return 0, fmt.Errorf("empty uptime data")
	}

	seconds, err := strconv.ParseFloat(fields[0], 64)
	if err != nil || seconds < 0 {
		return 0, fmt.Errorf("invalid uptime value %q", fields[0])
	}
	return uint64(seconds), nil
}

func formatUptime(seconds uint64) string {
	days := seconds / 86400
	seconds %= 86400
	hours := seconds / 3600
	seconds %= 3600
	minutes := seconds / 60
	seconds %= 60
	return fmt.Sprintf("%dd %02dh %02dm %02ds", days, hours, minutes, seconds)
}
