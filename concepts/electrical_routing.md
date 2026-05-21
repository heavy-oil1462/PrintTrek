# Koncept: El- & Nätverksdragning (Vänster Sida)

**Syfte:** Maximera driftsäkerhet, personsäkerhet och signalintegritet genom rigorös separation från gasol, stjärnjordning och smart blottning/inkapsling.

## Detaljer & Struktur
- **Stjärnjord (Single-Point Grounding):** Chassit har en central, kraftig bult/plint. Alla delsystem (230V skyddsjord, 12V minus, och utjämningskabel) dras gemensamt hit. Syftet är att undvika krypströmmar och jordslingor. Stålramen ansluts med en 6 mm² gulgrön kabel.
- **Tunneldesign i Hörnen:** Stålet utgör en pansrad rörgång, men vid varje 90-gradershörn är profilerna igensvetsade (eller bultade tätt). Håltagning med gummigenomföring sker strax *före* hörnen och flexslangen "genar" mjukt inuti dubbelmackan av aluminiumplattor.
- **Nätverk (RF):** Koaxialkablar (typ LMR-200/400) är känsliga för skarpa böjar och klämskador. Hörngenomföringarna måste ha en noggrant beräknad kurvradie (Bending Radius).
- **Modulär Power Station:** Designas som en fristående låda. Lådan har stora, kraftiga Anderson-kontakter på utsidan för in/ut. Innehåller 12V batteribank, DC-DC-laddare, MPPT och Noco 230V-laddare. Lådan måste gå att lyfta ur vagnen på 1 minut för vinterförvaring eller användning externt i baslägret.

## Nästa steg
1. Kissa upp ett formellt elschema (Single Line Diagram) för 12V och 230V.
2. Designa/CNC-fräsa el-nischen: En nedsänkt modul i vänster Dibond-vägg som snyggt rymmer 230V CEE-intag samt väderskyddade N-kontakter till Poynting-antennen.
