/*
 * Offroad Adventure Trailer - Slide-Out Kitchen Drawer
 *
 * Plywood drawer on 100-150 kg lock-in/lock-out slides, holding a 12V
 * compressor fridge (Dometic CFX3 45 class) and a stowed stove.
 * Fed by an ELECTRICAL-ONLY energy chain (propane stays on fixed pipes
 * to the external quick-connects — see concepts/gas_water_routing.md).
 *
 * Origin = front-bottom-left of the CLOSED drawer; slides out in +X
 * (toward the rear hatch). `pullout` extends the drawer for visualization.
 */

ply = 15;             // plywood wall thickness
drawer_l = 800;       // along X
drawer_w = 900;       // along Y
drawer_h = 350;
slide_h = 20;
fridge = [580, 400, 360];   // CFX3 45 class, approx

module kitchen_drawer(pullout = 0) {
    // Fixed slide rails (mounted to the floor structure)
    color("silver")
        for (y = [0, drawer_w - 40])
            translate([0, y, 0])
                cube([drawer_l, 40, slide_h]);

    translate([pullout, 0, 0]) {
        // Plywood box, open top
        color("BurlyWood")
            difference() {
                translate([0, 0, slide_h])
                    cube([drawer_l, drawer_w, drawer_h]);
                translate([ply, ply, slide_h + ply])
                    cube([drawer_l - 2*ply, drawer_w - 2*ply, drawer_h + 1]);
            }

        // 12V compressor fridge (lid opens up, so it may stand proud)
        color("DarkSlateGray")
            translate([drawer_l - fridge[0] - 30, (drawer_w - fridge[1])/2, slide_h + ply])
                cube(fridge);

        // Stowed stove + utensils box
        color("dimgray")
            translate([40, (drawer_w - 400)/2, slide_h + ply])
                cube([300, 400, 120]);

        // Energy chain (electrical only), draped under the drawer
        color([0.2, 0.2, 0.2])
            translate([-150, drawer_w/2 - 25, 2])
                cube([150 + 60, 50, 14]);
    }
}

// Renders if the file is opened standalone (half extended)
kitchen_drawer(pullout = 300);
