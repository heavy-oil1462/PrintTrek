// cad/t_plate.scad
/*
 * Offroad Adventure Trailer - T-Reinforcement ("T-Sandwich")
 * 
 * SLIM DESIGN: Precisely shaped to the profiles (50 mm wide) with beautiful
 * stress-reducing inner corners (fillets). Very similar to the corner plates.
 */

$fn = 60;

module t_plate(
    plate_type = "rectangular", // ["t_shape", "rectangular"]
    plate_thickness = 10,
    tube_width = 50,
    arm_length_x = 220, // For t_shape: Distance the plate extends along the central drawbar
    arm_length_y = 180, // For t_shape: Distance the plate extends along the crossbeam (left and right)
    rect_min_x = -130,  // For rectangular: back extension along drawbar
    rect_max_x = 50,    // For rectangular: front extension (typically covers crossbeam)
    rect_min_y = -65,   // For rectangular: left extension
    rect_max_y = 65,    // For rectangular: right extension
    hole_dia = 13,      // For M12 through-bolts (drilled before galvanizing, reamed clean after)
    outer_radius = 12,  // Outer corner radius
    fillet_r = 50       // Radius of the inner corner fillet
) {
    if (plate_type == "rectangular") {
        t_plate_rectangular(plate_thickness, tube_width, hole_dia, outer_radius, rect_min_x, rect_max_x, rect_min_y, rect_max_y);
    } else {
        t_plate_t_shape(plate_thickness, tube_width, arm_length_x, arm_length_y, hole_dia, outer_radius, fillet_r);
    }
}

module t_plate_t_shape(plate_thickness, tube_width, arm_length_x, arm_length_y, hole_dia, outer_radius, fillet_r) {
    difference() {
        union() {
            // 1. Crossbeam arm (Y-axis) - Exactly 50mm wide
            hull() {
                translate([outer_radius, arm_length_y - outer_radius, 0]) cylinder(r=outer_radius, h=plate_thickness);
                translate([tube_width - outer_radius, arm_length_y - outer_radius, 0]) cylinder(r=outer_radius, h=plate_thickness);
                
                translate([outer_radius, -arm_length_y + outer_radius, 0]) cylinder(r=outer_radius, h=plate_thickness);
                translate([tube_width - outer_radius, -arm_length_y + outer_radius, 0]) cylinder(r=outer_radius, h=plate_thickness);
            }
            
            // 2. Drawbar arm (X-axis) - Exactly 50mm wide
            hull() {
                // Connects flat against X=0 across the entire beam width
                translate([0, -tube_width/2, 0]) cube([0.1, tube_width, plate_thickness]);
                
                // Outer end with rounded corners
                translate([-arm_length_x + outer_radius, tube_width/2 - outer_radius, 0]) cylinder(r=outer_radius, h=plate_thickness);
                translate([-arm_length_x + outer_radius, -tube_width/2 + outer_radius, 0]) cylinder(r=outer_radius, h=plate_thickness);
            }
            
            // 3. Filler material for inner corners (a triangle of extra material that fillets will hollow out)
            // Upper corner (+Y)
            hull() {
                translate([0, tube_width/2, 0]) cube([0.1, fillet_r, plate_thickness]);
                translate([-fillet_r, tube_width/2, 0]) cube([fillet_r, 0.1, plate_thickness]);
                translate([0, tube_width/2, 0]) cylinder(r=0.1, h=plate_thickness);
            }
            // Lower corner (-Y)
            hull() {
                translate([0, -tube_width/2 - fillet_r, 0]) cube([0.1, fillet_r, plate_thickness]);
                translate([-fillet_r, -tube_width/2 - 0.1, 0]) cube([fillet_r, 0.1, plate_thickness]);
                translate([0, -tube_width/2, 0]) cylinder(r=0.1, h=plate_thickness);
            }
        }
        
        // 4. Hollow out inner corners with circles for perfectly smooth transitions
        // Tangent against X=0 and Y=25
        translate([-fillet_r, tube_width/2 + fillet_r, -1]) 
            cylinder(r=fillet_r, h=plate_thickness + 2);
            
        // Tangent against X=0 and Y=-25
        translate([-fillet_r, -tube_width/2 - fillet_r, -1]) 
            cylinder(r=fillet_r, h=plate_thickness + 2);
            
        // 5. Bolt pattern for the crossbeam: 2x M12 per side on the
        // flange centerline (see corner_plate.scad for the rationale —
        // e2 = 1.9*d0 vs the old zig-zag's 1.18*d0, half the holes)
        for(y_pos = [75, 145]) {
            translate([tube_width/2, y_pos, -1]) cylinder(d=hole_dia, h=plate_thickness + 2);
            translate([tube_width/2, -y_pos, -1]) cylinder(d=hole_dia, h=plate_thickness + 2);
        }

        // 6. Bolt pattern for the drawbar: 2x M12 on the centerline
        for(x_pos = [-60, -140])
            translate([x_pos, 0, -1]) cylinder(d=hole_dia, h=plate_thickness + 2);
    }
}

module t_plate_rectangular(plate_thickness, tube_width, hole_dia, outer_radius, rect_min_x, rect_max_x, rect_min_y, rect_max_y) {
    r = outer_radius;
    
    difference() {
        // Base plate with rounded corners
        hull() {
            translate([rect_min_x + r, rect_min_y + r, 0]) cylinder(r=r, h=plate_thickness);
            translate([rect_max_x - r, rect_min_y + r, 0]) cylinder(r=r, h=plate_thickness);
            translate([rect_min_x + r, rect_max_y - r, 0]) cylinder(r=r, h=plate_thickness);
            translate([rect_max_x - r, rect_max_y - r, 0]) cylinder(r=r, h=plate_thickness);
        }
        
        // 1. 2x M12 through the vertical member (in the mid-crossbeam
        // use this is the RAIL): on the flange centerline (X=25), 60 mm
        // apart — e2 = 25 mm = 1.9*d0 vs the old zig-zag's 1.18*d0.
        // One 13 mm hole per cross-section plane, same net section
        // logic as the zig-zag, half the holes (see corner_plate.scad).
        translate([25, 30, -1]) cylinder(d=hole_dia, h=plate_thickness + 2);
        translate([25, -30, -1]) cylinder(d=hole_dia, h=plate_thickness + 2);

        // 2. 2x M12 through the horizontal member (the CROSSBEAM in the
        // mid-crossbeam use), on its centerline, 40/100 mm from the
        // beam end (e1 = 3*d0)
        translate([-40, 0, -1]) cylinder(d=hole_dia, h=plate_thickness + 2);
        translate([-100, 0, -1]) cylinder(d=hole_dia, h=plate_thickness + 2);

        // (The former Y=+/-45 "side clamp" rows are gone: those bolts
        // passed BESIDE the beam through open air between the plates —
        // they could only clamp via 50 mm standoff sleeves that were
        // never specified, and the through-beam bolts with crush
        // sleeves already provide the sandwich preload.)
    }
}

// Visualization of the tubes (hidden by default)
/*
%translate([0, 0, -50]) {
    color("silver") {
        // Crossbeam
        translate([0, -180, 0]) cube([50, 180*2, 50]);
        // Drawbar
        translate([-220, -25, 0]) cube([220, 50, 50]);
    }
    
    // The plate under the tubes
    translate([0, 0, -10]) color("darkgray") t_plate();
}
*/
