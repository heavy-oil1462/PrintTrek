// cad/frame.scad
/*
 * Offroad Adventure Trailer - Chassi / Stålram
 *
 * Parametrisk modell för grundramen i 50x50 mm fyrkantsstål (VKR)
 * med central dragbalk i VKR 100x50x4 (stående).
 *
 * DIMENSIONERING AV DRAGBALKEN:
 *   100 kg kultryck x 3g dynamiskt offroadtillägg x 1,09 m hävarm
 *   = 3,2 kNm böjmoment vid främre tvärbalken.
 *   VKR 100x50x4 stående: W = 28,8 cm3 -> ~111 MPa mot S355 sträckgräns
 *   = säkerhetsfaktor ~3,2 (bra fatigue-marginal).
 *   (En 50x50x3 gav ~390 MPa - över sträckgränsen - därav den grövre balken.
 *    Ett V-drag är alternativet; se drawbar_wedge_plate.scad + git-historik.)
 *   Sidokrafter: balken lappar under ramen ända bak till axeltvärbalken,
 *   så sidomomentet tas som ett kraftpar över 1,2 m i stället för i en
 *   enda knutpunkt. Bultning vid båda tvärbalkarna (M12 + krosshylsor).
 *
 * Alla genomgående bultar i ramen kräver invändiga krosshylsor
 * (precisionsrör, t.ex. 16x2,5 mm för M10, 20x3 för M12) så att fullt
 * förspänningsmoment kan användas utan att RHS-väggarna deformeras.
 */

tube_w = 50;
frame_length = 2000;
frame_width = 1200;      // Smalnad från 1400: med 265/60R18 på Rangerns
                         // spårvidd (1560 mm) blir friläget kaross-däck
                         // (1560-265)/2 - 600 = 47,5 mm. 1400 mm ram är
                         // geometriskt omöjlig med matchad spårvidd.
plate_t = 10;            // Tjocklek på aluminiumplattorna (hörn/kil/distans)

// --- Central dragbalk (VKR 100x50x4, stående) ---
drawbar_reach = 1000;    // Kopplingspunktens avstånd framför ramen
bar_w = 50;              // Balkbredd (Y)
bar_h = 100;             // Balkhöjd (Z) - stående orientering för max W
// Balken lappar under ramen till och med axeltvärbalken:
drawbar_end_x = frame_length*0.6 + tube_w;
drawbar_len = drawbar_reach + drawbar_end_x;

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

        // Central dragbalk (VKR 100x50x4, stående): ligger plate_t under
        // ramplanet. 10 mm frästa distansplattor fyller spalten vid främre
        // tvärbalken och axeltvärbalken, där balken genombultas
        // (M12 + krosshylsor genom båda profilerna).
        translate([-drawbar_reach, frame_width/2 - bar_w/2, -(bar_h + plate_t)])
            cube([drawbar_len, bar_w, bar_h]);

        // Draghandske (fiktiv för visuellt stöd, i nivå med balkens överkant)
        translate([-drawbar_reach - 120, frame_width/2 - tube_w/2, -(plate_t + tube_w)])
            cube([120, tube_w, tube_w]);
    }
}

// Renderas om filen öppnas separat
trailer_frame();
