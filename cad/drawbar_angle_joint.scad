/*
 * Offroad Adventure Trailer - Drawbar Joint, ANGLE-BRACKET variant
 *
 * Budget alternative to the milled cradle (cad/drawbar_cradle.scad):
 * two hot-rolled steel angles L80x80x8 (S355), 120 mm long, flanking the
 * drawbar at the front crossbeam. Straight cuts only, hot-dip galvanized
 * with the frame, a few euro of material — and it keeps BOTH structural
 * tricks of the cradle:
 *   - NO holes in the beam flanges at peak moment (the fatigue killer,
 *     see check_joint_hole / check_angle_joint in scripts/beam_check.py)
 *   - horizontal M12 bolts through the beam WEBS at the NEUTRAL AXIS,
 *     passing through BOTH angles -> they act as a coupled pair
 *   - vertical M10 through each horizontal leg + crossbeam (crush sleeve)
 *
 * The 10 mm spacer plate between beam top and crossbeam bottom stays
 * (it carries the vertical compression; the angles clamp and locate).
 * Sizing: 8 mm legs -> leg-bending SF ~3.4 with the pair sharing the
 * lateral couple (6 mm legs drop to ~1.9 — not worth the saving).
 *
 * Origin: center of the crossbeam contact face, like drawbar_cradle.scad.
 */

bar_w = 50;
bar_h = 100;
tube_w = 50;
spacer_t = 10;
leg = 80;          // angle leg length
t = 8;             // angle thickness
ang_len = 120;     // along the drawbar (X)
d_m10 = 11;
d_m12 = 13;

$fn = 48;

// Modeled directly in installed orientation for the +Y side:
// corner line at (y=0, z=0) = beam side / crossbeam underside;
// horizontal leg outward (+Y) under the crossbeam, vertical leg DOWN
// against the beam web. The -Y side is a mirror.
module angle_bracket() {
    difference() {
        union() {
            translate([0, 0, -t])   cube([ang_len, leg, t]);   // horizontal leg
            translate([0, 0, -leg]) cube([ang_len, t, leg]);   // vertical leg
        }
        // Vertical M10 through the horizontal leg (into the crossbeam,
        // crush sleeve — sits beside the beam)
        translate([ang_len/2, 65, -t - 1]) cylinder(d = d_m10, h = t + 2);
        // Horizontal M12 x2 through the vertical leg at the beam's
        // NEUTRAL AXIS (z = -60: beam top -10, half height 50)
        for (x = [ang_len/2 - 35, ang_len/2 + 35])
            translate([x, -1, -60]) rotate([-90, 0, 0])
                cylinder(d = d_m12, h = t + 2);
    }
}

// --- assembled joint (module so main_assembly.scad can place it) ------
// Origin: center of the crossbeam contact face, z=0 at crossbeam
// underside, drawbar hanging below in -Z, beam axis along X.
module drawbar_angle_joint() {
    color("SteelBlue") {
        translate([-ang_len/2, bar_w/2, 0]) angle_bracket();               // right
        mirror([0, 1, 0]) translate([-ang_len/2, bar_w/2, 0]) angle_bracket(); // left
    }
    // Spacer plate (still needed: carries vertical compression)
    color("gold") translate([-tube_w/2, -bar_w/2, -spacer_t])
        cube([tube_w, bar_w, spacer_t]);
}

drawbar_angle_joint();

// Ghost context when opened standalone: drawbar below, crossbeam above
%color("gray", 0.4) translate([-200, -bar_w/2, -spacer_t - bar_h])
    cube([400, bar_w, bar_h]);
%color("gray", 0.4) translate([-tube_w/2, -160, 0])
    cube([tube_w, 320, tube_w]);
