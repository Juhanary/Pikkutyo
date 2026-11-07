// Ajaa supabase/tests/**/*.test.sql -pgTAP-testit etäkantaa vasten ilman Dockeria.
// (`supabase test db` vaatii Dockerin myös --remote-tilassa.)
//
// Käyttö: npm run db:test
// Vaatii .env-tiedostoon SUPABASE_DB_URL:n (Supabase → Connect → Session pooler).
import { readdir, readFile } from "node:fs/promises";
import { join, relative } from "node:path";
import pg from "pg";

const url = process.env.SUPABASE_DB_URL;
if (!url) {
  console.error("SUPABASE_DB_URL puuttuu. Kopioi .env.example → .env ja täytä se.");
  process.exit(2);
}

// TLS: jos Supabasen CA-varmenne on ladattu (Project Settings → Database → SSL),
// varmenne tarkistetaan. Muuten yhteys salataan ilman varmenteen tarkistusta.
const caFile = process.env.SUPABASE_DB_CA_FILE;
const ssl = caFile
  ? { ca: await readFile(caFile, "utf8") }
  : { rejectUnauthorized: false };
if (!caFile) {
  console.warn("Huom: SUPABASE_DB_CA_FILE puuttuu, palvelimen varmennetta ei tarkisteta.\n");
}

async function findTests(dir) {
  const entries = await readdir(dir, { withFileTypes: true });
  const files = [];
  for (const e of entries) {
    const p = join(dir, e.name);
    if (e.isDirectory()) files.push(...(await findTests(p)));
    else if (e.name.endsWith(".sql")) files.push(p);
  }
  return files.sort();
}

function tapLines(results) {
  const list = Array.isArray(results) ? results : [results];
  const lines = [];
  for (const r of list) {
    for (const row of r?.rows ?? []) {
      for (const v of Object.values(row)) {
        if (typeof v === "string") lines.push(...v.split("\n"));
      }
    }
  }
  return lines.filter((l) => /^(not ok|ok|1\.\.\d+|#)/.test(l));
}

const root = join(process.cwd(), "supabase", "tests");
const files = await findTests(root);
const client = new pg.Client({ connectionString: url, ssl });
await client.connect();

let failed = 0;
let passed = 0;
for (const file of files) {
  const name = relative(process.cwd(), file);
  console.log(`# ${name}`);
  const sql = await readFile(file, "utf8");
  try {
    const lines = tapLines(await client.query(sql));
    const plan = Number(lines.find((l) => l.startsWith("1.."))?.slice(3) ?? NaN);
    const oks = lines.filter((l) => l.startsWith("ok")).length;
    const notOks = lines.filter((l) => l.startsWith("not ok")).length;
    for (const l of lines) console.log(l);
    if (notOks > 0 || oks !== plan) {
      failed++;
      console.log(`✗ ${name}: ${oks}/${plan} ok\n`);
    } else {
      passed++;
      console.log(`✓ ${name}: ${oks}/${plan} ok\n`);
    }
  } catch (err) {
    failed++;
    console.log(`✗ ${name}: ${err.message}\n`);
    await client.query("rollback").catch(() => {});
  }
}

await client.end();
console.log(`${passed} tiedostoa läpi, ${failed} epäonnistui`);
process.exit(failed ? 1 : 0);
