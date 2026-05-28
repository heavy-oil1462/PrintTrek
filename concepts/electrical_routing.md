# Concept: Electrical & Network Routing (Left Side)

**Purpose:** Maximize operational reliability, personal safety, and signal integrity through rigorous separation from propane, single-point grounding, and smart exposure/encapsulation.

## Details & Structure
- **Single-Point Grounding (Star Grounding):** The chassis features a central, heavy-duty bolt/terminal. All subsystems (230V protective earth, 12V negative, and equipotential bonding) are routed here together. The purpose is to avoid stray currents and ground loops. The steel frame is connected with a 6 mm² yellow/green cable.
- **Tunnel Design in Corners:** The steel acts as an armored conduit, but at each 90-degree corner, the profiles are welded shut (or bolted tightly). Drilling with a rubber grommet is done just *before* the corners, and the flexible conduit takes a soft "shortcut" inside the double sandwich of aluminum plates.
- **Network (RF):** Coaxial cables (like LMR-200/400) are sensitive to sharp bends and crush damage. The corner passthroughs must have a carefully calculated bending radius.
- **Modular Power Station:** Designed as a standalone box. The box has large, heavy-duty Anderson connectors on the outside for in/out. It contains the 12V battery bank, DC-DC charger, MPPT, and Noco 230V charger. The box must be removable from the trailer in 1 minute for winter storage or external use at basecamp.

## Next Steps
1. Sketch out a formal electrical schematic (Single Line Diagram) for 12V and 230V.
2. Design/CNC mill the electrical niche: A recessed module in the left Dibond wall that neatly houses the 230V CEE inlet and weather-protected N-connectors for the Poynting antenna.
