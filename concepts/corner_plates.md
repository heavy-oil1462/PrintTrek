# Concept: Corner Reinforcements ("Double Sandwich")

**Purpose:** Join the corners of the steel frame in an extremely strong and vibration-resistant way without full welding, preventing crack formation during off-road driving and facilitating hot-dip galvanizing.

## Design Parameters (For PrintNC CAD)
- **Material:** 6082-T6 Aluminum (Thickness: 8-10 mm).
- **Bolt Pattern:** Design a "zig-zag" (offset) pattern for the bolts to prevent weakening along a single line in the steel profile (VKR). Through-bolts M10 or M12 (8.8/10.9).
- **Routing/Bracing:** In addition to the 90-degree profile, integrate mounting points in the plates to secure the flexible conduits in the "cable tunnel" between the upper and lower aluminum plates.
- **Tolerances:** The milling must allow for exact fitment of bolts but also provide microscopic space for isolation film (rubber/vinyl) and marine grease (Duralac) between the steel and aluminum.

## CAD Iteration
1. Model the VKR steel corner and identify distances and potential collisions for bolts (don't forget washers).
2. Create negative space (the tunnel) where pipes and flexible conduits are allowed to exit the steel profile before the 90-degree junction, traveling protected between the plates. Especially important for the sensitive LMR coaxial cable to the 5G antenna which requires a soft bending radius.
3. FEA-simulate the corner (static load and torsional force) if possible, to save weight in the aluminum plates (e.g., by milling pockets where material is redundant).
