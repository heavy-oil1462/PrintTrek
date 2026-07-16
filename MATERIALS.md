# Material & Component List (BOM)

## Chassis & Mechanics
- **Steel Profiles:** Square steel tubes VKR 50x50x3 mm — ONE profile for the whole trailer: rails, crossbeams, AND the two V-drawbar arms (2x ~1.75 m, straight square cuts only). (Legacy single-bar alternative: drawbar in VKR 100x50x4 mm, ~2.1 m, standing on edge.)
- **Corner Plates:** Aluminum 6082-T6, 8-10 mm (for CNC milling). T-plates: 4x for the mid crossbeam (top+bottom sandwich) + 8x for the OPTIONAL floor crossbars at x=500/1500 (same CNC part, same top+bottom sandwich; omit if the floor crossbars are toggled off — they are OFF by default).
- **V-Drawbar Plates (6082-T6, 10 mm):** 2x apex plates (`cad/v_apex_plate.scad`, top+bottom sandwich over the arm tips, ~1.2 kg ea); 4x wedge spacer plates (`cad/drawbar_wedge_plate.scad`) for the angled laps at the front crossbeam and rail ends; 2x gas-box bearer plates spanning the arms.
- **Fasteners:** Through-bolts M12 in grade 8.8 or 10.9 throughout — ONE bolt size, one 13 mm hole size, one ~91 Nm torque figure for every structural joint. Plate joints use 2 bolts per arm on the tube centerline (e2 = 1.9·d0 vs the old M10 zig-zag's 1.18·d0). Lock nuts (or Nord-Lock washers) and hardened washers — with 2 bolts per arm instead of 3-4, positive locking is mandatory, not optional. (M10 remains only in non-structural mounts, e.g. the gas-box bearers.)
- **Crush Sleeves:** Internal steel sleeves for every through-bolt (precision tube, 20x3 mm for M12; 16x2.5 mm for the odd M10), cut to the inner width of the VKR profile — required to reach full bolt preload without collapsing the 3 mm tube walls.
- **Galvanic Corrosion Insulation:** Duralac anodic paste; optionally 0.5-1 mm G10/FR4 sheet as a rigid isolator. (No rubber/vinyl shims in structural joints — elastomers creep and kill bolt preload.)
- **Wheels & Axle:** Braked torsion axle (overrun brakes, e.g., Knott/AL-KO) with 6x139.7 bolt pattern + shock absorber (damper) kit + matching overrun coupling with breakaway cable.
- **Tires/Rims:** Falken Wildpeak A/T3W 265/60R18 on Ford Ranger original rims (x2 — no spare on the trailer; the Ranger's underslung spare serves both).
- **Gas Locker Box:** Caravan-style drawbar box for the P6 bottle (off-the-shelf poly, Fiamma/Thule class, or CNC-folded aluminum tread plate), with low-level ventilation per EN 1949, lockable lid, internal strap points. Mounting on the V-drawbar: bolts onto 2x 10 mm aluminum bearer plates spanning the two arms (single-bar alternative: bearers + U-straps clamped around the beam — no holes in any drawbar member either way).
- **Drawbar Joint (front crossbeam):** sleeve-clamp per V-arm crossing: 2x M12 through the crossbeam beside the arm + 2x steel spacer sleeves (~18x3 mm, 60 mm, cut ~0.5 mm short so the arm carries the preload) + 1x 10 mm 6082-T6 clamp plate (60x140) under the arm — zero holes in the arm at its peak-moment point (`check_v_joints`). Rail-end laps: 1x M12 each through rail + wedge + arm. (Legacy single-bar joint: 2x steel angle L80x80x8 S355, 120 mm, hot-dip galvanized; CNC-milled 6082-T6 cradle; or M12 square U-bolts — which fit the straight bar, but not the V's skewed crossings.)

## Electrical System & Electronics (Left Side)
- **Cable Protection:** Corrugated conduit (automotive grade).
- **Distribution Board:** IP65-rated electrical cabinet, grounding busbar for star grounding.
- **Cables:** 6 mm² yellow/green ground cable for equipotential bonding, various tinned marine/automotive cables.
- **230V Components:** Blue CEE inlet, residual current device (RCD), circuit breakers (10A/13A), IP66-rated external outlets.
- **Charging & Battery:**
  - LiFePO4 battery 200 Ah (~19 kg) with BMS + battery shunt/coulomb counter.
  - Noco battery charger (230V to 12V).
  - DC-DC charger with built-in MPPT (e.g., Victron or Renogy), 30 A.
  - Solar: 200 W rigid panel, roof-rack mounting brackets, MC4 cabling to the external solar input.
  - Heavy-duty Anderson connectors.
- **Network:** Teltonika 5G industrial router (12V), Poynting 5G/Wifi puck antenna, LMR-200/400 coaxial cables, external N-connectors.

## Propane System (Right Side)
- **Tank:** 6 kg propane cylinder (P6/PK6).
- **Piping:** Copper or steel pipes (adapted for vehicles/gas), clamps.
- **Bulkheads:** Bulkhead fittings for sheet metal/Dibond.
- **External Outlets:** GOK / Truma gas quick connects with built-in shut-off valves.

## Water System & Body
- **Water:** Food-grade 40-liter water tank (with baffles), 12V galley pump (Seaflo/Shurflo).
- **Tank Protection:** 3 mm aluminum tread plate for underbody protection (skid plate).
- **Filler:** External lockable water filler, drainage/winterization valve.
- **Structure/Walls:** 12-15 mm form plywood (floor), 3-4 mm aluminum composite / Dibond (sides).
- **Galley Modules:** TWO pairs of heavy-duty drawer slides (100-150 kg capacity, lock-in/out): one pair for the front-left kitchen side-drawer, one pair for the rear-right fridge drawer. Plywood for the mid-left storage cabinet and the mid-right electrical bay + exterior door hardware x2 (hinges, compression latches, seals). Energy chains/cable carriers (electrical only — no gas hose in the chains).
- **Appliances:** 12V compressor fridge (e.g., Dometic CFX3 or Engel MR040).

## Road Equipment (Registration Requirements)
- **Lighting:** E-marked LED trailer lighting kit (tail/brake/indicator, number-plate lamp, rear fog), triangular rear reflectors, side/front reflectors, 13-pin connector.
- **Fenders:** Mudguards sized for 265/60R18.
- **Coupling & Safety:** Type-approved coupling head, breakaway cable/safety chain, jockey wheel.
