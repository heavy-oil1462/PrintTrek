# Technical Specifications & Design Decisions

## Overall Goals
- **Tow Vehicle:** Ford Ranger
- **Track Width and Bolt Pattern:** Matched exactly to the tow vehicle (6x139.7). Tire size: 265/60R18 Falken Wildpeak A/T3W on Ford original rims. A common spare wheel is used for both car and trailer.
- **Manufacturing Technique:** Custom-built CNC router (PrintNC) is utilized maximally for precision, corner joints, brackets, niches, and modular panels. Additionally, 3D printed guides will be used to ensure precise drilling of holes in the steel beams. A simplified, non-CNC version with cruder geometry will also be provided for builders without access to CNC routing.

## 1. Chassis & Mechanics
- **Frame Structure:** Square steel (VKR 50x50x3 or 60x40x3 mm). No full welding to prevent fatigue cracks; the frame is bolted together with through-bolts (M10/M12 in 8.8/10.9 grade).
- **Corner Reinforcements:** "Double sandwich" with heavy-duty, CNC-milled 8-10 mm aluminum plates (6082-T6) on the top and bottom of each 90-degree corner.
- **Surface Treatment:** The steel frame is hot-dip galvanized after drilling.
- **Corrosion Protection:** Insulation (vinyl/rubber) and marine grease (Duralac) are strictly used between steel and aluminum.

## 2. Electrical System & Electronics (LEFT Side)
- **Separation:** All electricity (12V, 230V, and network) is routed exclusively in the left side of the frame.
- **Cable Routing:** Cables in corrugated conduits inside the steel frame. The conduits exit the steel before the corners and are routed in a soft curve protected within the tunnel between the corner plates.
- **Grounding:** Single-Point Grounding (Star grounding). The steel frame is equipotentially bonded with a 6 mm² yellow/green cable to a grounding terminal in an IP65 electrical cabinet.
- **230V Network:** Blue CEE inlet -> Fuse box (RCD + 10A/13A circuit breakers) -> Outlets (fridge, Noco charger, IP66 external).
- **12V & Battery Module:** Detachable Power Station box with DC-DC MPPT charger, Noco charger, and Anderson connectors. Charged from the car's 13-pin socket while driving.
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
- **Kitchen Drawer:** Placed on 100-150 kg heavy-duty drawer slides. Equipped with a Dometic 3-way combi fridge. Gas/electricity is fed via a flexible energy chain. CNC-milled ventilation grille in the trailer side.
