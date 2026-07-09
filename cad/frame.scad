// cad/frame.scad
/*
 * Offroad Adventure Trailer - Chassis / Steel Frame
 *
 * Parametric model of the base frame in 50x50 mm square steel (VKR)
 * with a central drawbar in VKR 100x50x4 (standing on edge).
 *
 * DRAWBAR SIZING:
 *   100 kg tongue load x 3g dynamic off-road factor x 1.09 m lever
 *   = 3.2 kNm bending moment at the front crossbeam.
 *   VKR 100x50x4 standing: W = 28.8 cm3 -> ~111 MPa vs S355 yield
 *   = safety factor ~3.2 (good fatigue margin).
 *   (A 50x50x3 gave ~390 MPa - above yield - hence the bigger beam.
 *    A V-drawbar is the alternative; see drawbar_wedge_plate.scad + git history.)
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

// floor_crossbars: the two OPTIONAL floor crossbars (x 475-525 and
// 1475-1525). FEA-verified frame-neutral — they serve the formply floor
// span, lashing points and the water-tank hanger, so the frame is fully
// valid without them. Toggle here or per-assembly:
//   trailer_frame(floor_crossbars = false)
module trailer_frame(floor_crossbars = true) {
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
        // a bottom T-plate (see main_assembly.scad).
        if (floor_crossbars) {
            translate([525, tube_w, 0])
                rotate([0, 0, 90]) cube([frame_width - 2*tube_w, tube_w, tube_w]);
            translate([1525, tube_w, 0])
                rotate([0, 0, 90]) cube([frame_width - 2*tube_w, tube_w, tube_w]);
        }

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

// Renders if the file is opened standalone
trailer_frame();
