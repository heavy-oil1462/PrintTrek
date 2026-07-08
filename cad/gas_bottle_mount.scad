/*
 * Offroad Adventure Trailer - Cradle for the Propane Bottle (P6/PK6)
 *
 * This cradle is CNC-milled from 12-15 mm form plywood or thick aluminum
 * plate and mounts on the drawbar, flush against the front wall.
 * Includes recessed slots for heavy-duty straps and a drain hole.
 */

plate_thickness = 12;      // Material thickness
bottle_dia = 300;          // Diameter of a P6 bottle
cradle_margin = 40;        // Extra margin around the bottle
strap_width = 32;          // Width of the strap pass-through
strap_thickness = 6;       // Thickness/height of the strap slot

$fn = 100;

module gas_bottle_cradle() {
    difference() {
        // 1. Main plate (softly rounded rectangle)
        translate([0, 0, plate_thickness/2])
            minkowski() {
                cube([bottle_dia + cradle_margin, bottle_dia + cradle_margin, plate_thickness/2], center=true);
                cylinder(r=20, h=plate_thickness/2, center=true);
            }

        // 2. Recessed groove for the bottle's base ring
        // The P6 bottle has a bottom ring that locates it. A recess
        // makes it sit firmly.
        translate([0, 0, plate_thickness - 5])
            difference() {
                cylinder(d=290, h=10);
                // Keep the center intact
                translate([0, 0, -1]) cylinder(d=270, h=12);
            }

        // 3. Large drain hole in the center (lets dirt and water through)
        translate([0, 0, -1])
            cylinder(d=150, h=plate_thickness + 2);

        // 4. Strap slots (4x around the bottle for cross-lashing)
        for(angle = [0, 90, 180, 270]) {
            rotate([0, 0, angle])
                translate([0, bottle_dia/2 + 10, -1])
                // Slight Z offset to guarantee a through cut
                cube([strap_width, strap_thickness, (plate_thickness + 2) * 2], center=true);
        }

        // 5. Mounting holes (generic slots for U-bolts around round/square drawbar tubes)
        for(x = [-90, 90]) {
            for(y = [-120, 120]) {
                translate([x, y, -1])
                    hull() {
                        translate([0, 15, 0]) cylinder(d=11, h=plate_thickness + 2); // For M10 U-bolt
                        translate([0, -15, 0]) cylinder(d=11, h=plate_thickness + 2);
                    }
            }
        }
    }
}

// Render the cradle
gas_bottle_cradle();

// Visualize the propane bottle (transparent)
%translate([0, 0, plate_thickness]) {
    color("orange", 0.7) {
        // Bottle body
        cylinder(d=300, h=350);
        // Bottle neck
        translate([0, 0, 350]) cylinder(d1=300, d2=100, h=100);
        // Valve/crown guard on top
        translate([0, 0, 450]) cylinder(d=100, h=50);
    }
}
