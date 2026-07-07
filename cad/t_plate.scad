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
    hole_dia = 11,      // For M10 through-bolts (drilled before galvanizing, reamed clean after)
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
            
        // 5. Bolt pattern for the crossbeam (Zig-Zag along the Y-axis)
        for(i = [1 : 3]) {
            y_pos = tube_width/2 + 15 + i*35;
            x_pos = (i % 2 == 0) ? tube_width/2 + 12 : tube_width/2 - 12;
            
            // Hole on the right side
            translate([x_pos, y_pos, -1]) cylinder(d=hole_dia, h=plate_thickness + 2);
            // Hole on the left side
            translate([x_pos, -y_pos, -1]) cylinder(d=hole_dia, h=plate_thickness + 2);
        }
        
        // 6. Bolt pattern for the drawbar (Zig-Zag along the X-axis)
        for(i = [1 : 4]) {
            x_pos = -20 - i*40;
            y_pos = (i % 2 == 0) ? 12 : -12;
            translate([x_pos, y_pos, -1]) cylinder(d=hole_dia, h=plate_thickness + 2);
        }
        
        // 7. Bolts right in the center of the intersection
        translate([tube_width/2, 15, -1]) cylinder(d=hole_dia, h=plate_thickness + 2);
        translate([tube_width/2, -15, -1]) cylinder(d=hole_dia, h=plate_thickness + 2);
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
        
        // 1. 4 heavy-duty bolts through the horizontal beam (Crossbeam)
        // STRENGTH IMPROVEMENT: Zig-zag (X=13 and X=37) instead of a straight line (X=25).
        // This prevents creating a perforated "fracture line" straight across the steel beam.
        translate([37, 45, -1]) cylinder(d=hole_dia, h=plate_thickness + 2);
        translate([13, 15, -1]) cylinder(d=hole_dia, h=plate_thickness + 2);
        translate([37, -15, -1]) cylinder(d=hole_dia, h=plate_thickness + 2);
        translate([13, -45, -1]) cylinder(d=hole_dia, h=plate_thickness + 2);
        
        // 2. Two bolts directly into the drawbar (Along the X-axis)
        // STRENGTH IMPROVEMENT: Zig-zag to avoid stressing the same fiber in the beam
        translate([-40, 12, -1]) cylinder(d=hole_dia, h=plate_thickness + 2);
        translate([-100, -12, -1]) cylinder(d=hole_dia, h=plate_thickness + 2);
        
        // 3. Bolts on either side of the drawbar to support and clamp together (the "sandwich")
        // Same X-positions as the drawbar bolts, but out on the sides (Y = +/- 45)
        
        // Front row of side bolts (at X=-40)
        translate([-40, 45, -1]) cylinder(d=hole_dia, h=plate_thickness + 2);
        translate([-40, -45, -1]) cylinder(d=hole_dia, h=plate_thickness + 2);
        
        // STRENGTH IMPROVEMENT: Middle row of side bolts for massive clamping force (at X=-70)
        translate([-70, 45, -1]) cylinder(d=hole_dia, h=plate_thickness + 2);
        translate([-70, -45, -1]) cylinder(d=hole_dia, h=plate_thickness + 2);
        
        // Back row of side bolts (at X=-100)
        translate([-100, 45, -1]) cylinder(d=hole_dia, h=plate_thickness + 2);
        translate([-100, -45, -1]) cylinder(d=hole_dia, h=plate_thickness + 2);
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
