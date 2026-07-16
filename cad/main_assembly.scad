/*
 * Offroad Adventure Trailer - MASTER ASSEMBLY
 *
 * This file imports all CNC and CAD models and assembles them
 * into the complete trailer for overview and tolerance analysis.
 *
 * Open this file in OpenSCAD and press F5!
 */

use <frame.scad>
use <cabin.scad>
use <corner_plate.scad>
use <t_plate.scad>
use <electrical_niche.scad>
use <wheel_axle.scad>
use <fender.scad>
use <water_tank.scad>
use <kitchen_drawer.scad>
use <road_equipment.scad>
use <gas_box.scad>
use <battery_box.scad>
use <drawbar_angle_joint.scad>
use <v_apex_plate.scad>
use <drawbar_wedge_plate.scad>
use <fasteners.scad>

// --- System Parameters ---
$fn = 60;
tube_w = 50;
frame_length = 2000;
frame_width = 1200;   // Narrowed from 1400 to allow the Ranger's 1560 mm track

// --- Design toggles (floor_crossbars, v_drawbar, ...) ---
// Single source of truth shared with the Python pipeline — edit THERE:
include <design_params.scad>

// --- Display toggles (view-only, local to this file) ---
show_cabin = true;         // Body/canopy (walls are semi-transparent)
show_running_gear = true;  // Axle, wheels, fenders (LOAD-BEARING — part of the chassis view)
show_equipment = true;     // Tank, kitchen, gas, electrics, lights (ideation-stage layout)
drawer_pullout = 300;      // Kitchen drawer extension for visualization (mm)
// Chassis-only render (the structural truth: frame + drawbar + plates + axle):
//   scripts/render_scad.sh cad/main_assembly.scad chassis.png \
//       -D show_cabin=false -D show_equipment=false

// --- Drawbar geometry (must match frame.scad) ---
// DEFAULT: V-drawbar, two straight 50x50x3 arms to the coupling apex.
// Legacy single bar (v_drawbar=false): VKR 100x50x4 standing on edge,
// lapped back to the mid crossbeam. Sizing math in frame.scad.
drawbar_reach = 1000;
bar_w = 50;      // single-bar width (Y)
bar_h = 100;     // single-bar height (Z)

// --- Axle/wheel geometry (must match wheel_axle.scad) ---
// axle_x = the wheel-center line (AXLE_X in the mass budget). The
// torsion-axle TUBE sits trail=90 mm ahead of it so the trailing-arm
// hubs land exactly here. No frame crossbeam over the axle: the bolted
// axle tube ties the rails; the mid crossbeam (950-1000) is the frame's
// one middle beam.
axle_x = frame_length * 0.6;
trail = 90;
hub_x = axle_x;
hub_z = -190;
track = 1560;   // Ford Ranger track — matched (see wheel_axle.scad)

// --- Plate Configuration ---
corner_plate_type = "rectangular"; // ["l_shape", "rectangular"]
t_plate_type = "rectangular";      // ["t_shape", "rectangular"]

plate_thickness = 10;
corner_arm_length = 200;

// T-plate specific dimensions
t_arm_length_x = 220;
t_arm_length_y = 180;
t_rect_min_x = -130;
t_rect_max_x = 50;
t_rect_min_y = -65;
t_rect_max_y = 65;

// Fastener helpers: one M12 through-bolt (with crush sleeve) in every
// plate hole — ONE bolt size for every plate joint in the frame.
// 2 bolts per arm on the flange centerline (e2 = 1.9*d0; the old M10
// zig-zag sat at the EN 1993-1-8 floor of 1.18*d0). Hole coordinates
// mirror corner_plate.scad / t_plate.scad (rectangular variants) —
// keep in sync if the bolt patterns there change.
corner_plate_holes = [[80, 25], [170, 25], [25, 25],
                      [25, 80], [25, 170]];
t_plate_holes = [[25, 30], [25, -30], [-40, 0], [-100, 0]];

module corner_bolts() {
    for (h = corner_plate_holes)
        translate([h[0], h[1], tube_w + plate_thickness])
            stack_bolt(12, tube_w + 2 * plate_thickness);
}

module t_plate_bolts() {
    for (h = t_plate_holes)
        translate([h[0], h[1], tube_w + plate_thickness])
            stack_bolt(12, tube_w + 2 * plate_thickness);
}

