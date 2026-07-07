# Technical Specifications & Design Decisions

## Overall Goals
- **Tow Vehicle:** Ford Ranger
- **Track Width and Bolt Pattern:** Matched exactly to the tow vehicle (6x139.7). Tire size: 265/60R18 Falken Wildpeak A/T3W on Ford original rims. A common spare wheel is used for both car and trailer.
- **Manufacturing Technique:** Custom-built CNC router (PrintNC) is utilized maximally for precision, corner joints, brackets, niches, and modular panels. Additionally, 3D printed guides will be used to ensure precise drilling of holes in the steel beams. A simplified, non-CNC version with cruder geometry will also be provided for builders without access to CNC routing.

## 1. Chassis & Mechanics
- **Frame Structure:** Square steel (VKR 50x50x3 or 60x40x3 mm), frame 2000 x **1200 mm**. The frame was narrowed from 1400 mm because matching the Ranger's 1560 mm track is otherwise geometrically impossible: with 265 mm tires, tire-to-body clearance is (1560-265)/2 - 600 = **47.5 mm** at 1200 mm width, but negative at 1400 mm. No full welding to prevent fatigue cracks; the frame is bolted together with through-bolts (M10/M12 in 8.8/10.9 grade).
- **Bolted Joints (critical):** Every through-bolt runs through an **internal steel crush sleeve** (precision tube, e.g., 16x2.5 mm for M10) so the bolt can be torqued to full preload without collapsing the 3 mm RHS walls. Lock nuts and hardened washers throughout. **Re-torque all structural bolts after the first ~500 km, then annually.**
- **Drawbar:** V-shaped A-frame in the same VKR profile — two straight arms from the coupling, through-bolted under the front crossbeam and the side rails (10 mm CNC-milled wedge/spacer plates at the angled interfaces). A single central beam is *not* sufficient: with ~100 kg tongue weight and a 3g off-road dynamic factor, the bending stress in a cantilevered 50x50x3 beam exceeds yield. The coupling itself must be a type-approved unit with a documented rating.
- **Corner Reinforcements:** "Double sandwich" with heavy-duty, CNC-milled 8-10 mm aluminum plates (6082-T6) on the top and bottom of each 90-degree corner.
- **Surface Treatment:** The steel frame is hot-dip galvanized after drilling. Holes are drilled 11 mm (M10) / 13 mm (M12) and **reamed clean after galvanizing** — hot-dip adds ~100 µm of zinc per surface.
- **Corrosion Protection:** Duralac (anodic paste) on all steel–aluminum interfaces; optionally a thin *rigid* isolator sheet (0.5-1 mm G10/FR4). **No rubber or vinyl inside structural joints** — elastomers creep under sustained compression and destroy bolt preload, which is the exact loosening/fatigue failure mode the bolted design must avoid. Note that galvanized steel against aluminum is a relatively benign pairing (zinc is anodic to aluminum), so paste + galvanizing is sufficient protection.
- **Suspension:** Torsion (rubber) axles have limited travel (~70 mm) and no damping — on washboard/corrugated roads they overheat and pound the payload. Specify **shock absorbers (damper kit)** with the torsion axle as a minimum; evaluate axle-less trailing-arm setups (e.g., Timbren) if serious off-road use is intended.

