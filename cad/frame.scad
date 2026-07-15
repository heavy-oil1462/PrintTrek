// cad/frame.scad
/*
 * Offroad Adventure Trailer - Chassis / Steel Frame
 *
 * Parametric model of the base frame in 50x50 mm square steel (VKR)
 * with a V-drawbar (A-frame) in the same profile — DEFAULT design.
 * The legacy single central bar (VKR 100x50x4 standing) remains fully
 * modeled behind v_drawbar=false.
 *
 * V-DRAWBAR SIZING (check_v_drawbar in scripts/beam_check.py):
 *   Vertical 3g tongue splits over two arms -> 166 MPa/arm, SF 2.1;
 *   lateral loads resolve AXIALLY through the triangle (6 MPa vs
 *   135 MPa weak-axis bending in the single bar); governing combined
 *   case SF 3.0 vs 1.8 for the single bar. Joints: preload friction
 *   carries everything (check_v_joints) — crossbeam lap is a U-bolt
 *   CLAMP (peak arm moment, no flange holes), rail/apex through-bolted.
 *
 * SINGLE-BAR SIZING (legacy alternative):
 *   100 kg tongue load x 3g dynamic off-road factor x 1.09 m lever
 *   = 3.2 kNm bending moment at the front crossbeam.
 *   VKR 100x50x4 standing: W = 28.8 cm3 -> ~111 MPa vs S355 yield
 *   = safety factor ~3.2 (good fatigue margin).
 *   (A 50x50x3 gave ~390 MPa - above yield - hence the bigger beam.)
 *   Lateral loads: the beam laps under the frame back to the MID
 *   CROSSBEAM (x 950-1000), so the side moment is taken as a force
 *   couple over ~0.95 m instead of at a single joint. NOTE: the beam
 *   must end BEFORE the torsion-axle tube (x ~1070-1150), which crosses
 *   the centerline at the same depth. There is no separate crossbeam
 *   over the axle - the bolted axle tube itself ties the rails there.
 *   Front: angle-bracket clamp (drawbar_angle_joint.scad, no holes in
 *   the flanges). Rear: M12 through-bolt + spacer at the mid crossbeam.
 *
 * Every through-bolt in the frame requires an internal crush sleeve
 * (precision tube, e.g. 16x2.5 mm for M10, 20x3 for M12) so full
 * preload torque can be used without deforming the RHS walls.
 */

tube_w = 50;
frame_length = 2000;
frame_width = 1200;      // Narrowed from 1400: with 265/60R18 on the
                         // Ranger's track (1560 mm), body-to-tire
                         // clearance = (1560-265)/2 - 600 = 47.5 mm.
                         // A 1400 mm frame is geometrically impossible
                         // with a matched track.
plate_t = 10;            // Aluminum plate thickness (corner/wedge/spacer)

// --- Central drawbar (VKR 100x50x4, standing) ---
drawbar_reach = 1000;    // Coupling point distance ahead of the frame
bar_w = 50;              // Beam width (Y)
bar_h = 100;             // Beam height (Z) - standing orientation for max W
// The beam laps under the frame to the mid crossmember (950-1000) and
// ends 50 mm before the torsion-axle tube (front edge x=1070):
drawbar_end_x = 1020;
drawbar_len = drawbar_reach + drawbar_end_x;   // 2020 mm total

// --- V-drawbar (A-frame) — DEFAULT design ---
// Two straight square-cut VKR 50x50x3 arms (same profile as the frame)
// from the coupling apex, attached under the front crossbeam (U-bolt
// clamp — peak arm moment, no flange holes) and the side-rail ends
// (through-bolts). No welds, no miter cuts: the apex is tied by a CNC
// plate top+bottom sandwich (v_apex_plate.scad) and the angled laps
// get wedge spacer plates (drawbar_wedge_plate.scad).
v_attach_x = 600;                          // arm rear ends under the rails
v_arm_dx = v_attach_x + drawbar_reach;     // 1600 mm plan run
v_arm_dy = frame_width/2 - tube_w/2;       // 575 mm half spread
v_arm_len = sqrt(v_arm_dx*v_arm_dx + v_arm_dy*v_arm_dy);   // ~1700 mm
v_theta = atan(v_arm_dy / v_arm_dx);       // ~19.8 deg arm half-angle
// Square-cut tips stop short of each other: v_tip_gap of clear air
// between the two tube corners at the apex, so cut-length tolerance
// never makes the tubes press against each other — the apex plates
// bridge the gap. (Manufacturing/assembly slack, deliberate.)
v_tip_gap = 40;
v_tip_trim = (v_tip_gap/2 + (tube_w/2)/cos(v_theta)) / sin(v_theta);  // ~138 mm

