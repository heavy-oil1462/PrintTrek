/*
 * Offroad Adventure Trailer - 3D Printed Drill Guide
 *
 * Clamp-on saddle for the VKR 50x50 profiles that positions the plate
 * bolt pattern without a CNC or marking-out. Print in PETG/PLA (100%
 * perimeters around the bushings). Slide onto the tube until the end
 * stop touches the tube end, clamp with a G-clamp, and drill 13 mm
 * through the bushings (holes are reamed after galvanizing anyway).
 *
 * Hole pattern matches the corner-plate arms (corner_plate.scad):
 * 2x M12 on the tube CENTERLINE. Referenced from a crossbeam end the
 * holes sit 30 / 120 mm from the stop; for the RAIL ends (holes 80 /
 * 170 mm from the rail end) insert a 50 mm spacer block between the
 * end stop and the tube. Centered holes = drill straight through both
 * walls with a long bit; no flipping or mirroring needed.
 *
 * Origin: tube end at X=0, tube occupies Y 0..50 with its top face at Z=0.
 */

tube_w = 50;
clr = 0.4;          // print fit clearance around the tube
wall = 4;           // saddle side walls
top_t = 8;          // saddle top plate
side_drop = 35;     // how far the sides reach down the tube
stop_t = 8;         // end stop thickness
bush_h = 12;        // drill bushing height above the top plate
bush_wall = 5;
hole_dia = 13;      // M12 (reamed after galvanizing)
guide_len = 170;

// [distance from tube end, offset from tube centerline]
hole_pattern = [[30, 0], [120, 0]];

module drill_guide() {
    difference() {
        union() {
            // Saddle body + end stop
            translate([-stop_t, -wall - clr, -side_drop])
                cube([guide_len + stop_t, tube_w + 2*(wall + clr), side_drop + clr + top_t]);
            // Drill bushings
            for (h = hole_pattern)
                translate([h[0], tube_w/2 + h[1], clr + top_t])
                    cylinder(d=hole_dia + 2*bush_wall, h=bush_h, $fn=40);
        }

        // Tube channel (with fit clearance)
        translate([0, -clr, -side_drop - 1])
            cube([guide_len + 1, tube_w + 2*clr, side_drop + 1 + clr]);

        // Drill holes through top plate and bushings
        for (h = hole_pattern)
            translate([h[0], tube_w/2 + h[1], -1])
                cylinder(d=hole_dia, h=clr + top_t + bush_h + 2, $fn=40);
    }
}

// Renders if the file is opened standalone (with ghost tube)
color("orange") drill_guide();
%translate([0, 0, -tube_w]) cube([guide_len + 100, tube_w, tube_w]);
