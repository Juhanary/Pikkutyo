# ADR 0006: Yksityishenkilö tekijänä – toimeksianto ja työkorvaus

- Tila: ehdotus. Juristi ja Verohallinto vahvistavat ennen julkaisua.
- Päivä: 2026-11-17 (korvaa aiemman palkkamallin, jossa sovellus ilmoitti palkat
  kotitalouden puolesta)

## Lyhyesti

Yksityishenkilö voi tehdä pikkutöitä ilman Y-tunnusta ja laskutuspalvelua. Hän tekee työn
itsenäisesti toimeksiantona, ja asiakas maksaa hänelle työkorvausta. Asiakas ei ole
työnantaja. Palvelu toimii kuten Tori: käyttäjät vastaavat omista vero- ja
ilmoitusvelvollisuuksistaan, ja palvelu kertoo niistä ehdoissa ja ohjeissa. Palvelu ei tee
ilmoituksia tulorekisteriin, ei käytä Suomi.fi-valtuuksia eikä näytä tekijän henkilötunnusta
asiakkaalle. Tekijä saa vuosikoosteen tuloistaan.

## Konteksti

- Työsuhde vai toimeksianto ratkeaa sen mukaan, miten työ tosiasiassa tehdään. Työsuhteeseen
  viittaa, että teettäjä määrää milloin, miten ja missä työ tehdään, hankkii tarveaineet ja
  tekijä ei voi käyttää sijaista.
- Kun yksityishenkilö (Verohallinnon termein kotitalous) maksaa työkorvausta henkilölle, joka
  ei ole ennakkoperintärekisterissä, maksu ilmoitetaan tulorekisteriin. Ennakonpidätys
  tehdään vasta, kun samalle tekijälle maksetaan yli 1 500 € kalenterivuodessa. Työkorvauksesta
  ei makseta TyEL- eikä sairausvakuutusmaksuja.
- Yksityishenkilön tekemästä työstä ei saa kotitalousvähennystä.
- Lähde: vero.fi, "Ostitko palvelun ja maksoit laskulla?" ja "Kotitalous työn teettäjänä".

## Päätös

1. Tekijätyyppi `private_person` tekee töitä toimeksiantona. Palvelun säännöt tukevat
   itsenäisyyttä: tekijä asettaa hinnan, päättää työtavan, käyttää omia välineitään, sopii
   ajan ikkunana ja saa käyttää apulaista.
2. Sama asiakas voi maksaa samalle yksityishenkilölle enintään 1 500 € vuodessa. Sovellus
   estää ylityksen.
3. Tekijän vuosiraja on 3 000 € (selvästi YEL-rajan 9 423 € ja ALV-rajan 20 000 € alapuolella).
   Sen jälkeen sovellus ohjaa kevytyrittäjäksi tai toiminimeen.
4. Ehdoissa ja ohjeissa kerrotaan asiakkaan velvollisuudesta ilmoittaa työkorvaus
   tulorekisteriin. Tekijän henkilötunnusta ei luovuteta asiakkaalle. Tekijä saa vuoden lopussa koosteen
   tuloistaan.
5. Yksityishenkilöltä ei peritä palkkiota alussa. Tämä on liiketoimintapäätös: toimeksianto ei
   ole työnvälitystä, joten maksukielto ei koske sitä.
6. Tekijän on oltava täysi-ikäinen: Stripe Connectin Express- ja Custom-tilit vaativat 18 vuotta.
7. Tekijä asettaa hinnan ilmoitusta tehdessään. Asiakas näkee hakutuloksissa kokonaishinnan,
   ja ennen tilausta työn hinta ja palvelumaksu eritellään.
8. Tekijän henkilötunnusta ei luovuteta asiakkaalle, vaikka asiakas sitä pyytäisi.
9. Ilmoitukseen lisätään useita päiviä ja aikoja, joista eri asiakkaat varaavat. Ammattimaisuuden
   rajat yksityishenkilölle: enintään 10 työtä kuukaudessa ja 2 aktiivista ilmoitusta. Yksityishenkilönä
   ei voi toimia, jos on Y-tunnus, ilmoituksessa on yrityksen nimi tai logo, työssä käytetään
   ammattikalustoa, on palkattuja apulaisia tai työ on pääasiallinen toimeentulo.
10. 80 % euro- tai työmäärärajasta: ilmoitus ja ohje kevytyrittäjyydestä (UKKO.fi, Omapaja ym.)
    tai toiminimestä. 100 %: uusia varauksia ei yksityishenkilönä; tekijäryhmän vaihto säilyttää
    ilmoitukset, kalenterin ja arvostelut. Esto on automaattinen päätös: peruste näytetään
    tekijälle etukäteen, ja hän voi pyytää ihmisen tarkistuksen (ADR 0007).
11. Kaikki käyttäjät kirjautuvat Vipps MobilePay Login Advancedilla (60 €/kk alle 1 000
    aktiiviselle käyttäjälle, 150 €/kk 1 001–10 000). Advanced antaa henkilötunnuksen, jota
    tarvitaan tekijän DAC7-tietoihin. Henkilötunnusta kerätään vain tekijöiltä. Basic (30 €/kk)
    + FTN tekijöille hylättiin, koska kaksi järjestelmää on monimutkaisempi.

## Avoimet kysymykset

- Juristi: riittävätkö 3 000 €:n vuosiraja ja 10 työn kuukausiraja pitämään toiminnan
  satunnaisena.
- Juristi: riittävätkö säännöt tekemään työstä toimeksiannon, ja syntyykö palvelulle
  välittäjän vastuu (KSL 12:1), kun yksityishenkilö myy palvelun kuluttajalle.
- Juristi: riittääkö, että palvelu kertoo asiakkaan ilmoitusvelvollisuudesta ehdoissa ja
  ohjeissa. Suomi.fi-valtuutusta ja tulorekisterin rajapintaa ei rakenneta (liian raskas).
- Verohallinto: tulkinta toimeksiannosta ja DAC7-raportoinnin rajat palveluille.
- Juristi: onko henkilötunnuksen keräämiselle tekijöiltä riittävä peruste (DAC7 ja
  tietosuojalaki).
