/*
 * Offroad Adventure Trailer - Corner Reinforcement ("Double Sandwich")
 * 
 * Parametric design for CNC milling (PrintNC) in 8-10 mm 6082-T6 aluminum.
 * Designed to bolt together 50x50 mm VKR profiles in the frame corners.
 * Includes an inner overhang (roof/floor) for a protected "cable tunnel"
 * where corrugated conduits and network cables can cut across in a soft radius past the steel.
 */

$fn = 60; // Resolution for circles/curves

// --- Main Module ---
module corner_plate(
    plate_type = "l_shape",  // ["l_shape", "rectangular"]
    plate_thickness = 10,    // Thickness of the aluminum plate (mm)
    tube_width = 50,         // Width of the VKR profile (steel frame)
    arm_length = 200,        // Total length of the plate arms from the outer corner
    hole_dia = 13,           // Hole diameter for M12 bolts (drilled before galvanizing, reamed clean after — zinc adds ~100 µm per surface)
    outer_radius = 12,       // Rounding of outer corners
    tunnel_curve = 80        // Radius for the inner soft curve (cable shortcut). Also determines offset for perfect tangent.
) {
    if (plate_type == "rectangular") {
        corner_plate_rectangular(plate_thickness, tube_width, arm_length, hole_dia, outer_radius, tunnel_curve);
    } else {
        corner_plate_l_shape(plate_thickness, tube_width, arm_length, hole_dia, outer_radius, tunnel_curve);
    }
}

module corner_plate_l_shape(plate_thickness, tube_width, arm_length, hole_dia, outer_radius, tunnel_curve) {
    difference() {
        union() {
            // 1. X-arm (Exactly 50mm wide to avoid spikes/tapering)
            hull() {
                translate([outer_radius, outer_radius, 0]) 
                    cylinder(r=outer_radius, h=plate_thickness);
                translate([outer_radius, tube_width - outer_radius, 0]) 
                    cylinder(r=outer_radius, h=plate_thickness);
                translate([arm_length - outer_radius, outer_radius, 0]) 
                    cylinder(r=outer_radius, h=plate_thickness);
                translate([arm_length - outer_radius, tube_width - outer_radius, 0]) 
                    cylinder(r=outer_radius, h=plate_thickness);
            }
            
            // 2. Y-arm (Exactly 50mm wide)
            hull() {
                translate([outer_radius, outer_radius, 0]) 
                    cylinder(r=outer_radius, h=plate_thickness);
                translate([tube_width - outer_radius, outer_radius, 0]) 
                    cylinder(r=outer_radius, h=plate_thickness);
                translate([outer_radius, arm_length - outer_radius, 0]) 
                    cylinder(r=outer_radius, h=plate_thickness);
                translate([tube_width - outer_radius, arm_length - outer_radius, 0]) 
                    cylinder(r=outer_radius, h=plate_thickness);
            }
            
            // 3. Filler material for inner overhang ("cable tunnel")
            // Creates a bridge that we then hollow out with a circle
            hull() {
                translate([tube_width, tube_width, 0]) 
                    cube([0.1, tunnel_curve, plate_thickness]);
                translate([tube_width, tube_width, 0]) 
                    cube([tunnel_curve, 0.1, plate_thickness]);
                translate([tube_width, tube_width, 0]) 
                    cylinder(r=0.1, h=plate_thickness);
            }
        }
        
        // 4. Hollow out the inner corner with a circle for PERFECT tangent transition.
        // Center is placed exactly at (tube_width + radius) to blend invisibly with the edges.
        translate([tube_width + tunnel_curve, tube_width + tunnel_curve, -1]) 
            cylinder(r=tunnel_curve, h=plate_thickness + 2);

        // 5. Drill bolt pattern (zig-zag)
        bolt_holes_x(plate_thickness, tube_width, hole_dia);
        bolt_holes_y(plate_thickness, tube_width, hole_dia);
    }
}

module corner_plate_rectangular(plate_thickness, tube_width, arm_length, hole_dia, outer_radius, tunnel_curve) {
    difference() {
        // Base plate: a full square covering the arm length
        hull() {
            translate([outer_radius, outer_radius, 0]) 
                cylinder(r=outer_radius, h=plate_thickness);
            translate([arm_length - outer_radius, outer_radius, 0]) 
                cylinder(r=outer_radius, h=plate_thickness);
            translate([outer_radius, arm_length - outer_radius, 0]) 
                cylinder(r=outer_radius, h=plate_thickness);
            translate([arm_length - outer_radius, arm_length - outer_radius, 0]) 
                cylinder(r=outer_radius, h=plate_thickness);
        }

        // 1. Drill bolt pattern (zig-zag)
        bolt_holes_x(plate_thickness, tube_width, hole_dia);
        bolt_holes_y(plate_thickness, tube_width, hole_dia);
    }
}

// --- Bolt Patterns ---
// 2x M12 per arm on the flange CENTERLINE (was 3x M10 zig-zag at
// +/-12 mm): the joints are friction-grip and never capacity-limited
// (demand ~3-5 kN vs 38 kN slip per arm), but the zig-zag put hole
// edges 7.5 mm from the tube edge — e2 = 1.18*d0, at the EN 1993-1-8
// floor. Centered M12 gives e2 = 25 mm = 1.9*d0 and half the holes to
// drill, ream after galvanizing, and sleeve. Two holes 90 mm apart on
// a preloaded, sleeve-filled joint don't create the "perforation line"
// the zig-zag guarded against; net section per plane is one hole
// either way.
module bolt_holes_x(plate_thickness, tube_width, hole_dia) {
    for(x_pos = [80, 170])
        translate([x_pos, tube_width/2, -1])
            cylinder(d=hole_dia, h=plate_thickness + 2);
    // An extra bolt exactly in the joint point (center of the cross)
    translate([tube_width/2, tube_width/2, -1])
        cylinder(d=hole_dia, h=plate_thickness + 2);
}

module bolt_holes_y(plate_thickness, tube_width, hole_dia) {
    for(y_pos = [80, 170])
        translate([tube_width/2, y_pos, -1])
            cylinder(d=hole_dia, h=plate_thickness + 2);
}

// --- Visualization & Assembly (Not rendered as a printable part by default) ---
// Renders the top plate, the steel, the bottom plate, and a mockup of the conduit
// To preview alone, uncomment below:
/*
corner_plate();

%translate([0, 0, -50]) {
    // Steel frame (VKR profiles)
    color("silver") {
        translate([50, 0, 0]) cube([200 - 50, 50, 50]);
        translate([0, 50, 0]) cube([50, 200 - 50, 50]);
        cube([50, 50, 50]);
    }
    
    // Bottom plate
    translate([0, 0, -10]) color("darkgray") corner_plate();
    
    // Conduit for electrical/antenna (shows how it cuts across inside the tunnel)
    color("black") 
        translate([50 + 80 - 10, 50/2, 50/2])
        rotate([0, 90, 0]) cylinder(d=25, h=30);
    
    color("black") 
        translate([50/2, 50 + 80 - 10, 50/2])
        rotate([-90, 0, 0]) cylinder(d=25, h=30);
        
    color("black")
        hull() {
            translate([50 + 80 - 10, 50/2, 50/2]) sphere(d=25);
            translate([50/2, 50 + 80 - 10, 50/2]) sphere(d=25);
        }
}
*/
