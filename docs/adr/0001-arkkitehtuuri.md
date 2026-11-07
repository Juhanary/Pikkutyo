# ADR 0001: Next.js + Flutter + Supabase, logiikka tietokannassa

- Tila: hyväksytty
- Päivä: 2026-11-06

## Konteksti

Nettisivu on tärkein kanava, ja sen pitää näkyä hakukoneissa ("renkaanvaihto kuopio").
Samalla tarvitaan mobiilisovellus asiakkaille ja tarjoajille. Flutterin selainversio
renderöi canvasille, joten hakukoneet eivät näe sen sisältöä hyvin.

## Päätös

- Julkiset sivut, haku ja tarjoajaprofiilit Next.js:llä (SSR/ISR, Vercel fra1).
- Varaus, omat varaukset ja tarjoajan näkymät Flutterilla (iOS, Android, web
  osoitteessa app.vaihdarenkaat.fi). Next.js:n Varaa-nappi on syvälinkki Flutteriin.
- Ylläpito Next.js:n /admin-alueella.
- Supabase eu-central-1 (Frankfurt). Säännöt Postgres-funktioina (RPC), maksut ja webhookit
  Edge Functionsissa.
- Monorepo: npm workspaces + Turborepo (TypeScript), pub workspaces + Melos (Dart).

## Seuraukset

- Kaksi käyttöliittymäteknologiaa. Riski hallitaan pitämällä logiikka tietokannassa
  ja generoimalla tyypit skeemasta.
- Varauksen eheys on tietokannan vastuulla (exclusion constraint), ei sovelluksen.
- Erillinen API-palvelu voidaan lisätä myöhemmin kutsumaan samoja funktioita.
- Siirtymä Next.js:stä Flutter webiin lisää latausaikaa; pito tehdään heti ja
  pudotus mitataan.
