# Koncept: Hörnförstärkningar ("Dubbelmacka")

**Syfte:** Sammanfoga stålramens hörn på ett extremt starkt och vibrationssäkert sätt utan helsvetsning, vilket förhindrar sprickbildning vid offroad-körning och underlättar varmgalvanisering.

## Designparametrar (För PrintNC CAD)
- **Material:** 6082-T6 Aluminium (Tjocklek: 8-10 mm).
- **Bultmönster:** Designa ett "zick-zack"-mönster (offset) för bultarna för att förhindra försvagning längs en enskild linje i stålprofilen (VKR). Genomgående M10 eller M12 (8.8/10.9).
- **Bockning/Stagning:** Utöver 90-graders profilen, integrera fästpunkter i plattorna för att fixera flexslangarna i "kabeltunneln" mellan övre och undre aluminiumplatta.
- **Toleranser:** Fräsningen ska tillåta exakt passform för bultar men även ge mikroskopisk plats för isoleringsfilm (gummi/vinyl) och marinfett (Duralac) mellan stål och aluminium.

## Att iterera i CAD
1. Modellera VKR-stålhörnet och identifiera avstånd och eventuella kollisioner för bultar (glöm inte brickorna).
2. Skapa negativt utrymme (tunneln) där rör och flexslang tillåts hoppa ur stålprofilen innan 90-graders mötet, och färdas skyddat mellan plattorna. Speciellt viktigt för den känsliga LMR-koaxialkabeln till 5G-antennen som kräver mjuk radie.
3. FEA-simulera hörnet (statisk last och vridkraft) om möjligt, för att spara vikt i aluminiumplattorna (t.ex. genom att fräsa ut fickor där materialet är överflödigt).
