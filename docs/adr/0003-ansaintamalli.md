# ADR 0003: Ansaintamalli – palkkio varauksesta, ei mainoksia

- Tila: ehdotus. Päätetty: hyvitykset jaetaan suhteessa (2026-11-06). Palkkion taso,
  pilotin 0 % ja palvelumaksu ovat vielä ehdotuksia, eikä niistä ole päätetty.
- Päivä: 2026-11-06

## Lyhyesti

Ehdotus: alusta tienaa ottamalla pienen palkkion jokaisesta toteutuneesta
renkaanvaihdosta. Ensimmäisellä kaudella palkkio olisi 0 %, jotta tarjoajat saadaan mukaan.
Mainoksia ei käytetä.

Päätetty: jos asiakkaalle palautetaan rahaa, palkkio pienenee samassa suhteessa kuin
tarjoajan osuus.

## Konteksti

Vaihtoehtoja oli kolme:

| Malli | Miten tienaa | Miksi ei (nyt) / miksi kyllä |
|---|---|---|
| Mainokset (kuten tori.fi) | Näytöt ja klikit | Tarvitsee valtavan kävijämäärän. Renkaanvaihto on kapea ja kausittainen aihe: muutama viikko keväällä ja syksyllä. Tuotto jäisi satoihin euroihin kaudessa, ja mainokset heikentäisivät luottamusta. |
| Kuukausimaksu tarjoajille | Kiinteä maksu | Yksityinen tekijä ei maksa etukäteen palvelusta, jonka hyötyä ei vielä näe. Kausittaisuus tekee kuukausimaksusta huonon kaupan talvella. |
| **Palkkio varauksesta** | % jokaisesta työstä | Maksu kulkee jo alustan kautta (varataan ennen työtä, veloitetaan kuittauksen jälkeen). Tarjoaja maksaa vain, kun saa työn ja rahat. |

Esimerkki: 50 € työ, palkkio 10 % = 5 €. Maksupalvelu vie siitä noin 1 €, joten
alustalle jää noin 4 € varausta kohden.

## Ehdotus

1. **Palkkio on oletuksena 10 % työn hinnasta ja matkalisästä.** Arvo on säädettävissä
   (`platform_settings.default_commission_bps`, 1000 = 10 %). Ehdotettu haarukka on
   8–12 %; lopullinen taso päätetään pilotin jälkeen.
2. **Pilottikaudella 0 %.** Kannan oletus on 10 %, joten pilotissa jokaiselle tarjoajalle
   lisätään poikkeus voimassaolopäivällä (`provider_commission_overrides`). Sovittu palkkio ei näy julkisesti, vain tarjoajan
   omistajalle ja ylläpidolle.
3. **Palkkio lukitaan, kun asiakas varaa ajan.** Myöhempi muutos ei muuta jo tehtyjä
   varauksia.
4. **Asiakkaan palvelumaksu on mahdollinen, mutta pilotissa 0 €**
   (`customer_service_fee_cents`).
5. **Ei mainoksia.** Näkyvyyden ostaminen (nostot) harkitaan vasta, kun yhdessä
   kaupungissa on niin monta tarjoajaa, että järjestyksellä on merkitystä. Maksettu
   näkyvyys merkitään aina selvästi ("Mainos" / "Nostettu"), koska EU:n säännöt
   (kuluttajansuojan Omnibus-direktiivi ja P2B-asetus) edellyttävät sitä.

### Hyvitykset jaetaan suhteessa

Jos asiakkaalle palautetaan osa maksusta, sekä tarjoajan osuus että alustan palkkio
pienenevät samalla prosentilla.

| | Ennen hyvitystä | 20 % hyvitys |
|---|---|---|
| Asiakas maksoi | 50,00 € | 40,00 € |
| Tarjoaja saa | 45,00 € | 36,00 € |
| Alusta saa (10 %) | 5,00 € | 4,00 € |

Perustelu: alusta ei hyödy huonosta työstä, eikä tarjoaja maksa palkkiota rahasta,
jota hän ei saanut. Sama käytäntö on Stripen `refund_application_fee`-asetuksessa.

Sääntö lasketaan yhdessä paikassa, näkymässä `payment_settlements`. Tarjoajan
tienestit (`provider_earnings`) ja verottajan DAC7-raportti lukevat sitä.

## Seuraukset

- **Ohitus on suurin riski.** Renkaat vaihdetaan kaksi kertaa vuodessa usein saman
  tekijän luona, ja toisella kerralla on houkuttelevaa sopia suoraan. Alustan on oltava
  helpompi kuin ohittaminen: muistutus seuraavasta kaudesta suoraan varaukseen,
  reklamaatiosuoja ja arvostelut vain alustan kautta tehdyistä töistä.
- Korjaamoilla on omat asiakkaansa, joten niille voidaan myöhemmin tarvita matalampi
  palkkio tai kuukausimaksu. Päätetään pilotin kokemusten perusteella.
- Alusta käsittelee rahaa, joten se raportoi tarjoajien tulot DAC7:n mukaisesti
  (`admin_dac7_report`).
- Myöhemmät lisätulot, jotka eivät haittaa käyttöä: kumppanuus rengaskaupan kanssa
  (uudet renkaat, rengashotelli) ja merkityt nostot.
