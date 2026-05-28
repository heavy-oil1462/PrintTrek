package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/brutella/can"
	"github.com/gorilla/websocket"
)

// Relays defines the state of the trailer relays
type Relays struct {
	WaterPump      bool `json:"water_pump"`
	ExteriorLights bool `json:"exterior_lights"`
	Fridge         bool `json:"fridge"`
}

// TrailerState holds all sensor data and relay states
type TrailerState struct {
	WaterLevel     uint8   `json:"water_level"`
	BatteryVoltage float32 `json:"battery_voltage"`
	Temperature    uint8   `json:"temperature"`
	Relays         Relays  `json:"relays"`
}

var (
	state = TrailerState{
		WaterLevel:     0,
		BatteryVoltage: 12.0,
		Temperature:    20,
		Relays: Relays{
			WaterPump:      false,
			ExteriorLights: false,
			Fridge:         false,
		},
	}
	stateMutex sync.Mutex

	// WebSocket upgrader
	upgrader = websocket.Upgrader{
		CheckOrigin: func(r *http.Request) bool {
			return true // Allow all origins for local dev
		},
	}

	clients      = make(map[*websocket.Conn]bool)
	clientsMutex sync.Mutex

	// Global CAN bus interface
	canBus *can.Bus
)

func main() {
	// 1. Initialize CAN Bus in a goroutine
	go initCAN()

	// 2. Setup HTTP routes
	// Serve the frontend static files
	fs := http.FileServer(http.Dir("../frontend"))
	http.Handle("/", fs)

	// API Endpoints
	http.HandleFunc("/api/state", handleGetState)
	http.HandleFunc("/api/relays/", handleToggleRelay)

	// WebSocket Endpoint
	http.HandleFunc("/ws", handleWebSocket)

	// Broadcast loop
	go broadcastLoop()

	fmt.Println("Server starting on :8000...")
	fmt.Println("Serving frontend from ../frontend")
	log.Fatal(http.ListenAndServe(":8000", nil))
}

func initCAN() {
	var err error
	canBus, err = can.NewBusForInterfaceWithName("vcan0")
	if err != nil {
		log.Printf("Failed to connect to vcan0: %v. Simulation only.", err)
		return
	}
	log.Println("Connected to vcan0 successfully.")

	canBus.SubscribeFunc(func(msg can.Frame) {
		stateMutex.Lock()
		defer stateMutex.Unlock()

		if msg.ID == 0x100 && msg.Length >= 3 {
			state.WaterLevel = msg.Data[0]
			state.Temperature = msg.Data[1]
			state.BatteryVoltage = float32(msg.Data[2]) / 10.0
		} else if msg.ID == 0x200 && msg.Length >= 1 {
			val := msg.Data[0]
			state.Relays.WaterPump = (val & 0x01) != 0
			state.Relays.ExteriorLights = (val & 0x02) != 0
			state.Relays.Fridge = (val & 0x04) != 0
		}
	})

	canBus.ConnectAndPublish()
}

func handleGetState(w http.ResponseWriter, r *http.Request) {
	stateMutex.Lock()
	defer stateMutex.Unlock()

	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Access-Control-Allow-Origin", "*")
	json.NewEncoder(w).Encode(state)
}

func handleToggleRelay(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Methods", "POST")

	parts := strings.Split(r.URL.Path, "/")
	if len(parts) < 4 {
		http.Error(w, "Invalid relay name", http.StatusBadRequest)
		return
	}
	relayName := parts[3]

	stateStr := r.URL.Query().Get("state")
	newState, err := strconv.ParseBool(stateStr)
	if err != nil {
		http.Error(w, "Invalid state boolean", http.StatusBadRequest)
		return
	}

	stateMutex.Lock()
	switch relayName {
	case "water_pump":
		state.Relays.WaterPump = newState
	case "exterior_lights":
		state.Relays.ExteriorLights = newState
	case "fridge":
		state.Relays.Fridge = newState
	default:
		stateMutex.Unlock()
		http.Error(w, "Unknown relay", http.StatusBadRequest)
		return
	}
	stateMutex.Unlock()

	// In a real system, we would construct a CAN frame and send it here.
	// For example: canBus.Publish(can.Frame{ID: 0x201, Length: 1, Data: [...]})

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"status": "success",
		"relay":  relayName,
		"state":  newState,
	})
}

func handleWebSocket(w http.ResponseWriter, r *http.Request) {
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Println("WebSocket upgrade failed:", err)
		return
	}

	clientsMutex.Lock()
	clients[conn] = true
	clientsMutex.Unlock()

	// Send initial state
	stateMutex.Lock()
	initialState, _ := json.Marshal(state)
	stateMutex.Unlock()
	conn.WriteMessage(websocket.TextMessage, initialState)

	// Keep alive reading loop
	for {
		if _, _, err := conn.ReadMessage(); err != nil {
			clientsMutex.Lock()
			delete(clients, conn)
			clientsMutex.Unlock()
			conn.Close()
			break
		}
	}
}

func broadcastLoop() {
	ticker := time.NewTicker(500 * time.Millisecond)
	for range ticker.C {
		stateMutex.Lock()
		msg, _ := json.Marshal(state)
		stateMutex.Unlock()

		clientsMutex.Lock()
		for client := range clients {
			err := client.WriteMessage(websocket.TextMessage, msg)
			if err != nil {
				client.Close()
				delete(clients, client)
			}
		}
		clientsMutex.Unlock()
	}
}
