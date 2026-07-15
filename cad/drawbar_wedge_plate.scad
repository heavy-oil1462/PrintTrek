/*
 * Offroad Adventure Trailer - Drawbar Wedge/Spacer Plate
 *
 * 10 mm 6082-T6 aluminum, CNC milled. Fills the plate_t gap between the
 * top of a V-drawbar arm and the underside of the beam it bolts to
 * (side rail or front crossbeam), and spreads the clamping load over
 * the angled lap joint.
 *
 * Shape = the plan-view intersection of the two 50 mm wide tubes:
 * a parallelogram. Two M10 through-bolts along the arm centerline
 * (with internal crush sleeves in both tubes, as everywhere else).
 */

$fn = 60;

module drawbar_wedge_plate(
    tube_w = 50,        // Width of both crossing VKR profiles
    plate_t = 10,       // Plate thickness = gap between arm and beam
    angle = 157.13,     // Angle of the arm relative to the beam (deg).
                        // Default matches frame.scad: atan2(675, -1600).
    hole_dia = 11,      // M10, drilled before galvanizing, reamed after
    hole_spacing = 70,  // Bolt spacing along the arm centerline
    max_len = 120       // Trim the parallelogram's needle tips (millable part)
) {
    difference() {
        // Parallelogram: beam strip (along X) intersected with arm strip,
        // tips trimmed to max_len along the arm direction
        intersection() {
            translate([-300, -tube_w/2, 0])
                cube([600, tube_w, plate_t]);
            rotate([0, 0, angle])
                translate([-300, -tube_w/2, 0])
                    cube([600, tube_w, plate_t]);
            rotate([0, 0, angle])
                translate([-max_len/2, -tube_w - 20, 0])
                    cube([max_len, 2*tube_w + 40, plate_t]);
        }

        // Bolt holes along the arm centerline (hole_dia=0 -> plain
        // wedge, e.g. under the clamped front-crossbeam crossing;
        // hole_spacing=0 -> one central hole)
        if (hole_dia > 0)
            for (s = [-1, 1])
                rotate([0, 0, angle])
                    translate([s * hole_spacing/2, 0, -1])
                        cylinder(d=hole_dia, h=plate_t + 2);
    }
}

// Renders if the file is opened standalone
drawbar_wedge_plate();
