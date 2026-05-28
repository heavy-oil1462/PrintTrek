#include <SPI.h>
#include <mcp2515.h>

struct can_frame canMsg;
struct can_frame canTxMsg;
MCP2515 mcp2515(10); // CS pin 10

// Define Relays
const int RELAY_WATER_PUMP = 2;
const int RELAY_EXT_LIGHTS = 3;
const int RELAY_FRIDGE = 4;

// Define Sensors (Analog)
const int SENSOR_WATER = A0;
const int SENSOR_TEMP = A1;
const int SENSOR_BATT = A2;

unsigned long lastTxTime = 0;
const unsigned long TX_INTERVAL = 2000; // 2 seconds

void setup() {
  Serial.begin(115200);
  
  // Setup Relays
  pinMode(RELAY_WATER_PUMP, OUTPUT);
  pinMode(RELAY_EXT_LIGHTS, OUTPUT);
  pinMode(RELAY_FRIDGE, OUTPUT);
  
  digitalWrite(RELAY_WATER_PUMP, LOW);
  digitalWrite(RELAY_EXT_LIGHTS, LOW);
  digitalWrite(RELAY_FRIDGE, LOW);

  // Setup CAN
  mcp2515.reset();
  mcp2515.setBitrate(CAN_500KBPS, MCP_8MHZ); // Adjust based on your crystal
  mcp2515.setNormalMode();
  
  Serial.println("CAN Node Initialized.");
}

void loop() {
  // 1. Read incoming CAN messages (commands from Raspberry Pi)
  if (mcp2515.readMessage(&canMsg) == MCP2515::ERROR_OK) {
    // Check if message is for relays (ID 0x201 for commands)
    if (canMsg.can_id == 0x201 && canMsg.can_dlc >= 1) {
      uint8_t state = canMsg.data[0];
      digitalWrite(RELAY_WATER_PUMP, (state & 0x01) ? HIGH : LOW);
      digitalWrite(RELAY_EXT_LIGHTS, (state & 0x02) ? HIGH : LOW);
      digitalWrite(RELAY_FRIDGE, (state & 0x04) ? HIGH : LOW);
      
      // Acknowledge by broadcasting new state (ID 0x200)
      canTxMsg.can_id  = 0x200;
      canTxMsg.can_dlc = 1;
      canTxMsg.data[0] = state;
      mcp2515.sendMessage(&canTxMsg);
      Serial.println("Relays Updated");
    }
  }

  // 2. Broadcast Sensor Data every interval
  unsigned long currentMillis = millis();
  if (currentMillis - lastTxTime >= TX_INTERVAL) {
    lastTxTime = currentMillis;

    // Simulate reading sensors (0-1023 analog range)
    int rawWater = analogRead(SENSOR_WATER);
    int rawTemp = analogRead(SENSOR_TEMP);
    int rawBatt = analogRead(SENSOR_BATT);

    // Map to simple 8-bit values for CAN
    uint8_t waterPercent = map(rawWater, 0, 1023, 0, 100);
    uint8_t tempC = map(rawTemp, 0, 1023, 0, 50); // Just an example mapping
    uint8_t battVoltsX10 = map(rawBatt, 0, 1023, 100, 150); // 10.0V to 15.0V

    // Send Sensor Broadcast (ID 0x100)
    canTxMsg.can_id  = 0x100;
    canTxMsg.can_dlc = 3;
    canTxMsg.data[0] = waterPercent;
    canTxMsg.data[1] = tempC;
    canTxMsg.data[2] = battVoltsX10;

    mcp2515.sendMessage(&canTxMsg);
    Serial.println("Sent Sensor Data");
  }
}
