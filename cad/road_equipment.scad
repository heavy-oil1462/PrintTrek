/*
 * Offroad Adventure Trailer - Road Equipment (registration requirements)
 *
 * Visual mockups of the E-marked equipment needed for registreringsbesiktning:
 * rear lamp clusters, triangular rear reflectors (trailer-specific),
 * number plate, and the jockey wheel on the drawbar.
 * Lighting positions must satisfy UNECE R48 mounting heights/spacings.
 */

$fn = 60;

// Rear lamp cluster (tail/brake/indicator/fog). Origin = mounting face,
// body extends +X (rearward), lens area in YZ.
module rear_lamp() {
    color([0.5, 0, 0]) cube([25, 180, 90]);
    color("red")       translate([25, 10, 10]) cube([4, 70, 70]);
    color("orange")    translate([25, 100, 10]) cube([4, 70, 70]);
}

// Triangular rear reflector (mandatory on trailers). Lies in the YZ plane.
module triangle_reflector() {
    color("red")
        rotate([90, 0, 90])
            linear_extrude(8)
                polygon([[0, 0], [130, 0], [65, 110]]);
}

// Number plate holder with illumination
module number_plate() {
    color("white") cube([5, 480, 110]);
}

// Jockey wheel, clamped to a drawbar arm. Origin = top of the arm (Z=0),
// post and wheel extend downward. Stowed height keeps ~100 mm ground clearance.
module jockey_wheel() {
    color("silver") {
        // Clamp around the 50x50 arm
        translate([-35, -35, -60]) cube([70, 70, 60]);
        // Post
        translate([0, 0, -400]) cylinder(d=48, h=410);
        // Crank handle
        translate([0, 0, 5]) rotate([0, 90, 0]) cylinder(d=15, h=90);
        translate([90, 0, 5]) cylinder(d=15, h=60, center=true);
    }
    // Wheel
    color([0.2, 0.2, 0.2])
        translate([0, 0, -400])
            rotate([90, 0, 0])
                cylinder(d=200, h=60, center=true);
}

// Renders if the file is opened standalone
rear_lamp();
translate([0, 300, 0]) triangle_reflector();
translate([0, 600, 0]) number_plate();
translate([100, 900, 400]) jockey_wheel();
