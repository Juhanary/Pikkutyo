# ADR 0007: Alustatyölaki – palvelu pysyy markkinapaikkana, ei työtä organisoivana alustana

- **Tila:** Hyväksytty (juristi vahvistaa lopullisen lain perusteella)
- **Päivämäärä:** 23.11.2026
- **Liittyy:** ADR 0004 (riidat), ADR 0005 (alustan rooli), ADR 0006 (yksityishenkilö tekijänä)

## Konteksti

EU:n alustatyödirektiivi (EU) 2024/2831 pannaan Suomessa täytäntöön alustatyölailla. Hallituksen esitys HE 328/2026 vp annettiin eduskunnalle 5.11.2026. Direktiivin määräpäivä on 2.12.2026. Suomen lain voimaantulopäivää ei ole vielä vahvistettu.

Laki koskee palvelua vain, jos työn organisointi automatisoidulla seuranta- tai päätöksentekojärjestelmällä on palvelun välttämätön ja olennainen osa. Laki koskee myös yrittäjinä toimivia tekijöitä. Jos laki soveltuu, työsuhdeolettama siirtää todistustaakan alustalle. Lisäksi alustalle tulee velvoitteita algoritmisesta johtamisesta, läpinäkyvyydestä ja ihmisen tekemästä valvonnasta.

Lausuntoluonnoksen (TEM 8.7.2026) 2 §:n perustelujen mukaan organisointia ei lähtökohtaisesti ole se, että alusta:

- vain ylläpitää listausta palveluntarjoajista, joista asiakas valitsee vapaasti,
- rajaa näytettäviä tekijöitä vain asiakkaan omilla hakukriteereillä,
- antaa palveluntarjoajien ilmoittaa palveluistaan, tai
- tarjoaa teknisen ajanvarausjärjestelmän.

Organisointia sen sijaan on se, että järjestelmä vertailee asiakasarvioita ja yhdistää tekijöitä asiakkaisiin. Myös arvostelujen avulla tehty seuranta on automaattista seurantaa.

Pikkutyön ilmoitusmallissa tekijä tekee ilmoituksen, asettaa hinnan ja ajat, ja asiakas hakee, valitsee ja varaa itse. Malli on lain ulkopuolella vain, jos alla olevat säännöt pitävät. Sääntöjen pitää näkyä myös koodissa.

## Päätös

Palvelu on itsenäinen markkinapaikka. Seuraavat säännöt ovat pakollisia kaikissa palvelukategorioissa:

1. **Haku ja järjestys.**
   - Hakutulokset rajataan ja järjestetään vain asiakkaan valitsemilla ehdoilla: kategoria, sijainti tai etäisyys, päivä, hinta tai asiakkaan itse valitsema lajittelu.
   - Oletusjärjestys on neutraali, esimerkiksi etäisyys tai lähin vapaa aika.
   - Arvosana ei ole oletusjärjestys.
   - Palvelussa ei ole omaa suosittelu- tai laatupistettä.
2. **Arvostelut ovat tietoa asiakkaille.**
   - Arvostelut näytetään, ja tekijä voi vastata niihin.
   - Arvosana ei automaattisesti vaikuta tekijän näkyvyyteen, varausmahdollisuuteen tai tilin tilaan.
   - Väärinkäytökset ja asiattomat arvostelut käsittelee ihminen erillisessä ilmoitusmenettelyssä (DSA).
3. **Palvelu ei jaa töitä.**
   - Palvelu ei tarjoa, ehdota eikä jaa toimeksiantoja tekijöille.
   - Tekijöille ei lähetetä "uusi keikka lähelläsi" -tarjouksia.
   - Tekijä saa ilmoituksen vain varauksesta, joka koskee hänen omaa ilmoitustaan.
4. **Tekijä päättää omasta työstään.**
   - Tekijä päättää hinnan, ajat ja työtavan ja hyväksyy tilauksen itse.
   - Tekijä voi poistaa aikoja ja ilmoituksia vapaasti.
   - Peruutusehto on sama kaikille työlajeille (24 tuntia, ks. suunnitelma). Jos tekijä saa myöhemmin valita ehdon, hän valitsee valmiista vaihtoehdoista.
