package main

import (
	"log"
	"math/rand"
	"time"

	"github.com/brutella/can"
)

func main() {
	bus, err := can.NewBusForInterfaceWithName("vcan0")
	if err != nil {
		log.Fatalf("Failed to connect to vcan0: %v. Did you run 'sudo modprobe vcan'?", err)
	}

	go bus.ConnectAndPublish()

	waterLevel := 50
	temperature := 22
	batteryVoltageX10 := 125

	log.Println("Simulator started on vcan0...")

	for {
		// fluctuate
		waterLevel += rand.Intn(3) - 1
		temperature += rand.Intn(3) - 1
		batteryVoltageX10 += rand.Intn(3) - 1

		if waterLevel < 0 { waterLevel = 0 }
		if waterLevel > 100 { waterLevel = 100 }
		if temperature < 10 { temperature = 10 }
		if temperature > 40 { temperature = 40 }
		if batteryVoltageX10 < 110 { batteryVoltageX10 = 110 }
		if batteryVoltageX10 > 140 { batteryVoltageX10 = 140 }

		msg := can.Frame{
			ID:     0x100,
			Length: 3,
			Data:   [8]uint8{uint8(waterLevel), uint8(temperature), uint8(batteryVoltageX10), 0, 0, 0, 0, 0},
		}

		bus.Publish(msg)
		log.Printf("Sent ID 0x100: Water=%d%%, Temp=%dC, Batt=%.1fV", waterLevel, temperature, float32(batteryVoltageX10)/10.0)

		time.Sleep(2 * time.Second)
	}
}
