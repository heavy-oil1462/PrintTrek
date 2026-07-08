/*
 * Offroad Adventure Trailer - Braked Torsion Axle + Wheels (visual mockup)
 *
 * Braked torsion axle (Knott/AL-KO style), 6x139.7 hubs, trailing arms,
 * and 265/60R18 Falken Wildpeak on Ford Ranger rims.
 *
 * Track width matches the Ford Ranger (1560 mm center-to-center) so the
 * spare wheel is shared and the trailer follows the car's ruts. This is
 * only possible because the frame was narrowed to 1200 mm:
 * tire-to-body clearance = (track - tire_w)/2 - frame_width/2
 *                        = (1560 - 265)/2 - 600 = 47.5 mm.
 */

tube_w = 50;
frame_width = 1200;
frame_length = 2000;

tire_dia = 775;          // 265/60R18: 18*25.4 + 2*0.6*265
tire_w   = 265;
rim_dia  = 457;          // 18 inch
track = 1560;            // Ford Ranger track, center-to-center

axle_tube = 80;          // torsion axle square tube
axle_z = -100;           // axle tube center below frame underside
trail = 90;              // trailing arm: hub sits this far behind the tube
hub_z = -190;            // wheel center below frame underside

$fn = 60;

module wheel() {
    rotate([90, 0, 0]) {
        // Tire
        color([0.13, 0.13, 0.13])
        difference() {
            cylinder(d=tire_dia, h=tire_w, center=true);
            for (s = [-1, 1])
                translate([0, 0, s * tire_w/2])
                    cylinder(d=rim_dia + 40, h=70, center=true);
        }
        // Rim + hub
        color("lightgray") cylinder(d=rim_dia, h=tire_w - 90, center=true);
        color("dimgray")   cylinder(d=150, h=tire_w - 40, center=true);
    }
}

// NOTE: axle_x is the position of the axle TUBE. The trailing arms put
// the hubs (= wheel centers = ground contact) `trail` = 90 mm further
// back. To land the WHEELS on the intended wheel line (AXLE_X in
// scripts/calculate_mass.py), pass wheel_line_x - trail — the assembly
// does. When ordering the real axle, specify the HUB line, not the tube.
module torsion_axle(axle_x = frame_length * 0.6 - trail) {
    y_hub_l = frame_width/2 - track/2;
    y_hub_r = frame_width/2 + track/2;

    // Axle tube between the trailing arms
    color("dimgray")
        translate([axle_x - axle_tube/2, y_hub_l + 60, axle_z - axle_tube/2])
            cube([axle_tube, track - 120, axle_tube]);

    // Mounting brackets up to the frame rails
    color("gray")
        for (y = [0, frame_width - tube_w])
            translate([axle_x - 70, y, axle_z - axle_tube/2])
                cube([140, tube_w, -axle_z + axle_tube/2]);

    // Trailing arms + wheels
    for (y = [y_hub_l, y_hub_r]) {
        color("dimgray")
            hull() {
                translate([axle_x, y, axle_z]) cube([axle_tube, 70, axle_tube], center=true);
                translate([axle_x + trail, y, hub_z]) cube([70, 60, 70], center=true);
            }
        translate([axle_x + trail, y, hub_z]) wheel();
    }
}

// Renders if the file is opened standalone
torsion_axle();
