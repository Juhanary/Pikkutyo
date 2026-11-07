# ADR 0004: Riitojen ratkaisu – vaihtoehdot

- Tila: **avoin, ei päätetty.** Käydään läpi asiantuntijoiden kanssa (juristi,
  kuluttajansuoja, vakuutus) ennen kuin mitään toteutetaan.
- Päivä: 2026-11-06

## Tavoite

Riidat ratkeavat mahdollisimman pitkälle ilman, että alustan ylläpito joutuu
puuttumaan. Ylläpidolle jäävät vain harvat tapaukset, joissa osapuolet eivät pääse
sopuun.

## Miten toimii nyt

- Asiakas voi reklamoida 24 tunnin kuluessa siitä, kun tekijä merkitsee työn valmiiksi,
  tai 7 päivän kuluessa kuittauksesta. Jos tekijä ei tullut, asiakas voi reklamoida heti
  varatun ajan alettua. Määräajat ovat säädettävissä (`platform_settings`).
- Tekijä voi ilmoittaa, ettei asiakas ollut paikalla (varatun ajan alettua).
- Ennen kuittausta tehty reklamaatio pysäyttää veloituksen (raha on vain varattu).
- Osapuolet voivat kirjoittaa viestejä. Asiakas voi perua reklamaation.
- **Ylläpito ratkaisee jokaisen:** ei toimenpiteitä, osittainen hyvitys tai täysi hyvitys.
- Näyttönä on tekijän tarkistuslista (urasyvyys, renkaiden kunto, paineet, kiristys) ja
  kuvat. Työn jälkeiset kuvat ovat pakollisia; ennen-kuvat ja vauriokuvat ovat
  vapaaehtoisia. Asiakas voi lisätä kuvia reklamaatioon.

## Mahdollisia tapauksia ja vaihtoehtoja

### 1. Tekijä ei tullut

- **Vaihtoehto A:** automaattinen. Jos tekijä ei ole aloittanut työtä esim. 30 minuutin
  kuluessa ja asiakas ilmoittaa, varaus perutaan ja maksuvaraus vapautuu.
- **Vaihtoehto B:** ylläpito tarkistaa (nykyinen).
- Avoimia kysymyksiä: Seuraako tekijälle jotain (varoitus, poisto toistuvista)? Mitä jos
  tekijä on myöhässä mutta tulossa?

### 2. Asiakas ei ollut paikalla

- **Vaihtoehto A:** tekijä ilmoittaa ja ottaa kuvan paikalta, varaus perutaan, asiakas ei maksa.
- **Vaihtoehto B:** asiakkaalta veloitetaan pieni kiinteä maksu tekijälle (matkat ja
  menetetty aika). Pitää kertoa ehdoissa etukäteen.
- Avoimia kysymyksiä: Paljonko maksu olisi? Onko se kuluttajansuojan kannalta kohtuullinen?
  Miten kiistetään, jos asiakas väittää olleensa paikalla?

### 3. Pieni laatuongelma (esim. pultti löysällä, väärä rengaspaine)

- **Vaihtoehto A:** osapuolet sopivat. Tekijällä on 48 tuntia aikaa vastata: korjaan
  ilmaiseksi / tarjoan hyvitystä X € / en ole samaa mieltä. Asiakas hyväksyy tai hylkää.
- **Vaihtoehto B:** pienet hyvitykset (esim. alle 10 €) hyväksytään automaattisesti.
  Väärinkäyttöä rajataan, esim. yksi automaattinen hyvitys per asiakas vuodessa.
- **Vaihtoehto C:** ylläpito ratkaisee (nykyinen).

### 4. Kukaan ei vastaa

- **Vaihtoehto:** määräajat. Jos tekijä ei vastaa 48 tunnissa, asiakkaan pyyntö
  hyväksytään. Jos asiakas ei vastaa tarjoukseen 48 tunnissa, tarjous hyväksytään.
- Huom: koko kulun on mahduttava maksuvarauksen voimassaoloon (Stripessä kortilla noin
  7 päivää), muuten rahaa ei voi enää veloittaa.

### 5. Umpikuja: kumpikaan ei hyväksy

- **Vaihtoehto A:** riidanalainen summa jaetaan automaattisesti puoliksi, ja osapuolille
  kerrotaan jatkokeinot (yritystekijän kanssa kuluttajaneuvonta).
- **Vaihtoehto B:** ylläpito ratkaisee vain nämä.
- Avoimia kysymyksiä: Voiko alusta jakaa rahat ilman harkintaa? Miten yksityisen tekijän
  ja kuluttajan välinen riita eroaa yrityksen ja kuluttajan välisestä?

### 6. Iso vahinko (vanne, auto, henkilövahinko)

- Alusta voi hyvittää enintään asiakkaan maksaman summan.
- Isompi vahinko korvataan tekijän vastuuvakuutuksesta. **Toteutettu:** vakuutusliite on
  pakollinen tarjoajaksi hakiessa.
- Avoimia kysymyksiä: Mikä on vakuutuksen vähimmäistaso? Tarkistetaanko voimassaolo
  vuosittain? Tarvitseeko alusta oman vastuuvakuutuksen?

## Selvitettävät asiat asiantuntijoiden kanssa

- **Alustan rooli:** onko alusta pelkkä välittäjä, vaikka se käsittelee maksut? Mitä
  kuluttajansuojalaki edellyttää, kun tekijä on yritys ja kun tekijä on yksityishenkilö?
- **Ehdot:** voiko käyttöehdoissa sopia, että edellä kuvattu kulku on ensisijainen
  ratkaisutapa?
- **Automaattiset ratkaisut:** saako alusta päättää hyvityksistä sääntöjen perusteella
  ilman ihmistä?
- **Maksut ja aikarajat:** mitä tapahtuu, jos riita kestää pidempään kuin maksuvaraus?
- **Vakuutukset:** tekijän vähimmäisvakuutus ja alustan oma vakuutus.

## Mitä koodissa on valmiina

- Reklamaatiot, viestit, peruutus ja ylläpidon ratkaisu (`open_dispute`,
  `add_dispute_message`, `withdraw_dispute`, `admin_resolve_dispute`).
- Hyvitys maksupalveluun (`supabase/functions/payments-worker`, tapahtuma `dispute.resolved`).
- Suhteellinen hyvitys (ADR 0003).
- Pakollinen vastuuvakuutus hakemuksessa.
