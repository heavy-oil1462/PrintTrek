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
use <gas_bottle_mount.scad>
use <battery_box.scad>
use <drawbar_angle_joint.scad>

// --- System Parameters ---
$fn = 60;
tube_w = 50;
frame_length = 2000;
frame_width = 1200;   // Narrowed from 1400 to allow the Ranger's 1560 mm track

// --- Display toggles ---
show_cabin = true;         // Body/canopy (walls are semi-transparent)
show_running_gear = true;  // Axle, wheels, fenders (LOAD-BEARING — part of the chassis view)
show_equipment = true;     // Tank, kitchen, gas, electrics, lights (ideation-stage layout)
drawer_pullout = 300;      // Kitchen drawer extension for visualization (mm)
// Chassis-only render (the structural truth: frame + drawbar + plates + axle):
//   scripts/render_scad.sh cad/main_assembly.scad chassis.png \
//       -D show_cabin=false -D show_equipment=false

// --- Drawbar geometry (must match frame.scad) ---
// Single central beam, VKR 100x50x4 standing on edge, lapped under the
// frame back to the axle crossbeam. Sizing math in frame.scad.
drawbar_reach = 1000;
bar_w = 50;
bar_h = 100;

// --- Axle/wheel geometry (must match wheel_axle.scad) ---
// axle_x = the axle crossbeam AND the wheel-center line (AXLE_X in the
// mass budget). The torsion-axle TUBE sits trail=90 mm ahead of it so
// the trailing-arm hubs land exactly here.
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
trailer_frame();

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
// FRONT crossbeam: angle-bracket clamp (2x L80x80x8 + spacer plate,
// see drawbar_angle_joint.scad) — NO holes in the beam flanges at the
// peak-moment point; web bolts at the neutral axis. Fatigue rationale
// in scripts/beam_check.py (check_joint_hole / check_angle_joint).
translate([tube_w/2, frame_width/2, 0]) drawbar_angle_joint();

// AXLE crossbeam: plain through-bolted lap + 10 mm spacer (bending
// moment ~zero here; the through-bolt gives positive longitudinal
// location). drawbar_wedge_plate.scad remains for the V-drawbar
// alternative.
color("gold")
    translate([frame_length*0.6, frame_width/2 - bar_w/2, -plate_thickness])
        cube([tube_w, bar_w, plate_thickness]);

// 3.6 T-plates for Center Beam (Torsion Axle)
// Left side
translate([frame_length*0.6 - tube_w/2, tube_w, tube_w]) rotate([0, 0, -90]) place_t_plate();
translate([frame_length*0.6 - tube_w/2, tube_w, -plate_thickness]) rotate([0, 0, -90]) place_t_plate();

// Right side
translate([frame_length*0.6 - tube_w/2, frame_width - tube_w, tube_w]) rotate([0, 0, 90]) place_t_plate();
translate([frame_length*0.6 - tube_w/2, frame_width - tube_w, -plate_thickness]) rotate([0, 0, 90]) place_t_plate();

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
    // Water tank + skid plate, just ahead of the axle TUBE and offset
    // LEFT of the central drawbar (the beam occupies y 575-625 under the
    // frame — a centered tank would be impaled by it). The left offset
    // also counterbalances the right-side galley mass (battery + fridge).
    translate([780, 330, 0]) water_tank_assembly();   // 20 mm gap to the drawbar

    // Gas bottle cradle on the drawbar, FLUSH against the front wall
    // (bottle edge ~45 mm from the wall; the stone guard wraps the front)
    translate([-210, frame_width/2, -plate_thickness]) gas_bottle_cradle();
    %translate([-210, frame_width/2, 2]) color("orange", 0.6) {
        cylinder(d=300, h=350);
        translate([0, 0, 350]) cylinder(d1=300, d2=100, h=100);
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
    // Jockey wheel clamped to the drawbar
    translate([-800, frame_width/2, -plate_thickness])
        jockey_wheel();

    // Spare wheel on the LEFT half of the tailgate (swings with the
    // hatch). It cannot sit centered — the fridge drawer exits through
    // the rear right. Alternative if hatch hinges can't take 32 kg:
    // roof rack, forward of the tent.
    translate([2003 + 265/2, 390, 420]) rotate([0, 0, 90]) wheel();
}