// Helper modules to simplify placement with parameters
module place_corner() {
    corner_plate(
        plate_type = corner_plate_type,
        plate_thickness = plate_thickness,
        tube_width = tube_w,
        arm_length = corner_arm_length
    );
}

module place_t_plate() {
    t_plate(
        plate_type = t_plate_type,
        plate_thickness = plate_thickness,
        tube_width = tube_w,
        arm_length_x = t_arm_length_x,
        arm_length_y = t_arm_length_y,
        rect_min_x = t_rect_min_x,
        rect_max_x = t_rect_max_x,
        rect_min_y = t_rect_min_y,
        rect_max_y = t_rect_max_y
    );
}

// ==========================================
//                 ASSEMBLY
// ==========================================

// 1. Chassis (Steel Frame)
trailer_frame(floor_crossbars = floor_crossbars, v_drawbar = v_drawbar);

// V-drawbar geometry (must match frame.scad). attach at 800 keeps the
// V narrow enough that the crossing clamp bolts clear the 200x200
// front corner plates (see frame.scad).
v_attach_x = 800;
v_arm_dx = v_attach_x + drawbar_reach;   // 1800
v_arm_dy = frame_width/2 - tube_w/2;     // 575
v_theta = atan(v_arm_dy / v_arm_dx);     // ~17.7 deg arm half-angle
// arm-centerline offset from the trailer centerline at the front
// crossbeam centerline (x = tube_w/2): ~327 mm
v_cross_y = v_arm_dy * (drawbar_reach + tube_w/2) / v_arm_dx;
// single rail-lap bolt: this far along the arm from its rear end (the
// shallow-angle overlap parallelogram only has edge distance for ONE bolt)
v_rail_bolt = 30;

// 3. CNC Corner Plates ("Double Sandwiches")
// Front Left Corner
translate([0, 0, tube_w]) place_corner();
translate([0, 0, -plate_thickness]) place_corner(); // Bottom

// Front Right Corner (Rotated inwards)
translate([0, frame_width, tube_w]) rotate([0, 0, -90]) place_corner();
translate([0, frame_width, -plate_thickness]) rotate([0, 0, -90]) place_corner();

// Rear Left Corner
translate([frame_length, 0, tube_w]) rotate([0, 0, 90]) place_corner();
translate([frame_length, 0, -plate_thickness]) rotate([0, 0, 90]) place_corner();

// Rear Right Corner
translate([frame_length, frame_width, tube_w]) rotate([0, 0, 180]) place_corner();
translate([frame_length, frame_width, -plate_thickness]) rotate([0, 0, 180]) place_corner();

