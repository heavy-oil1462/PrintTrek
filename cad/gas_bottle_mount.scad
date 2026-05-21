/*
 * Offroad Adventure Trailer - Vagga för Gasolflaska (P6/PK6)
 *
 * Denna vagga CNC-fräses i 12-15 mm formplyfa eller tjock aluminiumplåt och 
 * monteras på V-dragstången (A-frame).
 * Inkluderar infällda spår för heavy-duty spännband och avrinningshål.
 */

plate_thickness = 12;      // Materialtjocklek
bottle_dia = 300;          // Diametern på en P6-flaska
cradle_margin = 40;        // Extramarginal runt om flaskan
strap_width = 32;          // Bredd på spännbandets genomföring
strap_thickness = 6;       // Tjocklek/höjd på bandets hål

$fn = 100;

module gas_bottle_cradle() {
    difference() {
        // 1. Huvudplattan (mjukt rundad rektangel)
        translate([0, 0, plate_thickness/2])
            minkowski() {
                cube([bottle_dia + cradle_margin, bottle_dia + cradle_margin, plate_thickness/2], center=true);
                cylinder(r=20, h=plate_thickness/2, center=true);
            }
            
        // 2. Försänkt spår för gasolflaskans bottenring
        // P6-flaskan har en bottenring som håller fast den. Om vi gör en urgröpning står den stadigt.
        translate([0, 0, plate_thickness - 5])
            difference() {
                cylinder(d=290, h=10);
                // Behåll mitten intakt
                translate([0, 0, -1]) cylinder(d=270, h=12);
            }
            
        // 3. Stort avrinningshål i mitten (släpper igenom smuts och vatten)
        translate([0, 0, -1])
            cylinder(d=150, h=plate_thickness + 2);
            
        // 4. Urtag för spännband (4 st runt om för att korsspänna flaskan)
        for(angle = [0, 90, 180, 270]) {
            rotate([0, 0, angle])
                translate([0, bottle_dia/2 + 10, -1])
                // Förskjut Z marginellt för att garantera hål igenom
                cube([strap_width, strap_thickness, (plate_thickness + 2) * 2], center=true);
        }
        
        // 5. Monteringshål (generiska slitsar för U-bultar mot runda/fyrkantiga dragstångsrör)
        for(x = [-90, 90]) {
            for(y = [-120, 120]) {
                translate([x, y, -1])
                    hull() {
                        translate([0, 15, 0]) cylinder(d=11, h=plate_thickness + 2); // För M10 U-bult
                        translate([0, -15, 0]) cylinder(d=11, h=plate_thickness + 2);
                    }
            }
        }
    }
}

// Rendera vaggan
gas_bottle_cradle();

// Visualisering av gasolflaskan (transparent)
%translate([0, 0, plate_thickness]) {
    color("orange", 0.7) {
        // Flaskkroppen
        cylinder(d=300, h=350);
        // Flaskhalsen
        translate([0, 0, 350]) cylinder(d1=300, d2=100, h=100);
        // Ventilen/Kranskyddet på toppen
        translate([0, 0, 450]) cylinder(d=100, h=50);
    }
}
