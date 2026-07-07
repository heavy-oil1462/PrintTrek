// cad/frame.scad
/*
 * Offroad Adventure Trailer - Chassi / Stålram
 *
 * Parametrisk modell för grundramen i 50x50 mm fyrkantsstål (VKR).
 * V-formad dragstång (A-ram) i samma profil: två raka armar från kopplingen,
 * genombultade under främre tvärbalken och långbalkarna.
 *
 * OBS: En tidigare version använde en enkel central dragbalk. Den är
 * borttagen — en ensam 50x50x3-balk klarar inte dynamiska offroadlaster
 * (~3g på kultrycket ger böjspänning över sträckgränsen). V-formen
 * triangulerar dessutom mot sidokrafter.
 *
 * Alla genomgående bultar i ramen kräver invändiga krosshylsor
 * (precisionsrör, t.ex. 16x2,5 mm för M10) så att fullt förspänningsmoment
 * kan användas utan att RHS-väggarna deformeras.
 */

tube_w = 50;
frame_length = 2000;
frame_width = 1200;      // Smalnad från 1400: med 265/60R18 på Rangerns
                         // spårvidd (1560 mm) blir friläget kaross-däck
                         // (1560-265)/2 - 600 = 47,5 mm. 1400 mm ram är
                         // geometriskt omöjlig med matchad spårvidd.
plate_t = 10;            // Tjocklek på aluminiumplattorna (hörn/kil/distans)

// --- Dragstång (V-form / A-ram) ---
drawbar_reach = 1000;    // Kopplingspunktens avstånd framför ramen
drawbar_attach_x = 600;  // Där armarnas bakre ände fäster under långbalkarna

// Armgeometri (toppnivå så att scripts/calculate_tubes.py hittar kaplängden)
arm_dx = drawbar_attach_x + drawbar_reach;
arm_dy = frame_width/2 - tube_w/2;
arm_len = sqrt(arm_dx*arm_dx + arm_dy*arm_dy);

// Raka armar från infästningen under långbalkarna (drawbar_attach_x)
// till kopplingspunkten (-drawbar_reach, frame_width/2).
// Ligger plate_t under ramplanet: 10 mm CNC-frästa kil-/distansplattor
// (samma aluplåt som hörnplattorna) fyller spalten vid varje infästning,
// och bultarna delas med hörnens "double sandwich" där de sammanfaller.
// (Medvetet två explicita cube-anrop så att kaplistan räknar 2 st.)

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

        // V-dragstång (A-ram): vänster arm
        translate([drawbar_attach_x, tube_w/2, -(tube_w + plate_t)])
            rotate([0, 0, atan2(arm_dy, -arm_dx)])
                translate([0, -tube_w/2, 0])
                    cube([arm_len, tube_w, tube_w]);

        // V-dragstång (A-ram): höger arm
        translate([drawbar_attach_x, frame_width - tube_w/2, -(tube_w + plate_t)])
            rotate([0, 0, atan2(-arm_dy, -arm_dx)])
                translate([0, -tube_w/2, 0])
                    cube([arm_len, tube_w, tube_w]);

        // Draghandske (fiktiv för visuellt stöd, vid kopplingspunkten)
        translate([-drawbar_reach - 120, frame_width/2 - tube_w/2, -(tube_w + plate_t)])
            cube([120, tube_w, tube_w]);
    }
}

// Renderas om filen öppnas separat
trailer_frame();
