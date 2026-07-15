/*
 * Offroad Adventure Trailer - V-Drawbar Apex Plate
 *
 * 10 mm 6082-T6 aluminum, CNC milled, used as a TOP+BOTTOM SANDWICH.
 * ONE simple trapezoidal plate laid straight over BOTH square-cut arm
 * ends where they converge: the edges just follow the tubes' outer
 * edges, two M12 through-bolts per arm (internal crush sleeves in the
 * tubes, as everywhere in the frame).
 *
 * This plate pair is what makes the V-drawbar both WELD-free and
 * MITER-free: the arms are plain straight VKR 50x50x3 sticks and all
 * of the V geometry lives in this one flat part.
 *
 * The coupling-head mounting is deliberately NOT modeled yet (open
 * design point) — the plate simply stops just ahead of the tube tips.
 *
 * Local origin = the arms' centerline convergence point; the apex
 * points toward -X, symmetric about y=0. The square-cut tube tips sit
 * ~140 mm out from the origin (frame.scad: v_tip_trim), leaving a
 * ~40 mm clear gap between the tubes at the apex — cut-length slack
 * for manufacturing/assembly; the plate pair bridges it.
 *
 * Sizing: check_v_drawbar() in scripts/beam_check.py — bolt bearing
 * governs; the plate itself is lightly loaded.
 */

$fn = 60;

module v_apex_plate(
    tube_w = 50,        // Width of the VKR arms
    plate_t = 10,       // Plate thickness (top and bottom are identical)
    theta = 19.8,       // Arm half-angle, deg (frame.scad: atan(575/1600))
    front_x = 115,      // Front edge (just ahead of the ~140 mm tube tips)
    back_x = 320,       // Rear edge along the centerline
    hole_dia = 13,      // M12 clearance, drilled/reamed after milling
    arm_holes = [180, 250]   // Hole positions along each arm centerline
) {
    // Outer edge of a tube at centerline distance x from the convergence
    function half_w(x) = x * tan(theta) + (tube_w / 2) / cos(theta);

    difference() {
        linear_extrude(plate_t)
            polygon([
                [front_x, -half_w(front_x)],
                [back_x,  -half_w(back_x)],
                [back_x,   half_w(back_x)],
                [front_x,  half_w(front_x)]
            ]);
        // Two bolts per arm, on the arm centerlines
        for (s = [-1, 1], d = arm_holes)
            rotate([0, 0, s * theta])
                translate([d, 0, -1])
                    cylinder(d = hole_dia, h = plate_t + 2);
    }
}

// Renders if the file is opened standalone
v_apex_plate();