// 3.5 Drawbar lap joints (structural — part of the chassis view)
if (!v_drawbar) {
    // FRONT crossbeam: angle-bracket clamp (2x L80x80x8 + spacer plate,
    // see drawbar_angle_joint.scad) — NO holes in the beam flanges at the
    // peak-moment point; web bolts at the neutral axis. Fatigue rationale
    // in scripts/beam_check.py (check_joint_hole / check_angle_joint).
    translate([tube_w/2, frame_width/2, 0]) drawbar_angle_joint();

    // MID crossbeam (x 950-1000): plain through-bolted rear lap + 10 mm
    // spacer (bending moment ~zero here; the through-bolt gives positive
    // longitudinal location). The beam ends at x=1020, short of the
    // torsion-axle tube (x 1070-1150) which crosses at the same depth.
    color("gold")
        translate([950, frame_width/2 - bar_w/2, -plate_thickness])
            cube([tube_w, bar_w, plate_thickness]);
} else {
    // V-DRAWBAR joint hardware (all CNC plates, no welds, no miter cuts):
    // one simple trapezoidal apex plate top+bottom ties the square-cut
    // arm ends; wedge spacer plates fill the 10 mm gap at each angled
    // lap (front-crossbeam crossing + side-rail ends). At the CROSSBEAM
    // crossing the arm is at peak bending moment, so it is CLAMPED
    // without any holes in it: two M12 pass through the crossbeam
    // BESIDE the arm, through spacer sleeves, into a plate under the
    // arm (fatigue rule — see check_v_joints in beam_check.py). One
    // through-bolt per rail end, two per arm at the apex, where arm
    // moment is ~zero. Coupling-head mounting deliberately not modeled
    // yet (open design point).
    color("gold") {
        // Apex sandwich: origin = arm centerline convergence point
        translate([-drawbar_reach, frame_width/2, -plate_thickness])
            v_apex_plate(theta = v_theta);
        translate([-drawbar_reach, frame_width/2, -(tube_w + 2*plate_thickness)])
            v_apex_plate(theta = v_theta);

        for (s = [-1, 1]) {
            // Front-crossbeam crossing (arm centerline ~327 mm off
            // center): plain wedge (no holes — the clamp bolts pass
            // BESIDE the arm, see the fasteners below)
            translate([tube_w/2, frame_width/2 + s * v_cross_y, -plate_thickness])
                rotate([0, 0, 90])
                    drawbar_wedge_plate(angle = 90 + s * v_theta, hole_dia = 0);

            // Clamp plate UNDER the arm at the crossing: the two bolts
            // through the crossbeam pull it up via spacer sleeves and
            // squeeze the arm between it and the wedge/crossbeam
            translate([tube_w/2 - 30, frame_width/2 + s * v_cross_y - 70,
                       -(tube_w + 2 * plate_thickness)])
                cube([60, 140, plate_thickness]);

            // Side-rail lap at the arm's rear end: ONE bolt hole (the
            // shallow-angle overlap only has edge distance for one)
            translate([v_attach_x - v_rail_bolt * cos(v_theta),
                       frame_width/2 + s * (v_arm_dy - v_rail_bolt * sin(v_theta)),
                       -plate_thickness])
                drawbar_wedge_plate(angle = 180 + s * v_theta, hole_spacing = 0);
        }
    }

    // V-drawbar fasteners (display hardware, sizing in check_v_joints):
    for (s = [-1, 1]) {
        // Apex plates: 2x M12 through-bolts per arm through the
        // top plate / tube / bottom plate stack (arm moment ~zero here)
        for (dd = [180, 250])
            translate([-drawbar_reach + dd * cos(v_theta),
                       frame_width/2 + s * dd * sin(v_theta), 0])
                stack_bolt(12, tube_w + 2 * plate_thickness);

        // Rail-end lap: ONE M12 down through rail + wedge + arm (the
        // arm's far support — moment ~zero, the hole is harmless; the
        // 19.8deg overlap parallelogram only fits one bolt anyway)
        translate([v_attach_x - v_rail_bolt * cos(v_theta),
                   frame_width/2 + s * (v_arm_dy - v_rail_bolt * sin(v_theta)),
                   tube_w])
            stack_bolt(12, 2 * tube_w + plate_thickness);

        // Front-crossbeam crossing: CLAMP — 2x M12 through the
        // CROSSBEAM 45 mm each side of the arm, down through 60 mm
        // spacer sleeves into the clamp plate under the arm. NO holes
        // in the arm at its peak-moment point (fatigue rule,
        // check_v_joints), and nothing lands on a beam edge — the
        // bolts have the crossbeam's whole length to sit on. (Square
        // U-bolts do NOT fit here: at the ~70deg crossing their legs
        // land exactly on the crossbeam's edges.)
        for (cs = [-1, 1]) {
            translate([tube_w/2, frame_width/2 + s * v_cross_y + cs * 45, tube_w])
                stack_bolt(12, 2 * tube_w + 2 * plate_thickness);
            color("Silver")
                translate([tube_w/2, frame_width/2 + s * v_cross_y + cs * 45,
                           -(tube_w + plate_thickness)])
                    cylinder(d = 18, h = tube_w + plate_thickness, $fn = 32);
        }
    }
}

// 3.6 T-plates for the mid crossbeam (x 950-1000: drawbar rear lap +
// rail tie ahead of the axle — the one middle beam of the frame)
// Left side
translate([975, tube_w, tube_w]) rotate([0, 0, -90]) place_t_plate();
translate([975, tube_w, -plate_thickness]) rotate([0, 0, -90]) place_t_plate();

// Right side
translate([975, frame_width - tube_w, tube_w]) rotate([0, 0, 90]) place_t_plate();
translate([975, frame_width - tube_w, -plate_thickness]) rotate([0, 0, 90]) place_t_plate();

