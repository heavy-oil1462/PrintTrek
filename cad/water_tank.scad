/*
 * Offroad Adventure Trailer - Water Tank + Skid Plate
 *
 * 40 L food-grade tank (550x450x160 = 39.6 L gross, baffled), slung under
 * the frame just ahead of the axle. Two steel straps carry the tank;
 * a 3 mm aluminum tread skid plate with a beveled leading edge protects
 * it from rocks and stumps.
 *
 * LOW-PROFILE ON PURPOSE: with the frame underside ~577 mm above ground,
 * a 220 mm-deep tank hung down to ~336 mm clearance and was the lowest
 * point of the whole trailer. At 160 mm depth the skid plate sits at
 * ~405 mm — roughly level with the axle tube (~437 mm), so the chassis
 * line stays clean and the wheels/axle meet obstacles first.
 *
 * Origin = center of the tank footprint, Z=0 at the frame underside
 * (tank hangs in -Z).
 */

tank_l = 550;      // along X (travel direction)
tank_w = 450;      // along Y
tank_h = 160;      // shallow: protection > packaging (see note above)
skid_t = 3;
skid_margin = 30;  // skid plate extends past the tank
strap_w = 30;

$fn = 60;

module water_tank_assembly() {
    // Tank
    color("SteelBlue", 0.9)
        translate([-tank_l/2, -tank_w/2, -tank_h])
            cube([tank_l, tank_w, tank_h]);

    // Filler neck (up toward the external filler in the wall)
    color("SteelBlue")
        translate([-tank_l/2 + 60, tank_w/2 - 60, -10])
            cylinder(d=50, h=12);

    // Drain valve at the low point (winterization requirement)
    color("goldenrod")
        translate([tank_l/2 - 50, 0, -tank_h - 20])
            cylinder(d=20, h=25);

    // Two carrying straps (rectangular rings around tank + skid)
    color("dimgray")
        for (x = [-tank_l/4, tank_l/4])
            translate([x, 0, -tank_h/2])
                difference() {
                    cube([strap_w, tank_w + 16, tank_h + 16], center=true);
                    cube([strap_w + 2, tank_w, tank_h], center=true);
                }

    // Skid plate (3 mm aluminum tread)
    color("silver") {
        translate([-tank_l/2 - skid_margin, -tank_w/2 - skid_margin, -tank_h - 8 - skid_t])
            cube([tank_l + 2*skid_margin, tank_w + 2*skid_margin, skid_t]);
        // Beveled leading edge (deflects rocks, ~45 degrees up toward the front)
        translate([-tank_l/2 - skid_margin, -tank_w/2 - skid_margin, -tank_h - 8])
            rotate([0, -135, 0])
                cube([90, tank_w + 2*skid_margin, skid_t]);
    }
}

// Renders if the file is opened standalone
water_tank_assembly();
