// cad/cabin.scad
/*
 * Offroad Adventure Trailer - Expedition Canopy (För Taktält)
 *
 * En solid lådstruktur (canopy) byggd av ett inre ramverk och täckt 
 * med aluminium/plyfa-skivor på sidor, golv och tak.
 * Designad med takräcken för att bära ett taktält i linje med bilens takhöjd.
 */

frame_length = 2000;
frame_width = 1200; // Matchar frame.scad (smalnad för Rangerns spårvidd)
cabin_height = 750; // Lägre profil så taktältet hamnar i bra höjd
pillar_w = 40;      // 40x40 mm fyrkantsrör för karossens skelett
floor_t = 15;       // Formplyfa i botten
wall_t = 3;         // Dibond / Aluminium / Plywood för väggarna

module canopy_skeleton() {
    color("silver") {
        // Hörnstolpar (Vertikala balkar)
        translate([0, 0, 0]) cube([pillar_w, pillar_w, cabin_height]);
        translate([frame_length - pillar_w, 0, 0]) cube([pillar_w, pillar_w, cabin_height]);
        translate([0, frame_width - pillar_w, 0]) cube([pillar_w, pillar_w, cabin_height]);
        translate([frame_length - pillar_w, frame_width - pillar_w, 0]) cube([pillar_w, pillar_w, cabin_height]);
        
        // Mittenstolpar (Förhindrar svikt när man sover i tältet)
        translate([frame_length/2 - pillar_w/2, 0, 0]) cube([pillar_w, pillar_w, cabin_height]);
        translate([frame_length/2 - pillar_w/2, frame_width - pillar_w, 0]) cube([pillar_w, pillar_w, cabin_height]);
        
        // Takbalkar (Långsidor)
        translate([0, 0, cabin_height - pillar_w]) cube([frame_length, pillar_w, pillar_w]);
        translate([0, frame_width - pillar_w, cabin_height - pillar_w]) cube([frame_length, pillar_w, pillar_w]);
        
        // Takbalkar (Kortsidor och mitten)
        translate([pillar_w, 0, cabin_height - pillar_w]) cube([pillar_w, frame_width, pillar_w]);
        translate([frame_length/2 - pillar_w/2, 0, cabin_height - pillar_w]) cube([pillar_w, frame_width, pillar_w]);
        translate([frame_length - 2*pillar_w, 0, cabin_height - pillar_w]) cube([pillar_w, frame_width, pillar_w]);
    }
}

module roof_racks() {
    // Tvärgående räcken/lastbågar (Crossbars) monterade på taket
    color("black") {
        // Främre räcke
        translate([frame_length*0.2, -50, cabin_height]) cube([40, frame_width + 100, 30]);
        // Bakre räcke
        translate([frame_length*0.8, -50, cabin_height]) cube([40, frame_width + 100, 30]);
    }
}

module trailer_cabin() {
    // 1. Botten (15mm formplyfa eller liknande)
    color("SaddleBrown") 
        translate([0, 0, 50]) cube([frame_length, frame_width, floor_t]);
        
    // 2. Ramverket (Skelettet av 40x40 balkar)
    translate([0, 0, 50 + floor_t])
        canopy_skeleton();
        
    // 3. Takräcken (Räcken som tältet monteras i)
    translate([0, 0, 50 + floor_t])
        roof_racks();
        
    // 4. Väggar och Takskivor (Viss transparens för att se ramen)
    color("WhiteSmoke", 0.8) {
        // Vänster vägg (med utskuret hål för el-nischen)
        difference() {
            translate([0, -wall_t, 50 + floor_t]) cube([frame_length, wall_t, cabin_height]);
            // Urtag för nischen (Y stämmer med main_assembly placering)
            translate([600, -wall_t - 1, 50 + floor_t + 200]) cube([160, wall_t + 2, 200]);
        }
        
        // Höger vägg
        translate([0, frame_width, 50 + floor_t]) cube([frame_length, wall_t, cabin_height]);
        
        // Framvägg
        translate([-wall_t, 0, 50 + floor_t]) cube([wall_t, frame_width, cabin_height]);
        
        // Bakvägg (T.ex. med lucka för köket/packningen)
        difference() {
            translate([frame_length, 0, 50 + floor_t]) cube([wall_t, frame_width, cabin_height]);
            // Urtag för bakluckan
            translate([frame_length - 1, 100, 50 + floor_t + 100]) cube([wall_t + 2, frame_width - 200, cabin_height - 200]);
        }
        
        // Taket
        translate([0, 0, 50 + floor_t + cabin_height - wall_t]) cube([frame_length, frame_width, wall_t]);
    }
    
    // 5. Visuellt taktält (Mockup i stängt/ihopfällt läge)
    color("DarkOliveGreen", 0.95)
    translate([frame_length*0.1, 100, 50 + floor_t + cabin_height + 30])
        cube([frame_length*0.8, frame_width - 200, 300]);
}

// Renderas om filen öppnas separat
trailer_cabin();