// 3.7 T-plates for the OPTIONAL floor crossbars (x=500/1500, off by
// default): same top+bottom double sandwich as the mid crossbeam —
// same CNC part, same joint everywhere in the frame.
if (floor_crossbars) {
    for (x = [500, 1500]) {
        translate([x, tube_w, tube_w]) rotate([0, 0, -90]) place_t_plate();
        translate([x, tube_w, -plate_thickness]) rotate([0, 0, -90]) place_t_plate();
        translate([x, frame_width - tube_w, tube_w]) rotate([0, 0, 90]) place_t_plate();
        translate([x, frame_width - tube_w, -plate_thickness]) rotate([0, 0, 90]) place_t_plate();
        translate([x, tube_w, 0]) rotate([0, 0, -90]) t_plate_bolts();
        translate([x, frame_width - tube_w, 0]) rotate([0, 0, 90]) t_plate_bolts();
    }
}

// 3.8 Frame fasteners (display hardware): every plate hole gets its
// M10 through-bolt + crush sleeve, so the mounting is readable
// straight off the model. Same transforms as the plates above.
corner_bolts();                                                    // front left
translate([0, frame_width, 0]) rotate([0, 0, -90]) corner_bolts(); // front right
translate([frame_length, 0, 0]) rotate([0, 0, 90]) corner_bolts(); // rear left
translate([frame_length, frame_width, 0]) rotate([0, 0, 180]) corner_bolts(); // rear right

translate([975, tube_w, 0]) rotate([0, 0, -90]) t_plate_bolts();   // mid crossbeam
translate([975, frame_width - tube_w, 0]) rotate([0, 0, 90]) t_plate_bolts();

// ==========================================
// 4. Body / Canopy
// ==========================================
if (show_cabin) {
    trailer_cabin();

    // Electrical niche recessed in the RIGHT Dibond wall (hole is cut in
    // cabin.scad at x 600-760, z 265-465; wall outer face at y=frame_width+3).
    // All electrical lives on the right side, ahead of the fridge drawer.
    color("darkslategray")
        translate([680, frame_width + 3, 365]) mirror([0, 1, 0])
            rotate([90, 0, 0]) power_niche();
}

// ==========================================
// 5. Running Gear (load-bearing)
// ==========================================
if (show_running_gear) {
    // Braked torsion axle + 265/60R18 wheels (tube ahead, hubs on axle_x)
    torsion_axle(axle_x - trail);

    // Fenders (registration requirement)
    translate([hub_x, frame_width/2 - track/2, hub_z]) fender();
    translate([hub_x, frame_width/2 + track/2, hub_z]) fender();
}

