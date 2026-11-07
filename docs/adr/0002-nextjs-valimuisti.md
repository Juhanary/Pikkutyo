# ADR 0002: Next.js 16 ilman Cache Components -tilaa (toistaiseksi)

- Tila: hyväksytty
- Päivä: 2026-11-06

## Konteksti

Next.js 16 suosittelee Cache Components -tilaa (`'use cache'`, Partial Prefetching).
Siinä tuntemattomille URL-parametreille tarjoillaan ensin yleinen "App Shell" ja
sisältö päivitetään taustalla. Hakukoneelle ensimmäinen vastaus voi siis olla ilman
kaupunki- tai tarjoajasisältöä, ja `notFound()` Suspense-rajan sisällä palauttaa 200.

## Päätös

Käytetään aiempaa välimuistimallia: `export const revalidate = 3600` sivuilla,
Supabase-haut `fetch`-välimuistissa tageilla (`cities`, `city:<id>`, `providers`,
`provider:<id>`), ja `/api/revalidate` mitätöi tagit heti (`expire: 0`), kun data muuttuu.
Haku (`/haku`) on aina dynaaminen ja `noindex`.

## Seuraukset

- Ensimmäinen pyyntö uuteen kaupunki- tai tarjoajasivuun renderöidään kokonaan
  palvelimella (oikea HTML ja 404-tila), sen jälkeen välimuistista.
- Next.js:n seuraava pääversio tekee Cache Componentsista oletuksen: silloin
  siirrytään ja varmistetaan, että ensimmäinen vastaus sisältää SEO-sisällön.
- Etusivu esirenderöidään buildissa, joten build tarvitsee yhteyden Supabaseen.
- Tilanne 2026-11-06: `/api/revalidate` on valmis, mutta sitä kutsuvaa työntekijää
  (outbox-tapahtumat `provider.changed` ym. → tagit) ei ole vielä tehty. Siihen asti
  muutokset näkyvät sivuilla viimeistään tunnin kuluttua.
