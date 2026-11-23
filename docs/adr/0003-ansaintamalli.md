# ADR 0003: Ansaintamalli – palvelumaksu asiakkaalta ja välityspalkkio tekijältä

- Tila: päätetty (suunnitelma "Pikkutyö – suunnitelma", 17.11.2026). Hyvitykset jaetaan
  suhteessa (2026-11-06).
- Päivä: 2026-11-06, päivitetty 2026-11-17

## Lyhyesti

- **Asiakkaalta palvelumaksu 10 %, kuitenkin vähintään 2,99 €** (sis. ALV 25,5 %).
- **Yrityksiltä, toiminimiltä ja kevytyrittäjiltä välityspalkkio 5 %.**
- **Yksityishenkilöltä 0 %** (ADR 0006). Liiketoimintapäätös, ei lakipakko: yksityishenkilö
  tekee työn toimeksiantona, joten työnvälityksen maksukielto ei koske sitä.
- Tekijä asettaa työn hinnan ilmoitusta tehdessään. Hakutuloksissa näytetään kokonaishinta,
  ennen tilausta työn hinta ja palvelumaksu eritellään.
- Ei mainoksia. Maksettu näkyvyys merkitään aina selvästi, jos sellaista joskus tulee.

## Kate

| 35 €:n työ | Yritys, toiminimi tai kevytyrittäjä | Yksityishenkilö |
|---|---|---|
| Asiakas maksaa | 38,50 € | 38,50 € |
| Tekijä saa | 33,25 € | 35,00 € |
| Alustan bruttotuotto | 5,25 € | 3,50 € |
| ALV 25,5 % | −1,07 € | −0,71 € |
| Stripe-kortti (1,5 % + 0,25 €) | −0,83 € | −0,83 € |
| Connect-tilitys (0,25 % + 0,10 €) | −0,19 € | −0,19 € |
| **Kate** | **noin 3,16 €** | **noin 1,77 €** |

20 €:n työssä minimimaksu 2,99 € on 15 %, ja kate on noin 2,43 € (yritys) tai 1,64 €
(yksityishenkilö). Stripe Connect veloittaa lisäksi 2 € kuussa jokaisesta aktiivisesta
tekijästä.

Pilotin kiinteät kulut ovat noin 310 €/kk, josta Vipps MobilePay Login Advanced 60 €/kk
(20 aktiivisella tekijällä noin 350 €/kk). Nollatulokseen tarvitaan noin 119–135 tilausta
kuukaudessa, kun 60 % töistä on yritysten.

Hylätyt: 1 € kiinteä maksu (ei kata korttikuluja), 8 % (väh. 1,50 €) (kate liian pieni)
ja 18 % (väh. 3,50 €) (liian suuri pikkutöille).

## Päätös

1. **Palvelumaksu ja palkkio ovat alustan omia maksuja, eivät osa työn hintaa.**
   Tekijä päättää työn hinnan (ADR 0005).
2. **Arvot ovat säädettäviä** `platform_settings`-taulussa: asiakkaan palvelumaksu
   (bps + vähimmäismäärä senteissä: 1000 bps, 299 snt) ja tekijän palkkio
   (`default_commission_bps` 500; yksityishenkilöillä 0).
3. **Pilotissa voidaan antaa alennus** tarjoajakohtaisella poikkeuksella
   (`provider_commission_overrides`).
4. **Maksut lukitaan, kun asiakas varaa.** Myöhempi muutos ei koske tehtyjä varauksia.

### Hyvitykset jaetaan suhteessa

Jos asiakkaalle palautetaan osa maksusta, tekijän osuus ja alustan palkkio pienenevät
samalla prosentilla. Asiakkaan palvelumaksu palautetaan vain, jos tekijä perui tai työ
jäi tekemättä tekijän vuoksi.

| | Ennen hyvitystä | 20 % hyvitys |
|---|---|---|
| Työn hinta | 50,00 € | 40,00 € |
| Tekijä saa (95 %) | 47,50 € | 38,00 € |
| Alustan palkkio (5 %) | 2,50 € | 2,00 € |

Sääntö lasketaan yhdessä paikassa, näkymässä `payment_settlements`. Tarjoajan tienestit
(`provider_earnings`) ja DAC7-raportti lukevat sitä.

## Seuraukset

- **Toteutettava kantaan:** palvelumaksu prosenttina ja vähimmäismääränä (nykyinen
  `customer_service_fee_cents` on kiinteä summa), palkkion oletus 500 bps (nyt 1000) ja 0 %
  yksityishenkilötekijöille.
- **Palvelun ohittaminen:** käyttäjät saavat sopia uusista töistä palvelun ulkopuolella,
  mutta maksuturva, riitojen käsittely ja arvostelut koskevat vain palvelussa maksettuja
  töitä. Puhelinnumero ja tarkka osoite näytetään vasta, kun tekijä on hyväksynyt tilauksen.
- Alusta raportoi tekijöiden tulot DAC7:n mukaisesti (`admin_dac7_report`).