// ==========================================
// 6. Systems & Payload
// ==========================================
if (show_equipment) {
    // Water tank: REMOVED from the assembly for now — mounting/placement
    // is being reworked (the underslung spot must dodge the central
    // drawbar at y 575-625 and the axle tube at x 1070-1150; candidate
    // was [780, 330] offset left). Model kept in cad/water_tank.scad;
    // mass stays as a placeholder in scripts/calculate_mass.py.

    // Caravan-style gas locker box on the drawbar, flush against the
    // front wall (box rear face ~25 mm from the wall). Houses the P6
    // bottle + regulator; low-level vents per EN 1949. Replaces the open
    // cradle + stone guard (gas_bottle_mount.scad kept as alternative).
    // V-drawbar (default): the box bolts onto two 10 mm alu bearer
    // plates spanning the arms — MORE mounting room than the single
    // bar, and still no holes in any drawbar member.
    if (v_drawbar) {
        // Two 10 mm alu bearer plates under the box, spanning the arms:
        // TRAPEZOIDS that follow the V taper, ending flush with the
        // arms' outer edges — no sharp corners overhanging the tubes.
        for (bx = [-380, -80]) {
            w0 = v_arm_dy * (bx - 50 + drawbar_reach) / v_arm_dx
                 + (tube_w/2) / cos(v_theta);   // half-width at the front edge
            w1 = v_arm_dy * (bx + 50 + drawbar_reach) / v_arm_dx
                 + (tube_w/2) / cos(v_theta);   // half-width at the rear edge
            color("gold")
                translate([0, frame_width/2, -plate_thickness])
                    linear_extrude(plate_thickness)
                        polygon([[bx - 50, -w0], [bx + 50, -w1],
                                 [bx + 50,  w1], [bx - 50,  w0]]);
            // one M10 through bearer + arm at each crossing
            for (s = [-1, 1])
                translate([bx, frame_width/2 + s * v_arm_dy * (bx + drawbar_reach) / v_arm_dx, 0])
                    stack_bolt(10, plate_thickness + tube_w);
        }
        translate([-230, frame_width/2, 0]) gas_box(mount = "plate");
    } else {
        // Legacy single-bar mount: bearers + U-straps around the beam
        translate([-230, frame_width/2, -plate_thickness]) gas_box();
    }

    // --- Layout (sides in TRAVEL direction; y=0 is the left wall) ---
    // LEFT,  front -> rear: kitchen side-drawer | storage cabinet (utensils)
    // RIGHT, front -> rear: electrical bay (battery box) | fridge drawer

    // Kitchen side-drawer, front left, slides out -Y through the wall
    translate([60, 0, 65]) kitchen_drawer(pullout = drawer_pullout);

    // Storage cabinet (utensils/dry goods), mid left.
    // Door in the left wall at x 780-1240.
    translate([600, 0, 65]) storage_cabinet();

    // Electrical bay, mid right, AHEAD of the fridge drawer: mirrored
    // cabinet housing the removable power-station box. Door in the right
    // wall at x 780-1240; the el-niche sits in its front bay (x 600-760).
    translate([600, frame_width, 65]) mirror([0, 1, 0]) storage_cabinet();
    translate([920, frame_width - 180, 65 + 15 + 202]) battery_box();

    // Fridge drawer, rear right, slides out +X through the rear hatch
    // (kept 110 mm off the right wall so the tray clears the hatch frame)
    translate([1330, frame_width - 450 - 110, 65]) fridge_drawer(pullout = drawer_pullout);

    // --- External connection points ---
    // 230V CEE inlet: FRONT wall, right half, mounted HIGH — kept well
    // clear (>500 mm) of all gas equipment (bottle low center, connects
    // on the right wall). Interior feed runs in conduit along the front
    // bulkhead to the left-side electrical cabinet.
    color("RoyalBlue") translate([-6, 950, 680]) rotate([0, -90, 0]) {
        cylinder(d = 60, h = 25);
        translate([-45, -45, 0]) cube([90, 90, 4]);
    }

    // Gas quick-connects (GOK/Truma) in recessed niches on the RIGHT
    // wall: one front, one rear. NOTE: gas-vs-electrical side separation
    // is parked while the interior layout settles (2026-07) — these
    // positions will be refined once the layout is frozen.
    color("orange") for (x = [300, 1750])
        translate([x, frame_width + 6, 250]) rotate([90, 0, 0]) {
            cylinder(d = 40, h = 25);
            translate([-40, -40, 0]) cube([80, 80, 4]);
        }

    // Road equipment (UNECE R48): lamps, reflectors, plate, jockey wheel.
    // One row across the 1200 mm rear beam:
    // lamp 30-210 | triangle 220-350 | plate 360-840 | triangle 850-980 | lamp 990-1170
    translate([2003, 30, -25]) rear_lamp();
    translate([2003, frame_width - 210, -25]) rear_lamp();
    translate([2003, 220, -20]) triangle_reflector();
    translate([2003, 850, -20]) triangle_reflector();
    translate([2003, 360, -25]) number_plate();
    // Jockey wheel: V-drawbar -> clamped to the LEFT arm (standard
    // A-frame practice); single bar -> on the centerline beam.
    if (v_drawbar)
        translate([-800, frame_width/2 - v_arm_dy * (-800 + drawbar_reach) / v_arm_dx,
                   -plate_thickness])
            rotate([0, 0, -v_theta]) jockey_wheel();
    else
        translate([-800, frame_width/2, -plate_thickness])
            jockey_wheel();

    // NO spare wheel on the trailer: the wheel spec matches the Ford
    // Ranger exactly (6x139.7, 265/60R18 on original rims), so the
    // car's underslung spare serves both. That IS the shared-spare
    // design goal — and it frees the tailgate for the fridge drawer.
}
