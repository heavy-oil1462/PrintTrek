// Battery Compartment Layout

// --- Parameters ---
// Box dimensions (Internal)
box_w = 500;
box_h = 400;
box_d = 250;
box_thickness = 2;

// Battery dimensions (e.g., typical 12V 100Ah LiFePO4)
batt_w = 330;
batt_d = 170;
batt_h = 220;

// Inverter dimensions (e.g., 1000W)
inv_w = 250;
inv_h = 150;
inv_d = 100;

// Charger dimensions (e.g., 15A AC-DC)
charger_w = 150;
charger_h = 100;
charger_d = 60;

// MPPT Solar Controller dimensions (e.g., Victron SmartSolar 75/15)
mppt_w = 100;
mppt_h = 113;
mppt_d = 40;

// Safety components dimensions
din_rail_w = 100;
din_rail_h = 35;
din_rail_d = 7.5;
rcbo_w = 36; // 2-module wide RCBO
rcbo_h = 85;
rcbo_d = 70;
dc_breaker_w = 50;
dc_breaker_h = 80;
dc_breaker_d = 40;

// --- Modules ---

module enclosure() {
    // Metal electrical box
    difference() {
        // Outer dimensions
        color("SlateGray", 0.3)
        cube([box_w + box_thickness*2, box_d + box_thickness*2, box_h + box_thickness*2], center=true);
        
        // Inner dimensions (hollow out)
        cube([box_w, box_d, box_h], center=true);
        
        // Front door opening
        translate([0, box_d/2, 0])
        cube([box_w, box_thickness*3, box_h], center=true);
    }
}

module handles() {
    // Simple side handles for portability
    handle_w = 20;
    handle_h = 100;
    handle_d = 40;
    
    color("Silver") {
        // Left handle
        translate([-(box_w/2 + handle_d/2 + box_thickness), 0, 0])
        difference() {
            cube([handle_d, handle_w, handle_h], center=true);
            cube([handle_d - 10, handle_w + 2, handle_h - 20], center=true);
        }
        
        // Right handle
        translate([(box_w/2 + handle_d/2 + box_thickness), 0, 0])
        difference() {
            cube([handle_d, handle_w, handle_h], center=true);
            cube([handle_d - 10, handle_w + 2, handle_h - 20], center=true);
        }
    }
}

module external_connectors() {
    // 230V CEE Inlet (Blue, 3-pin)
    color("Blue")
    translate([-(box_w/2 + box_thickness + 10), -box_d/4, box_h/4])
    rotate([0, 90, 0])
    cylinder(d=60, h=20, $fn=32, center=true);
    
    // 2x 230V Outlets (Schuko/Waterproof)
    color("LightGray")
    translate([box_w/2 + box_thickness + 10, -box_d/4 + 40, box_h/4 + 30])
    rotate([0, 90, 0])
    cylinder(d=50, h=20, $fn=32, center=true);
    
    color("LightGray")
    translate([box_w/2 + box_thickness + 10, -box_d/4 - 40, box_h/4 + 30])
    rotate([0, 90, 0])
    cylinder(d=50, h=20, $fn=32, center=true);
    
    // 1x 12V Outlet (Cigarette lighter style or similar)
    color("Black")
    translate([box_w/2 + box_thickness + 10, -box_d/4, box_h/4 - 40])
    rotate([0, 90, 0])
    cylinder(d=30, h=20, $fn=32, center=true);
    
    // Solar Input Connector (XT60 or small Anderson)
    color("Yellow")
    translate([box_w/2 + box_thickness + 10, -box_d/4, box_h/4 - 80])
    rotate([0, 90, 0])
    cube([15, 25, 20], center=true);
    
    // Main DC Connector to Trailer (Anderson style SB175)
    color("Red")
    translate([0, box_d/2 + box_thickness + 10, -box_h/2 + 40])
    rotate([90, 0, 0])
    cube([60, 20, 80], center=true);
}

module battery() {
    // LiFePO4 Battery
    color("DarkSlateGray")
    cube([batt_w, batt_d, batt_h], center=true);
    
    // Terminals
    color("Silver") {
        translate([-batt_w/2 + 30, 0, batt_h/2 + 10]) cylinder(d=15, h=20, $fn=16, center=true);
        translate([batt_w/2 - 30, 0, batt_h/2 + 10]) cylinder(d=15, h=20, $fn=16, center=true);
    }
}

module inverter() {
    color("DodgerBlue")
    cube([inv_w, inv_d, inv_h], center=true);
}

module charger() {
    color("LimeGreen")
    cube([charger_w, charger_d, charger_h], center=true);
}

module mppt() {
    color("DarkTurquoise")
    cube([mppt_w, mppt_d, mppt_h], center=true);
}

module safety_components() {
    // DIN Rail
    color("Silver")
    translate([0, 0, -rcbo_d/2 + din_rail_d/2])
    cube([din_rail_w, din_rail_h, din_rail_d], center=true);
    
    // 230V RCBO (Ground Fault + MCB)
    color("White")
    translate([-20, 0, 0])
    cube([rcbo_w, rcbo_h, rcbo_d], center=true);
    
    // 12V DC Resettable Breaker
    color("Black")
    translate([30, 0, -rcbo_d/2 + dc_breaker_d/2])
    cube([dc_breaker_w, dc_breaker_h, dc_breaker_d], center=true);
}

// --- Main Assembly ---
// Wrapped in a module so main_assembly.scad can place the whole box.
// Origin = center of the enclosure.
module battery_box() {
    enclosure();
    handles();
    external_connectors();

    // Place Battery at the bottom
    translate([0, 0, -box_h/2 + batt_h/2])
    battery();

    // Place Inverter on the back wall, above battery
    translate([-box_w/4 + 20, -box_d/2 + inv_d/2, box_h/2 - inv_h/2 - 20])
    inverter();

    // Place Charger on the back wall, above battery, next to inverter
    translate([box_w/4 + 20, -box_d/2 + charger_d/2, box_h/2 - charger_h/2 - 20])
    charger();

    // Place MPPT Solar Controller on a side wall
    translate([box_w/2 - mppt_d/2, -box_d/4, box_h/2 - mppt_h/2 - 40])
    rotate([0, 0, 90])
    mppt();

    // Place Safety Components (Breakers) near the top or on a side wall
    translate([0, -box_d/2 + rcbo_d/2, box_h/2 - rcbo_h/2 - 120])
    rotate([90, 0, 0])
    safety_components();
}

// Renders if the file is opened standalone
battery_box();
