/*
 * Offroad Adventure Trailer - Fender / Mudguard (registration requirement)
 *
 * Half-round fender over a 265/60R18 wheel, bent from 3 mm aluminum
 * tread plate (same stock as the water tank skid plate).
 * Origin = wheel center; fender width along Y.
 */

$fn = 90;

module fender(
    tire_dia = 775,
    tire_w = 265,
    clearance = 50,     // radial gap to the tire (suspension travel!)
    thickness = 3,
    overhang = 60       // extra width beyond the tire
) {
    r_i = tire_dia/2 + clearance;
    r_o = r_i + thickness;
    w = tire_w + overhang;

    color([0.1, 0.1, 0.1])
    rotate([90, 0, 0])
    difference() {
        cylinder(r=r_o, h=w, center=true);
        cylinder(r=r_i, h=w + 2, center=true);
        // Keep only the top half (open toward the ground)
        translate([-r_o - 1, -r_o - 1, -w/2 - 1])
            cube([2*r_o + 2, r_o + 1, w + 2]);
    }
}

// Renders if the file is opened standalone (with a ghost wheel)
fender();
%rotate([90, 0, 0]) cylinder(d=775, h=265, center=true);
