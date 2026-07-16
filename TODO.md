# To-Do List: Offroad Adventure Trailer

## Phase 1: Concept & CAD Design
- [ ] Measure the Ford Ranger to determine optimal track width and drawbar height.
- [ ] Maintain the weight & tongue-load budget (`scripts/calculate_mass.py`) — decides braked vs. unbraked axle and axle position.
- [ ] Research registration requirements (registreringsbesiktning): lighting, reflectors, fenders, coupling approval. Contact inspection body early.
- [x] CAD model the base frame (VKR profiles) and define bolt patterns for the corners.
- [x] Design the drawbar attachment. (DECIDED: single central VKR 100x50x4 beam; front crossbeam = angle-bracket clamp 2x L80x80x8 with no holes in the beam flanges (`cad/drawbar_angle_joint.scad`), mid crossmember = M12 through-bolt + 10 mm spacer; the beam ends ahead of the axle tube. `cad/drawbar_wedge_plate.scad`/`drawbar_cradle.scad` kept as alternatives.)
- [x] Add fenders, lighting positions, and jockey wheel to the CAD model (`cad/fender.scad`, `cad/road_equipment.scad`, `cad/wheel_axle.scad`).
- [x] **Resolve the track width conflict:** RESOLVED by narrowing the frame to 1200 mm — the 1560 mm Ranger track now fits with 47.5 mm tire-to-body clearance (see `cad/wheel_axle.scad`). Verify against the real car in the "Measure the Ford Ranger" task above.
- [ ] Prototype and physically test ONE bolted corner joint (crush sleeves, torque retention after vibration, Duralac interface) before committing to the full frame.
- [x] Design 3D printed drill guides to ensure accurate hole placement on the steel beams (`cad/drill_guide.scad`).
- [ ] Create a simplified geometry version (non-CNC) for builders without access to a CNC router.
- [x] Set up structural-calculation tooling: `scripts/beam_check.py` (RHS bending, bolt groups, safety factors) + CalculiX FEA in `fea/` (validated drawbar model). See `.claude/skills/structural-calc/`.
- [ ] CAD design and simulate the corner reinforcements ("double sandwich") in 8-10 mm aluminum. (Modeled — corner-plate FEA remains; candidate list in `fea/README.md`.)
- [ ] Design CNC-milled niches for external electrical and gas outlets. (Electrical niche done — gas-side niches remain.)
- [ ] Design mount/cradle for propane tank on the drawbar (including stone protection). (Cradle done — stone-guard tread plate remains.)
- [ ] Develop layouts for the electrical cabinet and network components (star ground, IP65 box).
- [ ] Design the water tank placement and mounting (tank + skid modeled in `cad/water_tank.scad`, but REMOVED from the assembly for now — the underslung mount must clear the central drawbar and axle tube; placeholder mass at x=780 in the tongue budget).
- [x] CAD model the kitchen drawer with space for the 12V compressor fridge and an electrical-only cable chain (`cad/kitchen_drawer.scad`).

## Phase 2: Material Sourcing & Purchasing
- [ ] Order steel (VKR 50x50x3), through-bolts (M12 in 8.8/10.9 — one size frame-wide), and 20x3 precision tube for crush sleeves.
- [ ] Buy 6082-T6 aluminum plates for corners and framework for CNC milling (PrintNC).
- [ ] Purchase braked torsion axle (overrun brakes, bolt pattern 6x139.7) with damper kit and matching overrun coupling, and Falken Wildpeak A/T3W 265/60R18 (with original rims).
- [ ] Order road equipment: E-marked lighting kit, reflectors, fenders, type-approved coupling, jockey wheel, breakaway cable.
- [ ] Order electrical components: IP65 cabinet, Circuit Breakers/RCD, Noco charger, DC-DC MPPT (30 A), Anderson connectors, 200 Ah LiFePO4 battery + shunt.
- [ ] Order solar: 200 W rigid panel + roof-rack brackets + MC4 cabling (see `scripts/calculate_energy.py` for why).
- [ ] Order network gear: Teltonika 5G, Poynting puck antenna, LMR coaxial cables.
- [ ] Purchase gas and water systems: 40L tank, 12V galley pump, GOK/Truma quick connects.
- [ ] Materials for body: Formply (12-15 mm), Dibond (3-4 mm), heavy-duty drawer slides.
- [ ] Consumables: Corrugated conduits, marine grease/Duralac, insulation, cable glands.

## Phase 3: Chassis Build & Mechanics
- [ ] Cut and drill the steel frame (VKR) — 13 mm holes for M12 (all plate bolts on the tube centerline).
- [ ] Cut and fit internal crush sleeves for all through-bolts.
- [ ] CNC mill the aluminum corner plates and drawbar wedge/spacer plates.
- [ ] Dry fit the entire frame with bolted joints for fitment check.
- [ ] Disassemble and send the steel frame for hot-dip galvanizing.
- [ ] Ream all bolt holes clean after galvanizing.
- [ ] Apply Duralac (and G10/FR4 isolators if used) between steel and aluminum — no rubber/vinyl in the joints.
- [ ] Final assembly of the chassis and torque the bolts to spec (crush sleeves in place).
- [ ] Mount axle, dampers, brakes, wheels, and fenders.
- [ ] Schedule re-torque of all structural bolts after the first ~500 km.

## Phase 4: Electrical & Gas Installation
- [ ] Route corrugated conduit and pull electrical/network cables (left side) before fully closing.
- [ ] Install IP65 electrical cabinet and establish star ground (equipotential bonding 6 mm²).
- [ ] Build the standalone battery module (Power Station) with DC-DC/MPPT and Anderson connections.
- [ ] Mount Teltonika router, Poynting antenna, and CNC mill the recessed connection panel.
- [ ] Route propane pipes on the right side and mount CNC-milled niches with external quick connects.
- [ ] Leak test the propane system.

## Phase 5: Body, Water System & Interior
- [ ] Build and mount the floor (formply).
- [ ] Mount framework for sides and clad with Dibond sheets.
- [ ] Mount and protect the water tank (with skid plate) and install 12V pump + lines.
- [ ] Mount heavy-duty drawer slides and build kitchen drawer for the 12V compressor fridge.
- [ ] Install cable chain (energy chain) for flexible transfer of electricity to the kitchen drawer (gas stays on fixed pipes to the external quick-connects).
- [ ] Mount lighting, reflectors, and number plate; verify with 13-pin tester.
- [ ] Test run and commission all systems (water, cooling, heating, electricity).
- [ ] Book and pass registreringsbesiktning.
