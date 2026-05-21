/*
 * Offroad Adventure Trailer - Nisch för extern el & nätverk
 *
 * En "kopp", infälld i 3 mm Dibond-väggen (vänster sida) för att försänka
 * 230V CEE-intag och koaxialkontakter (N-type) till 5G-antennen.
 * Skyddar känsliga uttag från att slitas av av grenar under offroad-körning.
 * 
 * Tillverkas genom att CNC-fräsa ut ett tjockt block POM/Plast eller vikas i durkaluminium.
 */

wall_thickness = 3;        // Vagnens väggtjocklek
niche_width = 160;         // Bredd på urtaget
niche_height = 200;        // Höjd på urtaget
niche_depth = 60;          // Hur djupt in i vagnen den går
flange_width = 25;         // Monteringsfläns på utsidan av väggen
material_thickness = 5;    // Nischens egen godstjocklek

$fn = 60;

module power_niche() {
    difference() {
        // 1. Solid yttre block inklusive flänsen
        hull() {
            // Bakre djupa delen
            for(x = [-niche_width/2, niche_width/2]) {
                for(y = [-niche_height/2, niche_height/2]) {
                    translate([x, y, -niche_depth])
                        cylinder(r=10, h=niche_depth + material_thickness);
                }
            }
            // Yttre flänsen (vilar mot utsidan av Dibond-skivan)
            for(x = [-(niche_width/2 + flange_width), niche_width/2 + flange_width]) {
                for(y = [-(niche_height/2 + flange_width), niche_height/2 + flange_width]) {
                    translate([x, y, 0])
                        cylinder(r=5, h=material_thickness);
                }
            }
        }
        
        // 2. Gröp ur insidan (det som gör den till en låda)
        hull() {
            for(x = [-(niche_width/2 - material_thickness), (niche_width/2 - material_thickness)]) {
                for(y = [-(niche_height/2 - material_thickness), (niche_height/2 - material_thickness)]) {
                    // +0.1 för att inte få z-fighting på öppningen
                    translate([x, y, -niche_depth + material_thickness])
                        cylinder(r=10 - material_thickness, h=niche_depth + 1);
                }
            }
        }
        
        // 3. Monteringshål för paneluttag i botten av nischen
        // Hål för standard 230V blått CEE-intag (ofta 50-60 mm runt hål + 4 små skruvhål)
        translate([0, -30, -niche_depth - 1]) {
            cylinder(d=55, h=material_thickness + 2); // Centrumhål CEE
            
            // Fyra fästhål för CEE-kontakten
            for(x=[-22, 22]) {
                for(y=[-22, 22]) {
                    translate([x, y, 0]) cylinder(d=4.5, h=material_thickness + 2);
                }
            }
        }
            
        // Hål för N-kontakter (2 st för 5G MiMo-antenn)
        translate([-35, 45, -niche_depth - 1])
            cylinder(d=16.5, h=material_thickness + 2); // N-Female chassihål
            
        translate([35, 45, -niche_depth - 1])
            cylinder(d=16.5, h=material_thickness + 2);
            
        // 4. Monteringshål i flänsen för att fästa hela nischen i vagnens vägg (t.ex. popnitar eller M5 skruv)
        for(x = [-(niche_width/2 + flange_width/2), niche_width/2 + flange_width/2]) {
            for(y = [-niche_height/2, 0, niche_height/2]) {
                translate([x, y, -1])
                    cylinder(d=5.5, h=material_thickness + 2);
            }
        }
        // Skruvar i över/underkant också
        for(y = [-(niche_height/2 + flange_width/2), niche_height/2 + flange_width/2]) {
            for(x = [-niche_width/4, niche_width/4]) {
                translate([x, y, -1])
                    cylinder(d=5.5, h=material_thickness + 2);
            }
        }
    }
}

// Rendera panelen
color("darkslategray") power_niche();

// Visualisera Dibond-väggen
%translate([-250, -250, -wall_thickness])
    color("white", 0.5) difference() {
        cube([500, 500, wall_thickness]);
        // Urtaget i väggen
        translate([250 - niche_width/2 - 10, 250 - niche_height/2 - 10, -1])
            cube([niche_width + 20, niche_height + 20, wall_thickness + 2]);
    }
