# ADR 0005: Alustan rooli ja tekijöiden käyttäjäryhmät

- Tila: ehdotus, tarkistetaan juristilla ennen julkaisua.
- Päivä: 2026-11-17

## Lyhyesti

Alusta on välittäjä. Asiakas ja tekijä tekevät toimeksiantosopimuksen keskenään, ja
alusta tarjoaa haun, viestinnän, sopimuksen tallennuksen ja maksun. Alusta ei jaa töitä,
ei hinnoittele yksittäisiä töitä eikä ohjaa tekijän työaikaa tai työtapaa.

Tekijöitä on kolmea tyyppiä: **yritys**, **toiminimi** ja **yksityishenkilö** (ADR 0006). Kullakin
on oma rekisteröitymispolkunsa ja omat vero- ja kuluttajansuojavelvoitteensa.

## Konteksti

- **Alustatyölaki** (HE 328/2026 vp) on tarkoitettu tulemaan voimaan 2.12.2026. Laki
  koskee alustoja, joissa työn organisointi automatisoidulla järjestelmällä on palvelun
  olennainen osa. Jos työn olosuhteista ilmenee johtamista ja valvontaa, suhde oletetaan
  työsuhteeksi, ja alustan on näytettävä, ettei se ole.
- Esitysluonnoksen perusteluissa (heinäkuu 2026) alusta ei organisoi työtä, kun asiakas
  valitsee tekijän vapaasti, tekijä valitsee asiakkaansa tai alusta vain tarjoaa
  ajanvarauksen. Organisointia on esimerkiksi tehtävien jakaminen ja yksittäisten
  toimeksiantojen hinnoittelu.
- Olettamaa puoltavat esimerkiksi työajan tai työpaikan määrääminen, sitovat
  työtapaohjeet, yksinoikeus tai kilpailukielto ja rankaisut.
- Haun, arvostelujen, automaattisten rajoitusten ja tilien rajoittamisen tarkat säännöt ovat
  ADR 0007:ssä.

## Päätös: tuotesäännöt

| Osa-alue | Sallittu | Ei tehdä |
|---|---|---|
| Töiden jako | Asiakas valitsee tekijän. Tekijä valitsee, mihin tarjoaa. | Algoritmi osoittaa työn tekijälle. |
| Hinta | Tekijä asettaa hinnan. Alusta voi näyttää ohjeellisen haarukan. Alustan oma palvelumaksu lisätään eriteltynä. | Alusta laskee työn hinnan, jota tekijä ei voi muuttaa, tai rajoittaa hinnan muuttamista. |
| Työaika | Tekijä julkaisee omat vapaat aikansa ja hyväksyy tai hylkää tilauksen. | Vuorot, minimisaatavuus, "ole online". |
| Työtapa | Asiakkaan ja tekijän sopima tehtäväkuvaus. Tarkistuslista ja kuvat näyttönä. | Pakolliset työohjeet, alustan asut, työn aikainen seuranta. |
| Arvostelut | Molemmat arvioivat toisensa. Arvosana ei vaikuta automaattisesti näkyvyyteen, varauksiin tai tiliin (ADR 0007). | Automaattinen sulkeminen keskiarvon perusteella, näkyvyyden pudotus kieltäytymisistä. |
| Sanktiot | Tilin rajoitus vain lainvastaisesta tai vahingollisesta toiminnasta, perusteltuna ja muutoksenhakumahdollisuudella. | Sakot, pidätetyt palkkiot tai tasot tehtyjen töiden mukaan. |
| Yksinoikeus | Tekijä saa toimia muuallakin. | Kilpailukielto. |
| Riidat | Alusta välittää viestit. Jos sopua ei synny, ihminen päättää palvelussa olevasta maksusta ja perustelee päätöksen. Päätös ei estä viemästä asiaa kuluttajariitalautakuntaan tai tuomioistuimeen. | Alusta arvioi työn laadun ja määrää korjaamaan. |