## 2. Electrical System & Electronics (LEFT Side)
- **Separation:** All electricity (12V, 230V, and network) is routed exclusively in the left side of the frame.
- **Cable Routing:** Cables in corrugated conduits inside the steel frame. The conduits exit the steel before the corners and are routed in a soft curve protected within the tunnel between the corner plates.
- **Grounding:** Single-Point Grounding (Star grounding). The steel frame is equipotentially bonded with a 6 mm² yellow/green cable to a grounding terminal in an IP65 electrical cabinet.
- **230V Network:** Blue CEE inlet -> Fuse box (RCD + 10A/13A circuit breakers) -> Outlets (fridge, Noco charger, IP66 external).
- **12V & Battery Module:** Detachable Power Station box with a **200 Ah LiFePO4** bank, DC-DC MPPT charger, Noco charger, and Anderson connectors. Charged from the car's 13-pin socket while driving and from a **200 W solar panel** on the roof rack (MC4 via the external solar input).
- **Energy Budget (12V):** Maintained in `scripts/calculate_energy.py` — edit the load table there and re-run as components are chosen. Current estimates: ~64 Ah/day total (compressor fridge ~34, router/RPi/lights/pump ~30). Autonomy with 200 Ah + 200 W solar: **~32 days parked in summer sun, ~5 days in shade/shoulder season, ~3.4 days overcast**; one day's consumption is recovered by ~2 h of driving (30 A DC-DC). The comparison in the script also shows why the gas absorption fridge was rejected: without solar even *it* is battery-limited to ~3 days by the base loads, so solar is required either way — and a compressor fridge with solar then beats gas on every axis (works off-level, no flame under the roof tent, no flue, slide-out compatible).
- **Network:** Teltonika 5G industrial router, coaxial LMR-200/400 to Poynting puck antenna. Waterproof N-connectors in a CNC-milled, recessed panel.

## 3. Propane System (RIGHT Side)
- **Separation:** All propane on the right side for complete isolation from the electrical system.
- **Tank:** 6 kg (P6/PK6) externally on the drawbar in a CNC-milled cradle. Stone protection in bent aluminum tread plate.
- **Routing:** Fixed, clamped copper or steel pipes under the right frame. Bulkhead fittings at consumers.
- **External Outlets:** Two fixed gas quick connects (GOK/Truma) mounted in CNC-milled protective niches on the right side.

## 4. Water System & Interior
- **Water Tank:** 40-liter tank (food-grade with baffles) centrally mounted low over the axle. Protected by a 3 mm aluminum tread skid plate.
- **Water Components:** External lockable filler (in Dibond wall), 12V pressure-controlled galley pump (Seaflo/Shurflo), central drain valve.
- **Body:** Floor in 12-15 mm vehicle plywood (formply). Sides in 3-4 mm Dibond on steel/aluminum framework.
- **Kitchen Drawer:** Placed on 100-150 kg heavy-duty drawer slides. Equipped with a **12V compressor fridge** (e.g., Dometic CFX or Engel). A compressor fridge works off-level, has no flame/flue, and integrates with the CAN-controlled fridge relay — a 3-way absorption fridge was rejected: it must be near-level to run, needs a fixed flue and ventilation on gas (EN 1949), and an open-flame appliance on a moving drawer would be very hard to get approved. **The energy chain to the drawer carries electrical only** — propane stays on fixed pipes to the external quick-connects (right side), preserving the gas/electric separation principle. CNC-milled ventilation grille in the trailer side for the compressor.

## 5. Road Legal & Registration (Sweden)
- **Approval:** An amateur-built trailer requires *registreringsbesiktning* (individual approval) before road use. Contact the inspection body (Besikta/Opus/Dekra) early — their requirements drive design decisions.
- **Weight class (DECIDED):** The trailer will be **braked** (overrun/auflauf brakes — braked torsion axles with 6x139.7 hubs exist from Knott/AL-KO). This permits registering a total weight above 750 kg, giving real payload margin — the current curb-weight estimate (~585 kg) leaves almost nothing under an unbraked 750 kg rating. The running weight and tongue-load budget is maintained in `scripts/calculate_mass.py`.
- **Tongue load:** Target roughly 5-10% of total weight, and within the Ford Ranger towbar's rated ball load.
- **Lighting & marking:** Full lighting per UNECE R48 (tail/brake/indicators, number-plate lamp, rear fog, reversing light where required), triangular rear reflectors (trailer-specific), side/front reflectors. E-marked components only.
- **Mudguards/fenders:** Required — not yet in the CAD model.
- **Coupling & safety:** Type-approved coupling head matched to the Ranger's ball height, plus breakaway cable (or safety chain for unbraked class) and jockey wheel.
