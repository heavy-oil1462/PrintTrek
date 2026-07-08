// cad/cabin.scad
/*
 * Offroad Adventure Trailer - Expedition Canopy (for a roof tent)
 *
 * A solid box structure (canopy) built from an inner skeleton and clad
 * with aluminum/plywood sheets on the sides, floor and roof.
 * Designed with roof racks to carry a roof tent level with the car.
 */

frame_length = 2000;
frame_width = 1200; // Matches frame.scad (narrowed for the Ranger's track)
cabin_height = 750; // Low profile so the roof tent lands at a good height
pillar_w = 40;      // 40x40 mm square tube for the body skeleton
floor_t = 15;       // Form plywood floor
wall_t = 3;         // Dibond / aluminum / plywood walls

module canopy_skeleton() {
    color("silver") {
        // Corner pillars (vertical)
        translate([0, 0, 0]) cube([pillar_w, pillar_w, cabin_height]);
        translate([frame_length - pillar_w, 0, 0]) cube([pillar_w, pillar_w, cabin_height]);
        translate([0, frame_width - pillar_w, 0]) cube([pillar_w, pillar_w, cabin_height]);
        translate([frame_length - pillar_w, frame_width - pillar_w, 0]) cube([pillar_w, pillar_w, cabin_height]);

        // Mid pillars (prevent sag when sleeping in the tent)
        translate([frame_length/2 - pillar_w/2, 0, 0]) cube([pillar_w, pillar_w, cabin_height]);
        translate([frame_length/2 - pillar_w/2, frame_width - pillar_w, 0]) cube([pillar_w, pillar_w, cabin_height]);

        // Roof beams (long sides)
        translate([0, 0, cabin_height - pillar_w]) cube([frame_length, pillar_w, pillar_w]);
        translate([0, frame_width - pillar_w, cabin_height - pillar_w]) cube([frame_length, pillar_w, pillar_w]);

        // Roof beams (short sides and middle)
        translate([pillar_w, 0, cabin_height - pillar_w]) cube([pillar_w, frame_width, pillar_w]);
        translate([frame_length/2 - pillar_w/2, 0, cabin_height - pillar_w]) cube([pillar_w, frame_width, pillar_w]);
        translate([frame_length - 2*pillar_w, 0, cabin_height - pillar_w]) cube([pillar_w, frame_width, pillar_w]);
    }
}

module roof_racks() {
    // Transverse crossbars mounted on the roof
    color("black") {
        // Front bar
        translate([frame_length*0.2, -50, cabin_height]) cube([40, frame_width + 100, 30]);
        // Rear bar
        translate([frame_length*0.8, -50, cabin_height]) cube([40, frame_width + 100, 30]);
    }
}

module trailer_cabin() {
    // 1. Floor (15 mm form plywood or similar)
    color("SaddleBrown")
        translate([0, 0, 50]) cube([frame_length, frame_width, floor_t]);

    // 2. Skeleton (40x40 beams)
    translate([0, 0, 50 + floor_t])
        canopy_skeleton();

    // 3. Roof racks (the tent mounts to these)
    translate([0, 0, 50 + floor_t])
        roof_racks();

    // 4. Walls and roof sheets (semi-transparent to show the skeleton)
    color("WhiteSmoke", 0.8) {
        // Left wall (kitchen drawer opening + storage cabinet door)
        difference() {
            translate([0, -wall_t, 50 + floor_t]) cube([frame_length, wall_t, cabin_height]);
            // Opening for the kitchen drawer (front left, pulls out sideways)
            translate([60, -wall_t - 1, 50 + floor_t]) cube([520, wall_t + 2, 330]);
            // Opening for the storage cabinet door (behind the kitchen drawer)
            translate([780, -wall_t - 1, 50 + floor_t + 50]) cube([460, wall_t + 2, 400]);
        }
        // Storage cabinet door (hinged at the front edge, shown closed)
        color("Gainsboro")
            translate([782, -wall_t, 50 + floor_t + 52]) cube([456, wall_t, 396]);

        // Right wall (el-niche + electrical bay door - all electrical
        // lives on the right side, ahead of the fridge drawer)
        difference() {
            translate([0, frame_width, 50 + floor_t]) cube([frame_length, wall_t, cabin_height]);
            // Cutout for the electrical niche (Y matches main_assembly placement)
            translate([600, frame_width - 1, 50 + floor_t + 200]) cube([160, wall_t + 2, 200]);
            // Opening for the electrical bay door (battery box lifts out here)
            translate([780, frame_width - 1, 50 + floor_t + 50]) cube([460, wall_t + 2, 400]);
        }
        // Electrical bay door (shown closed)
        color("Gainsboro")
            translate([782, frame_width, 50 + floor_t + 52]) cube([456, wall_t, 396]);

        // Front wall
        translate([-wall_t, 0, 50 + floor_t]) cube([wall_t, frame_width, cabin_height]);

        // Rear wall (tailgate opening down to floor level so the fridge
        // drawer can slide out)
        difference() {
            translate([frame_length, 0, 50 + floor_t]) cube([wall_t, frame_width, cabin_height]);
            // Tailgate cutout - sill-free at the floor for the fridge sled
            translate([frame_length - 1, 100, 50 + floor_t]) cube([wall_t + 2, frame_width - 200, cabin_height - 150]);
        }

        // Roof
        translate([0, 0, 50 + floor_t + cabin_height - wall_t]) cube([frame_length, frame_width, wall_t]);
    }

    // 5. Visual roof tent (mockup, closed/folded state)
    color("DarkOliveGreen", 0.95)
    translate([frame_length*0.1, 100, 50 + floor_t + cabin_height + 30])
        cube([frame_length*0.8, frame_width - 200, 300]);
}

// Renders if the file is opened standalone
trailer_cabin();
