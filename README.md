# PrintTrek

![Main Assembly](main_assembly.png)

**PrintTrek** is an open-source, highly engineered, and modular offroad adventure trailer designed to be manufactured using a custom CNC router (like the PrintNC) and basic hand tools.

Built to traverse rugged terrain and function as an ultimate basecamp, PrintTrek eliminates the need for complex and fatigue-prone welding by utilizing a structural, bolted-together chassis. It is specifically designed to be the perfect companion for a mid-size pickup (like the Ford Ranger), matching its track width, wheel specs, and offroad capabilities.

## Project Goals

1. **Weld-Free Assembly:** Eliminate the barrier of entry and fatigue issues associated with welding. The entire frame is bolted together using through-bolts and heavy-duty, CNC-milled aluminum corner plates (the "double sandwich" method).
2. **Open Source & Maker-Friendly:** Provide complete, open-source CAD files and instructions so anyone with access to a CNC router (like a PrintNC) can mill the complex components themselves. Additionally, 3D printed drill guides will be provided for precise hole placement, and a simplified geometry version will be available for builders without CNC access.
3. **Extreme Durability:** Utilize hot-dip galvanized steel framing, 6082-T6 aluminum nodes, and strict galvanic corrosion protection to ensure the trailer survives decades of abuse in harsh environments.
4. **Safety & Separation of Systems:** Isolate electrical and network systems on the left side of the chassis, and the propane system entirely on the right side.
5. **Modularity:** Allow builders to customize the body panels (Dibond/plywood), electrical payload, and slide-out kitchen configuration without compromising the core structural integrity.

## Key Features

- **Tow-Vehicle Synchronization:** Matches the Ford Ranger's 6x139.7 bolt pattern and track width, allowing the use of shared spare wheels (e.g., 265/60R18 Falken Wildpeak A/T3W).
- **CNC-Optimized Design:** Heavily relies on flat-pack milled aluminum brackets, niches, and nodes that can be routed accurately at home.
- **Off-Grid Capabilities:**
  - 40L food-grade water tank centrally mounted with a 3mm aluminum skid plate.
  - Dedicated drawbar mount for a 6kg propane cylinder with built-in stone protection.
  - Recessed, milled niches for external water, gas, and power outlets.
  - Modular "Power Station" 12V box, 230V mains integration, and Teltonika 5G network integration.
- **Slide-Out Kitchen:** Accommodates a heavy-duty drawer (100-150kg slides) for a Dometic combi fridge and stove, fed safely via a flexible cable/gas energy chain.

## Repository Structure

- `/cad`: Contains all the 3D models and manufacturing files (e.g., OpenSCAD, STEP, or STL files) for the corner plates, niches, and chassis geometry.
- `/concepts`: Markdown files and diagrams detailing sub-systems (like electrical routing, propane layout, and water flow).
- `MATERIALS.md`: A comprehensive Bill of Materials (BOM) detailing the steel, aluminum, fasteners, and specific off-the-shelf components required.
- `SPECS.md`: The core technical specifications and overarching design decisions.
- `TODO.md`: The phased checklist of design, purchasing, and construction tasks.

## How to Contribute or Build Your Own

Currently, the project is in the **Concept & CAD Design phase**. 

If you are interested in building your own PrintTrek, or want to contribute to the CAD models, electrical schematics, or documentation, feel free to fork this repository, open an issue, or submit a pull request!