Varausmalli on ilmoitusmalli: tekijä tekee ilmoituksen, asettaa hinnan ja lisää useita
päiviä ja aikoja, ja eri asiakkaat varaavat niistä sopivan. Tekijä hyväksyy tilauksen.
Aiemmin harkittu "tehtävä + tarjoukset" -malli jätettiin pois.

## Päätös: kolme tekijäryhmää

| | Yritys (Oy, Ky, osuuskunta) | Toiminimi tai kevytyrittäjä | Yksityishenkilö (ADR 0006) |
|---|---|---|---|
| Sopimus | Palvelusopimus asiakkaan kanssa | Palvelusopimus asiakkaan kanssa | Toimeksianto: tekijä on itsenäinen, asiakas maksaa työkorvausta |
| Tunniste | Y-tunnus | Y-tunnus | Henkilötunnus (Vipps MobilePay Login Advanced) |
| Kuluttajansuoja | Tekijä on elinkeinonharjoittaja | Tekijä on elinkeinonharjoittaja | Yksityishenkilö myy palvelun kuluttajalle. Välittäjän vastuu (KSL 12:1) on juristin kysymys. |
| Alustan maksut | Asiakkaalta 10 % (väh. 2,99 €), tekijältä 5 % + ALV | Asiakkaalta 10 % (väh. 2,99 €), tekijältä 5 % | Vain asiakkaalta 10 % (väh. 2,99 €) |
| Verot ja ilmoitukset | Tekijä itse | Tekijä itse | Tekijä ilmoittaa tulon itse. Asiakas ilmoittaa työkorvauksen tulorekisteriin itse; palvelu kertoo velvollisuudesta ohjeissa |
| DAC7 | Raportoidaan | Raportoidaan | Raportoidaan (rajat varmistetaan Verohallinnolta) |
| Kotitalousvähennys 2026 | 40 % työn osuudesta | 40 % työn osuudesta | Ei vähennystä |
| Pilotissa | Kyllä | Kyllä | Kyllä |

## Seuraukset

- **Tietokanta:** `provider_kind` on nyt `company | individual`. Se muutetaan muotoon
  `company | sole_trader | private_person`. Y-tunnus vaaditaan yrityksiltä ja toiminimiltä.
  Laskutuspalveluvaatimus (`invoicing_service`) poistetaan, koska yksityishenkilöt toimivat
  toimeksiantona (ADR 0006). Hakemuksen vaatimukset (`submit_provider_application`) ja
  käännökset päivitetään samalla.
- **Kuluttajalle näytetään** tekijän tyyppi hakutuloksessa ja ennen varausta: kuka on
  palveluntarjoaja, onko hän elinkeinonharjoittaja ja kenelle vaatimukset esitetään.
  Silloin alustalle ei synny välittäjän vastuuta yritysten ja toiminimien töistä (KSL 12:1).
- **Peruuttamisoikeus (KSL 6:16, 6:19):** kun tekijä on elinkeinonharjoittaja, varauksessa on
  kaksi erillistä, valmiiksi valitsematonta suostumusta: työn aloittaminen
  peruuttamisaikana ja oikeuden menetys, kun työ on kokonaan tehty. Myöhäisen peruutuksen
  maksua ei voi periä ennen työn alkua.
- **Reklamaatio:** 48 tunnin ilmoitusaika koskee vain maksun tilitystä, ei asiakkaan
  lakisääteisiä oikeuksia.
- **Käyttöehdot:** luonnokset ovat dokumentissa "Pikkutyö – käyttöehdot, tietosuoja ja tuki".
  Juristi tarkistaa ne ennen julkaisua.
- **Ei hakemuksen hyväksyntää:** tekijä (18+) voi tarjota sallittua työtä heti, kun on
  tunnistautunut. Kielletyt työt poistetaan valvonnassa jälkikäteen. Mahdolliset
  kategoriakohtaiset vaatimukset ovat pätevyyksien tarkistuksia, eivät työtapaohjeita.
