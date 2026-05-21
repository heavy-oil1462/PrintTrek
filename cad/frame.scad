// cad/frame.scad
/*
 * Offroad Adventure Trailer - Chassi / Stålram
 *
 * Parametrisk modell för grundramen i 50x50 mm fyrkantsstål (VKR).
 * Inkluderar V-dragstång (A-ram) och central tvärbalk för torsionsaxeln.
 */

tube_w = 50;
frame_length = 2000;
frame_width = 1400;

module trailer_frame() {
    color("silver") {
        // Långsidor (Vänster och Höger balk)
        translate([0, 0, 0]) cube([frame_length, tube_w, tube_w]);
        translate([0, frame_width - tube_w, 0]) cube([frame_length, tube_w, tube_w]);
        
        // Kortsidor (Fram och Bak)
        // Ligger infällda mellan långsidorna för att ge rena bultytor i hörnen
        translate([tube_w, tube_w, 0]) 
            rotate([0, 0, 90]) cube([frame_width - 2*tube_w, tube_w, tube_w]);
        translate([frame_length, tube_w, 0]) 
            rotate([0, 0, 90]) cube([frame_width - 2*tube_w, tube_w, tube_w]);
        
        // Mittenbalk (över axeln, ca 60% bak på vagnen)
        translate([frame_length*0.6, tube_w, 0]) 
            rotate([0, 0, 90]) cube([frame_width - 2*tube_w, tube_w, tube_w]);
        
        // Central Dragstång (Enkel balk istället för V-ram)
        // Går från draghandsken in i ramen.
        translate([-1000, frame_width/2 - tube_w/2, 0]) cube([1000 + tube_w, tube_w, tube_w]);
        
        // Draghandske (fiktiv för visuellt stöd)
        translate([-1100, frame_width/2 - tube_w/2, 0]) cube([100, tube_w, tube_w]);
    }
}

// Renderas om filen öppnas separat
trailer_frame();
