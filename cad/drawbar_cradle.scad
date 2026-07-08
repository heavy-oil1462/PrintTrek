/*
 * Offroad Adventure Trailer - Drawbar Cradle (CNC-milled 6082-T6)
 *
 * WHY (see scripts/beam_check.py, check_joint_hole): the weak point of the
 * bolted drawbar is not the beam — it is the 13 mm bolt hole through the
 * tension flange at the FRONT crossbeam, exactly where the bending moment
 * peaks (net-section fatigue margin only ~1.3x vs 3-4x everywhere else).
 *
 * THE FIX: don't pierce the flanges at the peak-moment joint. This milled
 * aluminum cradle replaces the flat spacer plate:
 *   - The WEB (10 mm, same as the old spacer) transfers vertical load
 *     between beam top flange and crossbeam bottom face over a full
 *     120 x 80 mm footprint.
 *   - Two VERTICAL M10 bolts pass BESIDE the beam (through web wings +
 *     crossbeam with crush sleeves) — zero holes in the beam flanges.
 *   - Two CHEEKS grip the beam sides; two HORIZONTAL M12 bolts pass
 *     through cheeks + beam webs at MID-HEIGHT = the neutral axis, where
 *     bending stress is ~zero. Holes there cost nothing in fatigue.
 *   - Tolerance-friendly: the channel has `fit_clr` play, the beam can
 *     sit anywhere along its length (nothing references the beam's end
 *     cuts), and the horizontal holes are match-drilled at assembly.
 *
 * Use at the front crossbeam (peak moment). The axle-crossbeam lap keeps
 * plain through-bolts + spacer plate (moment there is far smaller and a
 * positive location point is wanted).
 *
 * Origin: center of the crossbeam contact face (top of web), Z down = beam.
 */

bar_w = 50;        // drawbar width  (VKR 100x50x4 standing)
bar_h = 100;       // drawbar height
tube_w = 50;       // crossbeam width (VKR 50x50x3)
web_t = 10;        // web thickness = old spacer plate thickness
cheek_t = 15;      // side cheek thickness
cheek_drop = 62;   // cheeks reach past mid-height of the beam
block_len = 120;   // along the drawbar (X)
fit_clr = 0.5;     // channel clearance per side — mm of "playroom"
d_m10 = 11;        // vertical bolts (beside the beam, into the crossbeam)
d_m12 = 13;        // horizontal bolts (through the beam webs, neutral axis)

wing_w = 32;       // web wings extending PAST the cheeks (nut/washer space
                   // for the vertical bolts — they must clear the cheeks)

block_w = bar_w + 2*fit_clr + 2*cheek_t;   // width across cheeks
web_w   = block_w + 2*wing_w;              // full web width incl. wings

$fn = 48;

module drawbar_cradle() {
    color("LightSteelBlue")
    difference() {
        union() {
            // Web (spacer layer between crossbeam and beam top), with
            // wings sticking out past the cheeks on both sides
            translate([-block_len/2, -web_w/2, -web_t])
                cube([block_len, web_w, web_t]);
            // Cheeks flanking the beam
            for (s = [-1, 1])
                translate([-block_len/2,
                           s*(bar_w/2 + fit_clr) + (s < 0 ? -cheek_t : 0),
                           -web_t - cheek_drop])
                    cube([block_len, cheek_t, cheek_drop]);
        }
        // Vertical M10 holes in the WINGS (clear of both beam and cheeks;
        // bolt runs up through the crossbeam with a crush sleeve)
        for (s = [-1, 1])
            translate([0, s*(block_w/2 + wing_w/2), -web_t - 1])
                cylinder(d = d_m10, h = web_t + 2);
        // Horizontal M12 holes at the beam's NEUTRAL AXIS (z = -web_t - bar_h/2)
        for (x = [-35, 35])
            translate([x, -block_w/2 - 1, -web_t - bar_h/2])
                rotate([-90, 0, 0])
                    cylinder(d = d_m12, h = block_w + 2);
        // Chamfer the cheek bottom edges (snag protection)
        for (s = [-1, 1])
            translate([-block_len/2 - 1,
                       s*(bar_w/2 + fit_clr + cheek_t) + (s < 0 ? 8 : -8),
                       -web_t - cheek_drop])
                rotate([s < 0 ? -45 : 225, 0, 0])
                    cube([block_len + 2, 14, 14]);
    }
}

drawbar_cradle();

// Ghost context: drawbar below, crossbeam above
%color("gray", 0.4) translate([-200, -bar_w/2, -web_t - bar_h])
    cube([400, bar_w, bar_h]);
%color("gray", 0.4) translate([-tube_w/2, -160, 0])
    cube([tube_w, 320, tube_w]);