5. **Automaattiset rajoitukset ovat läpinäkyviä ja ihmisen tarkistettavissa.**
   - Yksityishenkilön rajat (ADR 0006: 1 500 € samalta asiakkaalta, 3 000 €:n vuosiraja, 10 työtä kuukaudessa ja 2 aktiivista ilmoitusta) ovat ainoat automaattiset rajoitukset, jotka estävät tekijältä uusia varauksia tai ilmoituksia.
   - Rajojen peruste ja tekijän oma tilanne näytetään tekijälle etukäteen, ja 80 %:n kohdalla hän saa ilmoituksen.
   - Tekijä voi pyytää eston ihmisen tarkistettavaksi, ja päätös perustellaan.
6. **Riidat.** Kun palvelu päättää riidan maksusta (ADR 0004), päätöksen tekee ihminen ja perustelee sen. Kyse on maksuriidan ratkaisusta, ei työn johtamisesta.
7. **Tilien sulkeminen ja rajoittaminen** tapahtuu vain ihmisen päätöksellä. Päätös perustellaan (DSA 17 art.).
8. **Tunnistaminen.** Vipps MobilePay Login Advanced täyttää tekijän tunnistamisen. Ehtoihin tulee ohjeistus, ja kohtuuttomista ehdoista voi tehdä ilmoituksen.

### Kategoriakohtainen dokumentointi

Jokaisesta uudesta palvelukategoriasta lisätään alla olevaan taulukkoon rivi ennen julkaisua.

| Kategoria | Kuka löytää | Kuka valitsee tekijän | Kuka hyväksyy | Kuka hinnoittelee | Kuka sopii ajasta | Automaattinen pisteytys / työnjako |
|---|---|---|---|---|---|---|
| Renkaanvaihto | Asiakas haulla | Asiakas | Tekijä julkaisee ajat, asiakas varaa ja tekijä hyväksyy | Tekijä | Tekijä tarjoaa ajat, ja asiakas valitsee | Ei |
| Lumityö | Asiakas haulla | Asiakas | Tekijä julkaisee ajat, asiakas varaa ja tekijä hyväksyy | Tekijä | Tekijä tarjoaa aikaikkunat, ja asiakas valitsee | Ei |

## Seuraukset

- **Hyöty:** palvelu jää perustelujen mukaan alustatyölain ulkopuolelle. Työsuhdeolettamaa ja algoritmisen johtamisen velvoitteita ei sovelleta.
- **Kustannus:** markkinapaikoilla tavallisia ominaisuuksia ei voi käyttää. Tällaisia ovat "parhaat ensin" -oletusjärjestys, suosittelualgoritmi, keikkailmoitukset tekijöille ja arvosanaan perustuva automaattinen esto. Jokainen tällainen ominaisuus vaatii uuden ADR:n ja oikeudellisen arvion.
- **Koodikatselmointi:** muutokset hakuun, järjestykseen, arvosteluihin, ilmoituksiin ja tilien tilaan tarkistetaan tätä ADR:ää vasten.
- **Avoimet kysymykset juristille:**
  - Vahvistaako lopullinen laki ja valiokuntamietintö luonnoksen perustelut?
  - Tarvitaanko vapaaehtoinen selostus järjestelmistä tekijöille?
  - Riittävätkö säännöt 5–7?
  - Voiko palvelu asettaa yhteisen peruutusehdon, vai pitäisikö tekijän valita ehto itse valmiista vaihtoehdoista?

## Lähteet

- Direktiivi (EU) 2024/2831: https://eur-lex.europa.eu/eli/dir/2024/2831/oj
- HE 328/2026 vp: https://data.finlex.fi/fi/hallituksen-esitykset/2026/328
- TEM:n lausuntoluonnos HE:ksi alustatyölaiksi (8.7.2026), 2 §:n perustelut noin s. 65–66: https://api.hankeikkuna.fi/asiakirjat/de2f6fa4-12b6-4a8a-bcdb-11cd75287879/78b4dfef-0341-49ab-8853-da396460efc8/KIRJE_20260709045413.PDF
- Suomen Yrittäjät, lausunto valiokunnalle 10.11.2026: https://www.yrittajat.fi/ajankohtaista/lausunnot/lausunto-hallituksen-esityksesta-alustatyolaiksi/
