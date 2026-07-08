/*
 * Offroad Adventure Trailer - Niche for External Power & Network
 *
 * A "cup" recessed into the 3 mm Dibond wall to countersink the 230V
 * CEE inlet and the coaxial connectors (N-type) for the 5G antenna.
 * Protects sensitive sockets from being ripped off by branches during
 * off-road driving.
 *
 * Manufactured by CNC-milling a thick POM/plastic block or bending
 * aluminum tread plate.
 */

wall_thickness = 3;        // Trailer wall thickness
niche_width = 160;         // Cutout width
niche_height = 200;        // Cutout height
niche_depth = 60;          // How deep it goes into the trailer
flange_width = 25;         // Mounting flange on the outside of the wall
material_thickness = 5;    // Wall thickness of the niche itself

$fn = 60;

module power_niche() {
    difference() {
        // 1. Solid outer block including the flange
        hull() {
            // Deep rear part
            for(x = [-niche_width/2, niche_width/2]) {
                for(y = [-niche_height/2, niche_height/2]) {
                    translate([x, y, -niche_depth])
                        cylinder(r=10, h=niche_depth + material_thickness);
                }
            }
            // Outer flange (rests against the outside of the Dibond sheet)
            for(x = [-(niche_width/2 + flange_width), niche_width/2 + flange_width]) {
                for(y = [-(niche_height/2 + flange_width), niche_height/2 + flange_width]) {
                    translate([x, y, 0])
                        cylinder(r=5, h=material_thickness);
                }
            }
        }

        // 2. Hollow out the inside (what makes it a box)
        hull() {
            for(x = [-(niche_width/2 - material_thickness), (niche_width/2 - material_thickness)]) {
                for(y = [-(niche_height/2 - material_thickness), (niche_height/2 - material_thickness)]) {
                    // +0.1 to avoid z-fighting at the opening
                    translate([x, y, -niche_depth + material_thickness])
                        cylinder(r=10 - material_thickness, h=niche_depth + 1);
                }
            }
        }

        // 3. Mounting holes for panel sockets in the bottom of the niche
        // Hole for a standard blue 230V CEE inlet (typically a 50-60 mm
        // round hole + 4 small screw holes)
        translate([0, -30, -niche_depth - 1]) {
            cylinder(d=55, h=material_thickness + 2); // CEE center hole

            // Four fastening holes for the CEE connector
            for(x=[-22, 22]) {
                for(y=[-22, 22]) {
                    translate([x, y, 0]) cylinder(d=4.5, h=material_thickness + 2);
                }
            }
        }

        // Holes for N connectors (2x for the 5G MiMo antenna)
        translate([-35, 45, -niche_depth - 1])
            cylinder(d=16.5, h=material_thickness + 2); // N-female chassis hole

        translate([35, 45, -niche_depth - 1])
            cylinder(d=16.5, h=material_thickness + 2);

        // 4. Flange mounting holes to fasten the niche to the trailer
        // wall (e.g. pop rivets or M5 screws)
        for(x = [-(niche_width/2 + flange_width/2), niche_width/2 + flange_width/2]) {
            for(y = [-niche_height/2, 0, niche_height/2]) {
                translate([x, y, -1])
                    cylinder(d=5.5, h=material_thickness + 2);
            }
        }
        // Screws along the top/bottom edges too
        for(y = [-(niche_height/2 + flange_width/2), niche_height/2 + flange_width/2]) {
            for(x = [-niche_width/4, niche_width/4]) {
                translate([x, y, -1])
                    cylinder(d=5.5, h=material_thickness + 2);
            }
        }
    }
}

// Render the panel
color("darkslategray") power_niche();

// Visualize the Dibond wall
%translate([-250, -250, -wall_thickness])
    color("white", 0.5) difference() {
        cube([500, 500, wall_thickness]);
        // Wall cutout
        translate([250 - niche_width/2 - 10, 250 - niche_height/2 - 10, -1])
            cube([niche_width + 20, niche_height + 20, wall_thickness + 2]);
    }
