# Concept: Corner Reinforcements ("Double Sandwich")

**Purpose:** Join the corners of the steel frame in an extremely strong and vibration-resistant way without full welding, preventing crack formation during off-road driving and facilitating hot-dip galvanizing.

## Design Parameters (For PrintNC CAD)
- **Material:** 6082-T6 Aluminum (Thickness: 8-10 mm).
- **Bolt Pattern:** Design a "zig-zag" (offset) pattern for the bolts to prevent weakening along a single line in the steel profile (VKR). Through-bolts M10 or M12 (8.8/10.9).
- **Crush Sleeves:** Every through-bolt gets an internal steel sleeve (precision tube, e.g., 16x2.5 mm for M10) cut to the inner width of the VKR profile. Without sleeves the 3 mm tube walls collapse before the bolt reaches proper preload, and an under-torqued friction joint loosens under off-road vibration.
- **Routing/Bracing:** In addition to the 90-degree profile, integrate mounting points in the plates to secure the flexible conduits in the "cable tunnel" between the upper and lower aluminum plates.
- **Tolerances:** Holes drilled 11 mm (M10) / 13 mm (M12) and reamed after hot-dip galvanizing (~100 µm zinc per surface). Interface: Duralac paste, optionally a thin *rigid* G10/FR4 isolator sheet. No rubber/vinyl film in the joint — elastomers creep under clamping pressure and the bolt preload decays.

## CAD Iteration
1. Model the VKR steel corner and identify distances and potential collisions for bolts (don't forget washers).
2. Create negative space (the tunnel) where pipes and flexible conduits are allowed to exit the steel profile before the 90-degree junction, traveling protected between the plates. Especially important for the sensitive LMR coaxial cable to the 5G antenna which requires a soft bending radius.
3. FEA-simulate the corner (static load and torsional force) if possible, to save weight in the aluminum plates (e.g., by milling pockets where material is redundant).