// floor_crossbars: the two OPTIONAL floor crossbars (x 475-525 and
// 1475-1525), OFF by default. FEA-verified frame-neutral — they serve
// the formply floor span, lashing points and the water-tank hanger, so
// the frame is fully valid without them. Enable per-assembly:
//   trailer_frame(floor_crossbars = true)
// v_drawbar: true (DEFAULT design) = the V-drawbar described above;
// false = the legacy single central bar. The assembly passes the value
// from cad/design_params.scad.
module trailer_frame(floor_crossbars = false, v_drawbar = true) {
    color("silver") {
        // Side rails (left and right)
        translate([0, 0, 0]) cube([frame_length, tube_w, tube_w]);
        translate([0, frame_width - tube_w, 0]) cube([frame_length, tube_w, tube_w]);

        // Short sides (front and rear)
        // Recessed between the rails to give clean bolt faces at the corners
        translate([tube_w, tube_w, 0])
            rotate([0, 0, 90]) cube([frame_width - 2*tube_w, tube_w, tube_w]);
        translate([frame_length, tube_w, 0])
            rotate([0, 0, 90]) cube([frame_width - 2*tube_w, tube_w, tube_w]);

        // Mid crossbeam (x 950-1000): takes the drawbar's rear lap bolt
        // AND ties the rails ahead of the axle. No separate beam over
        // the axle: the bolted torsion-axle tube (x 1070-1150) is
        // itself a cross-tie via its rail brackets.
        translate([1000, tube_w, 0])
            rotate([0, 0, 90]) cube([frame_width - 2*tube_w, tube_w, tube_w]);

        // OPTIONAL floor crossbars at ~500 mm spacing (beams at
        // 0/500/975/1500/2000): these carry the 15 mm formply floor
        // (unsupported spans drop from ~950 to ~475 mm under cargo point
        // loads), give lashing/body mounting points, and the rear one
        // doubles as the water-tank hanger (tank zone x 1125-1675).
        // They clear the axle tube. Each end bolts to the rail through
        // a top+bottom T-plate sandwich like the mid crossbeam
        // (see main_assembly.scad).
        if (floor_crossbars) {
            translate([525, tube_w, 0])
                rotate([0, 0, 90]) cube([frame_width - 2*tube_w, tube_w, tube_w]);
            translate([1525, tube_w, 0])
                rotate([0, 0, 90]) cube([frame_width - 2*tube_w, tube_w, tube_w]);
        }

        if (v_drawbar) {
            // V-drawbar arms: straight square-cut VKR 50x50x3 hanging
            // plate_t below the frame plane (wedge plates fill the gap
            // at the front crossbeam and the rail-end laps). The tips
            // stop ~70 mm short of the centerline convergence — the
            // apex V-plate sandwich (main_assembly.scad) ties them.
            for (s = [-1, 1])
                translate([v_attach_x, frame_width/2 + s*v_arm_dy, -(tube_w + plate_t)])
                    rotate([0, 0, atan2(-s*v_arm_dy, -v_arm_dx)])
                        translate([0, -tube_w/2, 0])
                            cube([v_arm_len - v_tip_trim, tube_w, tube_w]);

            // NOTE: no coupling head modeled — how the coupling mounts
            // to the apex is an open design point.
        } else {
            // Central drawbar (VKR 100x50x4, standing): sits plate_t below
            // the frame plane. 10 mm milled spacer plates fill the gap at
            // the front crossbeam (angle clamp) and the mid crossmember
            // (M12 through-bolt + crush sleeves).
            translate([-drawbar_reach, frame_width/2 - bar_w/2, -(bar_h + plate_t)])
                cube([drawbar_len, bar_w, bar_h]);

            // Coupling mock (visual placeholder, level with the beam top)
            translate([-drawbar_reach - 120, frame_width/2 - tube_w/2, -(plate_t + tube_w)])
                cube([120, tube_w, tube_w]);
        }
    }
}

// Renders if the file is opened standalone
trailer_frame();
