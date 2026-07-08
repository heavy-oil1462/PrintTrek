/*
 * Offroad Adventure Trailer - Left-Side Galley Modules
 *
 * Three units along the LEFT side (all consumers electric — propane stays
 * on fixed pipes to the right-side quick-connects):
 *
 *   1. kitchen_drawer(pullout)  — FRONT LEFT, slides out SIDEWAYS (-Y)
 *      through an opening in the left wall. Structural only: slides,
 *      plywood box, worktop and drawer front (no taps/stove modeled).
 *   2. storage_cabinet()        — MID LEFT, fixed plywood cabinet for
 *      utensils/dry goods; also houses the removable power-station box.
 *      Accessed through a door in the left wall (cut in cabin.scad).
 *   3. fridge_drawer(pullout)   — REAR LEFT, fridge-sized drawer that
 *      slides out (+X) through the rear hatch. 12V compressor fridge
 *      (Dometic CFX3 45 class) strapped into a low plywood tray.
 *
 * All origins = front-bottom-left of the CLOSED unit, sitting on the
 * cabin floor. `pullout` extends a drawer for visualization.
 */

ply = 15;            // plywood wall thickness
slide_h = 20;        // heavy-duty slide rail height
rail_w = 40;         // slide rail width
fridge = [580, 400, 413];   // CFX3 45 class, approx

// ------------------------------------------------------------------
// 1. Kitchen side-drawer (travel along -Y, out through the left wall)
//    Footprint 520 (X) x 680 (Y). Wall opening: x 60-580, 330 tall.
// ------------------------------------------------------------------
kd_x = 520;          // unit width along the wall
kd_y = 680;          // drawer length = slide length (travel direction)
kd_h = 300;          // box height incl. worktop

module kitchen_drawer(pullout = 0) {
    // Fixed slide rails on the floor, running in Y
    color("silver")
        for (x = [0, kd_x - rail_w])
            translate([x, 0, 0])
                cube([rail_w, kd_y, slide_h]);

    translate([0, -pullout, 0]) {
        // Plywood box, open top (worktop covers the rear half)
        color("BurlyWood") {
            difference() {
                translate([10, 0, slide_h])
                    cube([kd_x - 20, kd_y - 20, kd_h - ply]);
                translate([10 + ply, ply, slide_h + ply])
                    cube([kd_x - 20 - 2*ply, kd_y - 20 - 2*ply, kd_h]);
            }
            // Worktop over the inner (rear) half — front half is open bins
            translate([10, (kd_y - 20)/2, slide_h + kd_h - ply])
                cube([kd_x - 20, (kd_y - 20)/2, ply]);
        }

        // Drawer front — overlay panel sitting PROUD of the 3 mm wall
        // (wall outer face is at y=-3 in the assembly; panel at -15..-3)
        color("Peru")
            translate([-10, -15, slide_h - 15])
                cube([kd_x + 20, 12, kd_h + 25]);
    }
}

// ------------------------------------------------------------------
// 2. Storage cabinet (fixed), mid left: 650 x 450 x 550
//    Door opening in the left wall at x 780-1240 (cut in cabin.scad);
//    the electrical niche (x 600-760) shares the cabinet's front bay.
// ------------------------------------------------------------------
sc_x = 650;
sc_y = 450;
sc_h = 550;

module storage_cabinet() {
    color("Tan") {
        difference() {
            cube([sc_x, sc_y, sc_h]);
            // Hollow interior
            translate([ply, -1, ply])
                cube([sc_x - 2*ply, sc_y - ply + 1, sc_h - 2*ply]);
            // Door opening toward the left wall (-Y is wall side; the
            // wall itself carries the hinged door — see cabin.scad)
        }
        // Mid shelf above the power-station box
        translate([ply, 0, 430])
            cube([sc_x - 2*ply, sc_y - ply, ply]);
    }
}

// ------------------------------------------------------------------
// 3. Fridge drawer (travel along +X, out through the rear hatch)
//    Low tray, fridge-sized only: outer 640 x 450.
// ------------------------------------------------------------------
fd_x = 640;          // tray length = slide length
fd_y = 450;
fd_wall = 200;       // low sides — fridge is strapped, lid must clear

module fridge_drawer(pullout = 0) {
    // Fixed slide rails on the floor, running in X
    color("silver")
        for (y = [0, fd_y - rail_w])
            translate([0, y, 0])
                cube([fd_x, rail_w, slide_h]);

    translate([pullout, 0, 0]) {
        // Plywood tray
        color("BurlyWood")
            difference() {
                translate([0, 0, slide_h])
                    cube([fd_x, fd_y, fd_wall]);
                translate([ply, ply, slide_h + ply])
                    cube([fd_x - 2*ply, fd_y - 2*ply, fd_wall + 1]);
            }
        // 12V compressor fridge (lid opens upward when pulled out)
        color("DarkSlateGray")
            translate([(fd_x - fridge[0])/2, (fd_y - fridge[1])/2, slide_h + ply])
                cube(fridge);
    }
}

// Renders if the file is opened standalone (drawers half extended)
kitchen_drawer(pullout = 300);
translate([600, 0, 0]) storage_cabinet();
translate([1330, 0, 0]) fridge_drawer(pullout = 300);
