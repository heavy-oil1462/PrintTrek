/*
 * Offroad Adventure Trailer - Drawbar Gas Locker Box (caravan style)
 *
 * Replaces the open cradle + bent stone guard: a lockable, weatherproof
 * box on the drawbar housing the P6/PK6 bottle + regulator, flush
 * against the front wall. Off-the-shelf poly "gasolbox"/drawbar boxes
 * exist in this size class (Fiamma/Thule/generic) — or CNC-fold one
 * from aluminum tread plate.
 *
 * Key requirements (EN 1949 gas locker):
 *   - LOW-LEVEL VENTILATION: propane is heavier than air — vent slots
 *     at the bottom of both side walls, and the box floor sits on open
 *     bearers so gas can never pool.
 *   - Sealed from the cabin (it is: separate box, outside the body).
 *   - Bottle strapped upright; regulator + hose inside; fixed pipe
 *     exits through the floor gland and runs to the right-side rail.
 *
 * MOUNTING (respects the no-holes-in-the-drawbar rule): two aluminum
 * bearers sit ON the beam and are CLAMPED around it with U-straps —
 * the forward drawbar still carries near-peak bending moment, so it
 * must not be drilled.
 *
 * Origin: center of the drawbar top face under the box center,
 * beam axis along X (like drawbar_angle_joint.scad). Box hangs in +Z.
 */

bar_w = 50;
box_w = 500;       // across the trailer (Y)
box_d = 400;       // along the drawbar (X)
box_h = 620;       // fits a P6 (495 mm incl. valve) + regulator space
wall_r = 15;       // rounded edges (molded poly look)
lid_h = 140;
bearer_h = 18;
bearer_l = 300;    // bearer length across the beam

$fn = 40;

module rounded_box(size, r) {
    minkowski() {
        translate([r, r, r])
            cube([size[0] - 2*r, size[1] - 2*r, size[2] - 2*r]);
        sphere(r);
    }
}

module gas_box() {
    // Mounting bearers, clamped around the beam with U-straps
    color("Silver") for (x = [-box_d/2 + 50, box_d/2 - 50]) {
        translate([x - 20, -bearer_l/2, 0]) cube([40, bearer_l, bearer_h]);
        // U-strap hint wrapping the beam sides
        for (s = [-1, 1])
            translate([x - 15, s*(bar_w/2 + 4) - 2, -60])
                cube([30, 4, 60 + bearer_h]);
    }

    translate([0, 0, bearer_h]) {
        // Body
        color("Gainsboro")
            difference() {
                translate([-box_d/2, -box_w/2, 0])
                    rounded_box([box_d, box_w, box_h - lid_h + wall_r], wall_r);
                // Trim the top so the lid seam is flat
                translate([-box_d/2 - 1, -box_w/2 - 1, box_h - lid_h])
                    cube([box_d + 2, box_w + 2, lid_h + wall_r + 1]);
                // Low-level vent slots (EN 1949) in both side walls
                for (s = [-1, 1], x = [-120, -40, 40, 120])
                    translate([x - 15, s*(box_w/2) - 10, 25])
                        cube([30, 20, 12]);
            }

        // Lid (front-hinged, shown closed)
        color("WhiteSmoke")
            translate([-box_d/2, -box_w/2, box_h - lid_h])
                rounded_box([box_d, box_w, lid_h], wall_r);

        // Latches on the front face
        color("DimGray") for (y = [-box_w/4, box_w/4])
            translate([-box_d/2 - 6, y - 20, box_h - lid_h - 45])
                cube([10, 40, 60]);

        // Gas pipe gland exiting the floor toward the right-side rail
        color("goldenrod")
            translate([box_d/2 - 60, box_w/2 - 60, -bearer_h - 20])
                cylinder(d = 16, h = 40);
    }

    // Ghost bottle inside
    %color("orange", 0.5) translate([0, -60, bearer_h + 15]) {
        cylinder(d = 300, h = 350);
        translate([0, 0, 350]) cylinder(d1 = 300, d2 = 100, h = 100);
        translate([0, 0, 450]) cylinder(d = 100, h = 50);
    }
}

gas_box();

// Ghost drawbar for context when opened standalone
%color("gray", 0.4) translate([-400, -bar_w/2, -110]) cube([800, bar_w, 100]);
