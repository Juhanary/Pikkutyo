# Pikkutyö

Pikkutöiden markkinapaikka (ent. Kausityö ja Vaihdarenkaat; ilman ääkkösiä `pikkutyo`).
Asiakas löytää tekijän pikkutyöhön ja maksaa sen turvallisesti sovelluksessa. Palvelu on
välittäjä: asiakas valitsee tekijän, tekijä päättää hinnan, ja palvelu hoitaa haun, maksun ja
luottamuksen. Ensimmäiset työt ovat lumityö ja renkaanvaihto, pilottikaupunki Kuopio.
Myöhemmin mukaan tulevat muut pikkutyöt, joita saa tehdä ilman lupia.

Tekijät voivat olla yrityksiä, toiminimiä, kevytyrittäjiä tai yksityishenkilöitä
(`docs/adr/0005-alustan-rooli-ja-kayttajaryhmat.md`). Yksityishenkilö tekee työn
toimeksiantona ilman Y-tunnusta (`docs/adr/0006-yksityishenkilo-tekijana.md`). Palvelu pysyy
markkinapaikkana eikä organisoi työtä (alustatyölaki, `docs/adr/0007-alustatyolaki-markkinapaikkamalli.md`).

Suunnitelma: [Pikkutyö – suunnitelma](https://claude.ai/artifact/5ySwBGieRGePNqJqmpC8Xt).
Jos tämä tiedosto ja suunnitelma ovat ristiriidassa, suunnitelma on voimassa.
Tekniset päätökset ovat kansiossa `docs/adr/`.

## Tila (23.11.2026)

**Toimii ja on testattu**

- Sivuston yksikkötestit (19) ja tyyppitarkistus menevät läpi.
- Maksumoduulien testit (9) menevät läpi (`node --experimental-strip-types --test supabase/functions/_shared/*.test.ts`).
- Flutter-sovelluksen runko: `flutter analyze` ilman huomioita ja 12 testiä läpi
  (`apps/app`, alustakansiot android/ios/web tehty).
- Sivusto: etusivu, haku, kaupunkisivut suodattimineen, tarjoajan profiilisivu,
  "Tarjoajaksi"-sivu, tarjoajahakemus liitteineen ja kirjautuminen sähköpostilinkillä.
- Tietokanta: varaukset ja vapaat ajat, työn kulku ja kuittaus, Stripe Connect -maksut
  (oletuksena testimaksut), reklamaatiot, ilmoitusjono, tarjoajahakemukset, DAC7-raportti
  ja ajastetut työt. pgTAP-testit ajetaan komennolla `npm run db:test` dev-kantaa vasten.

**Seuraavat askeleet järjestyksessä** (suunnitelman kohta "Rakennus")

1. Kategoriat (lumityö, renkaanvaihto) ja ilmoitus, johon tekijä lisää hinnan sekä useita
   päiviä ja aikoja, joista asiakkaat varaavat.
2. Flutter-sovellus (`apps/app`, iOS, Android ja web, ADR 0001): kirjautuminen, haku, ilmoitus ja
   varaus. Runko, alustakansiot sekä kieli- ja ulkoasuvalinta on tehty
   (`apps/app/README.md`); kategoriat, tekijän näkymät ja maksuvirta (askel 7) tehdään siihen.
3. Tarjoajahakemuksen hyväksyntä poistetaan, jotta tekijä voi tarjota työtä heti. Ikäraja
   18 vuotta tarkistetaan tunnistautumisessa.
4. Tekijätyypit (`company | sole_trader | private_person`) ja ansioseuranta: 1 500 €
   samalta asiakkaalta, tekijän 3 000 €:n vuosiraja, 10 työtä kuukaudessa, 2 aktiivista
   ilmoitusta, 80 %:n varoitus ja ohjaus yritykseksi (ADR 0006).
5. Ansaintamalli kantaan: palvelumaksu 10 % (väh. 2,99 €), palkkio 5 % tai 0 % (ADR 0003).
6. Työn kuittaus kuvalla sekä riitamalli: 48 tunnin ilmoitusaika ja 7 päivän sopimisaika
   (koodissa nyt 24 h, ADR 0004).
7. Maksuvirta: maksutapa (kortti, Apple Pay tai Google Pay) pakollinen ennen tilausta,
   varaus automaattisesti 24 tuntia ennen työtä (alle 24 tunnin tilauksissa heti), 6 tunnin
   aika maksutavan vaihtoon, veloitus 48 tuntia kuittauksen jälkeen, Stripen automaattiset
   tilitykset ja 24 tunnin peruutusmaksu yksityishenkilötekijöille. Peruutusehto tallennetaan
   tilaukseen arvoina (tunnit ja prosentti).
8. Puhelinnumero ja tarkka osoite piilotetaan, kunnes tekijä hyväksyy tilauksen.
9. Asiakkaalle ohje ilmoitusvelvollisuudesta ja tekijälle vuosikooste. Henkilötunnusta ei
   näytetä asiakkaalle.
10. DAC7-tiedot tekijöiltä.
11. Käyttöehdot, säännöt, tietosuojaseloste, evästeet, turvalliset kaupat ja asiakastuki
    sivustolle. Luonnokset: [Pikkutyö – käyttöehdot, tietosuoja ja tuki](https://claude.ai/artifact/FoFPwnuectnGwRyDB6F6e6).
    Juristi tarkistaa ennen julkaisua.
12. Sähköpostilinkkikirjautuminen vaihdetaan Vipps MobilePay Login Advanced -kirjautumiseen.
13. ADR 0007:n säännöt: neutraali oletusjärjestys, arvosanat eivät vaikuta automaattisesti
    ja rajojen estoon voi pyytää ihmisen tarkistuksen.

Myöhemmin: `/admin` ja ilmoitusten ja sivuston revalidoinnin
työntekijät (niiden tapahtumat odottavat jonossa).

## Rakenne

```
apps/web/            Next.js: julkinen sivusto, kaupunkisivut, haku, tarjoajasivut
                     (/admin tulossa)
apps/app/            Flutter: asiakas + tarjoaja, iOS, Android ja web (runko ja alustat tehty)
packages/db-types/   Supabasesta generoidut TypeScript-tyypit
packages/i18n/       kielet, käännetyt URL-polut, käännökset (fi, sv, en)
supabase/            migraatiot, siemendata, pgTAP-testit, Edge Functions
docs/adr/            arkkitehtuuri- ja liiketoimintapäätökset
```

Säännöt (vapaat ajat, pito, vahvistus, työn kulku, maksujen määräajat, reklamaatiot)
ovat Postgres-funktioissa. Next.js ja Flutter kutsuvat samoja RPC-funktioita eivätkä laske
hintoja tai aikoja itse. Maksupalvelun kutsut tehdään Edge Functionsissa.

## Vaatimukset

- Node 22+ ja npm
- Flutter (vain `apps/app`, ks. `apps/app/README.md`)
- Supabase-projektit alueella eu-central-1 (dev ja prod)

Paikallinen kehitys ei vaadi Dockeria: se tehdään pilven dev-projektia vasten.
GitHubin CI (`.github/workflows/db.yml`) ajaa migraatiot ja pgTAP-testit paikallisessa
Supabasessa, jossa Docker on valmiina.

## Aloitus

```bash
npm install
npx supabase login
npm run db:link        # valitse dev-projekti
npm run db:push        # migraatiot dev-kantaan
npm run db:seed        # TYHJENTÄÄ dev-kannan ja ajaa siemendatan (vain dev!)
cp .env.example .env   # täytä avaimet ja SUPABASE_DB_URL (Session pooler)
npm run db:test        # pgTAP-testit ilman Dockeria (scripts/db-test.mjs)
npm run db:types       # generoi packages/db-types/src/database.ts
npm run dev            # sivusto osoitteessa http://localhost:3000
```

`db:seed` ajaa `supabase db reset --remote`, joka poistaa kaiken datan linkitetystä
projektista. Älä koskaan linkitä tuotantoprojektia samalla koneella ilman tarkistusta.

Muut tarkistukset: `npm run typecheck`, `npm test` (sivuston yksikkötestit) ja
`node --test supabase/functions/_shared/*.test.ts` (maksumoduulit).

## Tietokanta

### RPC-funktiot

Virheet palautetaan koodilla `P0001` ja koneluettavalla viestillä
(`slot_unavailable`, `too_many_holds`, `hold_expired`, `contact_required`, ...).

**Haku ja varaus**

| Funktio | Kuka kutsuu | Mitä tekee |
| --- | --- | --- |
| `search_providers` | anon, kirjautunut | Kaupungin tarjoajat, hinnat, etäisyys ja vapaat ajat päivälle |
| `get_available_slots` | anon, kirjautunut | Vapaat aloitusajat (15 min ruudukko), enintään 31 päivää kerralla |
| `hold_slot` | kirjautunut (myös anonyymi) | Pitää ajan 10 min, enintään 2 pitoa per käyttäjä. Lukitsee hinnan ja palkkion |
| `extend_hold` | kirjautunut | Jatkaa pitoa kerran 10 min |
| `confirm_booking` | kirjautunut | Pito → vahvistettu, yhteystiedot, maksun eräpäivä |
| `cancel_booking` | asiakas tai tarjoaja | Peruu ennen alkua |

**Työn kulku ja arvostelu**

| Funktio | Kuka kutsuu | Mitä tekee |
| --- | --- | --- |
| `start_job` | tarjoaja | Vahvistettu → työ käynnissä |
| `save_checklist_item` | tarjoaja | Tarkistuslistan kohta (urasyvyys, kunto, paineet, kiristys, jälkeen-kuvat) |
| `register_booking_photo` | tarjoaja, asiakas | Storageen ladatun kuvan kirjaus varaukseen (tarjoaja työn aikana, asiakas reklamaatiota varten) |
| `complete_job` | tarjoaja | Työ valmis, vaatii tarkistuslistan. Asiakkaalla on 24 h aikaa kuitata tai reklamoida |
| `confirm_job_completion` | asiakas | Kuittaus, joka käynnistää veloituksen |
| `submit_review` | asiakas | Arvostelu kuitatusta työstä (30 päivän sisällä) |

**Reklamaatiot** (ks. `docs/adr/0004-riitojen-ratkaisu.md`)

| Funktio | Kuka kutsuu | Mitä tekee |
| --- | --- | --- |
| `open_dispute` | asiakas tai tarjoaja | Avaa reklamaation. Ennen kuittausta pysäyttää kuittauksen ja veloituksen |
| `add_dispute_message` | osapuolet | Viesti reklamaatioon |
| `withdraw_dispute` | avaaja | Peruu reklamaation, jolloin varaus jatkuu |
| `admin_resolve_dispute` | ylläpito | Ei toimenpiteitä, osittainen tai täysi hyvitys |

**Tarjoajaksi hakeminen ja ylläpito**

| Funktio | Kuka kutsuu | Mitä tekee |
| --- | --- | --- |
| `accept_provider_terms` | hakija | Ehtojen hyväksyntä luonnokseen |
| `submit_provider_application` | hakija | Lähettää hakemuksen. Vaatii tunnistuksen, kurssin, välinekuvat ja vastuuvakuutuksen |
| `admin_review_application` | ylläpito | Hyväksyy (syntyy odottava tarjoaja) tai hylkää |
| `admin_set_provider_status` | ylläpito | Julkaisee, keskeyttää tai palauttaa tarjoajan |
| `admin_dac7_report` | ylläpito | Verottajan DAC7-vuosiraportti |

**Muut**

| Funktio | Kuka kutsuu | Mitä tekee |
| --- | --- | --- |
| `register_device` | kirjautunut | Push-tokenin rekisteröinti (token siirtyy uudelle käyttäjälle) |
| `worker_claim_outbox_events`, `worker_complete_outbox_event` | Edge Functions (secret-avain) | Tapahtumajonon käsittely |

### Ajastetut työt (pg_cron)

| Työ | Väli | Mitä tekee |
| --- | --- | --- |
| `private.expire_holds` | 1 min | Vanhentuneet pidot |
| `private.auto_complete_jobs` | 5 min | Automaattinen kuittaus, jos asiakas ei kuittaa eikä reklamoi |
| `private.enqueue_reminders` | 15 min | Varaus- ja jälkikiristysmuistutukset jonoon |
| `private.enforce_payment_deadlines` | 15 min | Maksupyynnöt ja maksamattomien varausten peruutus (vain kun maksut ovat käytössä) |
| `private.cleanup_outbox` | päivittäin | Yli 30 päivää vanhat käsitellyt tapahtumat |
| `private.invoke_payments_worker` | 1 min | Kutsuu maksutyöntekijää (vain kun maksut ovat käytössä ja Vaultissa on osoite) |

Ajastukset luodaan vain, jos pg_cron on käytössä. Muuten migraatio ohittaa ne.

### Periaatteet

- Apufunktiot ovat `private`-skeemassa, joka ei näy Data API:ssa. `public`-skeemassa
  security definer -funktioina ovat vain yllä listatut RPC:t. Testi `001_schema_rls`
  tarkistaa listan.
- Taulujen ja funktioiden oikeudet annetaan eksplisiittisesti `GRANT`-lauseilla. Uusi taulu
  tai funktio ei näy rajapinnassa ilman omaa grantia.
- Kaksoisvaraus on estetty tietokantatasolla (`bookings_no_overlap`, exclusion constraint).
- Varauksen palkkio on omassa taulussaan (`booking_commissions`), jota asiakas ei näe.
  Samasta syystä `payments.application_fee_cents` ei ole asiakkaan luettavissa: maksurivejä
  luettaessa sarakkeet on listattava (`select=*` ei toimi).
- Muutokset (varauksen tila, reklamaatiot, hakemukset) kirjataan samassa transaktiossa
  `outbox_events`-jonoon, ja Edge Functions käsittelee sen. Maksutyöntekijä on tehty.
  Ilmoitusten ja sivuston revalidoinnin työntekijät puuttuvat vielä, joten niiden tapahtumat
  odottavat jonossa.
- Kaupunginosasivu julkaistaan, kun alueella on vähintään 3 aktiivista tarjoajaa
  (`published_districts`).

## Kirjautuminen ja tarjoajahakemus

Sivustolla kirjaudutaan sähköpostiin tulevalla linkillä (Supabase Auth, PKCE). Linkki palaa
osoitteeseen `/api/auth/callback`, ja sessio on evästeissä (`@supabase/ssr`). `proxy.ts`
päivittää session vain kirjautuneille, joten julkiset sivut eivät tee ylimääräisiä kutsuja.

Tarjoajahakemus on osoitteessa `/tarjoajaksi/hakemus`: perustiedot, liitteet (välinekuvat ja
vastuuvakuutus Storageen), ehdot ja lähetys. Vahva tunnistus ja verkkokurssi eivät ole vielä
kytkettyinä. Testatessa ne voi merkitä tehdyiksi, kun `.env`-tiedostossa on
`ALLOW_TEST_SHORTCUTS=true`.

Supabasen asetukset (Authentication → URL Configuration): Site URL ja sallitut paluuosoitteet
`supabase/config.toml`-tiedoston mukaan (esim. `http://localhost:3000/**`). Ilman niitä linkki
palaa sivuston juureen, josta `proxy.ts` ohjaa sen oikein, mutta paluusivu jää pois.

## Maksut

Maksut tehdään Edge Functionsilla (`supabase/functions/`, ohjeet sen README:ssä).
Oletuksena käytössä on testimaksupalvelu, jolloin raha ei liiku. Pilotissa maksut ovat
pois päältä (`platform_settings.payments_enabled = false`), eikä varauksia peruta maksun
puuttuessa. Ansaintamalli ja hyvitysten jako: `docs/adr/0003-ansaintamalli.md`.

## Siemendata

`supabase/seed.sql` sisältää Kuopion ja 15 kuvitteellista tarjoajaa ("Esimerkki"-nimet).
Kaupunginosien koordinaatit ovat likimääräisiä, ja postinumeroilla on toistaiseksi
kaupungin keskipiste. Siemendataa ei ajeta tuotantoon.
