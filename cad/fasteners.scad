/*
 * Offroad Adventure Trailer - Fastener Display Models
 *
 * Visual bolts, nuts and square U-bolts for the master assembly: they
 * show HOW every joint is mounted (which holes get through-bolts,
 * where the U-bolt clamps sit). Display geometry only — no threads,
 * approximate head/nut sizes. The engineering lives elsewhere:
 * preload/friction budget in scripts/beam_check.py (check_v_joints,
 * check_bolts), quantities in MATERIALS.md. Every through-bolt runs on
 * an internal crush sleeve (not drawn — hidden inside the tube).
 */

// Hex-head through-bolt + washer + nut for a clamped stack:
// head sits on top at z=0, shank passes DOWN through `grip`
// (= the stack thickness), washer+nut below.
module stack_bolt(d = 10, grip = 70) {
    color("SlateGray") {
        cylinder(d = 1.8 * d, h = 0.64 * d, $fn = 6);          // head
        cylinder(d = 2.1 * d, h = 0.16 * d, $fn = 32);         // washer
        translate([0, 0, -grip - d])
            cylinder(d = d, h = grip + d, $fn = 32);           // shank
        translate([0, 0, -grip - 0.8 * d]) {
            cylinder(d = 1.8 * d, h = 0.8 * d, $fn = 6);       // nut
            translate([0, 0, 0.8 * d - 0.16 * d + 0.01])
                cylinder(d = 2.1 * d, h = 0.16 * d, $fn = 32); // washer
        }
    }
}

// Square U-bolt (fyrkantbygel) wrapping a tube that runs along local X:
// bottom bar under the tube at z=drop, legs rise beside the tube up to
// z=rise where the washers+nuts sit (on top of the clamped member).
module square_u_bolt(d = 12, tube_w = 50, clear = 6, drop = -66, rise = 50) {
    w = tube_w / 2 + clear;
    color("SlateGray") {
        for (s = [-1, 1]) {
            translate([0, s * w, drop])
                cylinder(d = d, h = rise - drop + d, $fn = 32);   // leg
            translate([0, s * w, rise]) {
                cylinder(d = 2.1 * d, h = 0.16 * d, $fn = 32);    // washer
                cylinder(d = 1.8 * d, h = 0.8 * d, $fn = 6);      // nut
            }
        }
        translate([0, -w, drop])
            rotate([-90, 0, 0])
                cylinder(d = d, h = 2 * w, $fn = 32);             // bottom bar
    }
}

// Standalone preview
stack_bolt(12, 70);
translate([100, 0, 0]) square_u_bolt();
