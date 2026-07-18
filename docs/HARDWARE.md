# PrintTrek controller hardware guide

Reference build for the stock packages. Everything is swappable — see
EXTENDING.md — but this exact combination is what `example-trailer.yaml`
compiles for. The trailer-wide electrical design (bank, solar, DC-DC,
distribution, grounding) lives in SPECS.md section 2; this file covers only
the ESP32 controller and its peripherals.

## Bill of materials

| Qty | Part | Notes | ~Cost |
|----:|------|-------|------:|
| 1 | ESP32 DevKit (esp32dev, WROOM-32) | lives in the electrical bay (IP65 cabinet) | 6 EUR |
| 1 | INA226 breakout | battery monitor, I2C | 4 EUR |
| 1 | 50 A / 75 mV shunt | in the battery main negative | 8 EUR |
| 1 | SHT31 breakout (I2C) | interior temp/RH | 5 EUR |
| 1 | DS18B20 probe (waterproof) | fridge compartment | 3 EUR |
| 1 | Resistive tank level sender (or capacitive strip with 0-3 V out) | 40 L tank | 15 EUR |
| 1 | Buck converter 12 V -> 5 V (>= 1 A, low quiescent) | powers the ESP32 | 5 EUR |
| 3 | Automotive relay or logic-level N-MOSFET module (IRLZ44N class) | pump, lights, fridge | 6 EUR |
| — | 4.7 kOhm resistor (1-wire pull-up), divider resistors for the sender, wire, glands | | 5 EUR |

The pump, lights, fridge, battery bank, solar and DC-DC hardware are in the
main BOM (MATERIALS.md) — the controller just switches and measures them.

## Default pin map (all overridable via substitutions)

| Function | GPIO | Substitution | Constraint |
|---|---|---|---|
| I2C SDA / SCL | 21 / 22 | `i2c_sda` / `i2c_scl` | INA226 + SHT31 share the bus |
| Water level ADC | 34 | `water_adc_pin` | **ADC1 only** (32-39): ADC2 is unusable with WiFi. 34/35 are input-only. |
| Fridge DS18B20 (1-wire) | 4 | `fridge_onewire_pin` | 4.7 kOhm pull-up to 3.3 V |
| Fridge relay | 25 | `fridge_pin` | |
| Lights relay | 26 | `lights_pin` | |
| Pump relay | 27 | `pump_pin` | |

Avoid strapping pins (0, 2, 12, 15) for outputs that must not glitch at
boot — a boot glitch on the pump relay pressurizes the system unasked.

## Wiring

```
   12V bank (+) ──┬──────────► relay ──► fridge (12V compressor)
                  ├──────────► relay ──► pump
                  ├──────────► relay ──► exterior lights
                  └──► buck 12->5V ──► ESP32 5V/GND
   12V bank (-) ──[ 50A/75mV shunt ]── chassis loads return
                        │
                   INA226 (I2C): shunt sense + bus voltage tap to bank (+)

   tank sender ── divider from 3.3V ──► GPIO34
   DS18B20 (fridge box) ── data ► GPIO4, 4.7k pull-up to 3.3V
   SHT31 + INA226 ── I2C ► GPIO21/22
```

The INA226 measures NET bank current: positive while the solar MPPT or
DC-DC charges, negative while the fridge/pump/lights discharge. Put ALL
load/charge return paths through the shunt or the reading lies.

## Tank sender calibration

1. Flash, open logs (USB or OTA — the radio is always on by default).
2. Tank empty -> note "Water Level Raw Voltage" -> `water_raw_empty_v`.
3. Fill the tank brim full -> note voltage -> `water_raw_full_v`.
4. Set both substitutions in your node config, re-flash. Resistive senders
   step in ~10 % increments; treat the gauge as coarse.

## Power draw

The controller itself is a rounding error in the trailer's budget
(`scripts/calculate_energy.py`): ESP32 with WiFi on ~0.6 W, sensors ~0.1 W.
That is why "Radio Always On" is the default — the 200 Ah bank spends more
on the fridge in 10 minutes than the radio costs per day. Storage mode
(duty-cycled radio, docs/PROTOCOL.md) exists for winter storage where every
self-discharge amp-hour counts.

## Placement notes

- Controller in the electrical bay (mid right), on the 12 V distribution —
  short runs to the fridge drawer's energy chain and the pump.
- The SHT31 wants airflow, away from the fridge compressor's warm exhaust.
- Conformal-coat the tank sender connections; glands facing down.
- The DS18B20 lead runs inside the fridge drawer's energy chain with the
  12 V supply.
