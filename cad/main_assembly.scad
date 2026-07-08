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

// --- System Parameters ---
$fn = 60;
tube_w = 50;
frame_length = 2000;
frame_width = 1200;   // Narrowed from 1400 to allow the Ranger's 1560 mm track

// --- Display toggles ---
show_cabin = true;        // Body/canopy (walls are semi-transparent)
show_equipment = true;    // Wheels, tank, kitchen, gas, electrics, lights
drawer_pullout = 300;     // Kitchen drawer extension for visualization (mm)

// --- Drawbar geometry (must match frame.scad) ---
// Single central beam, VKR 100x50x4 standing on edge, lapped under the
// frame back to the axle crossbeam. Sizing math in frame.scad.
drawbar_reach = 1000;
bar_w = 50;
bar_h = 100;

// --- Axle/wheel geometry (must match wheel_axle.scad) ---
axle_x = frame_length * 0.6;
hub_x = axle_x + 90;
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

// 3.5 Drawbar spacer plates
// The central drawbar bolts UNDER the front crossbeam and the axle
// crossbeam (see frame.scad); 10 mm milled plates fill the gap at both
// lap joints. (drawbar_wedge_plate.scad remains in the repo for the
// V-drawbar alternative.)
color("gold") {
    translate([0, frame_width/2 - bar_w/2, -plate_thickness])
        cube([tube_w, bar_w, plate_thickness]);
    translate([frame_length*0.6, frame_width/2 - bar_w/2, -plate_thickness])
        cube([tube_w, bar_w, plate_thickness]);
}

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

    // Electrical niche recessed in the left Dibond wall (hole is cut in
    // cabin.scad at x 600-760, z 265-465; wall outer face at y=-3)
    color("darkslategray")
        translate([680, -3, 365]) rotate([90, 0, 0]) power_niche();
}

// ==========================================
// 5. Running Gear
// ==========================================
if (show_equipment) {
    // Braked torsion axle + 265/60R18 wheels
    torsion_axle(axle_x);

    // Fenders (registration requirement)
    translate([hub_x, frame_width/2 - track/2, hub_z]) fender();
    translate([hub_x, frame_width/2 + track/2, hub_z]) fender();
}

// ==========================================
// 6. Systems & Payload
// ==========================================
if (show_equipment) {
    // Water tank + skid plate, centered just ahead of the axle
    translate([950, frame_width/2, 0]) water_tank_assembly();

    // Gas bottle cradle on the drawbar arms (bottle shown transparent)
    translate([-550, frame_width/2, -plate_thickness]) gas_bottle_cradle();
    %translate([-550, frame_width/2, 2]) color("orange", 0.6) {
        cylinder(d=300, h=350);
        translate([0, 0, 350]) cylinder(d1=300, d2=100, h=100);
    }

    // Removable power station box, left front inside the cabin
    translate([450, 180, 65 + 202]) battery_box();

    // Slide-out kitchen at the rear (drawn partially extended)
    translate([1150, (frame_width - 900)/2, 170]) kitchen_drawer(pullout = drawer_pullout);

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
}
