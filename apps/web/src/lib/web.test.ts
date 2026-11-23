import { locales, pathSegments } from "@pikkutyo/i18n";
import en from "@pikkutyo/i18n/messages/en.json";
import fi from "@pikkutyo/i18n/messages/fi.json";
import sv from "@pikkutyo/i18n/messages/sv.json";
import { describe, expect, it } from "vitest";
import { routing } from "@/i18n/routing";
import {
  applicableRequirements,
  documentContentType,
  firstParam,
  isValidBusinessId,
  missingRequirements,
  randomId,
  safeFileName,
  safeNext,
  type ProviderApplication,
} from "./auth";
import { parseFilter } from "./cityPage";
import { addDays, dateFromIso, formatPrice, formatTime, isoDate, isValidIsoDate } from "./format";
import { jsonLdHtml } from "./seo";
import type { District } from "./types";

function keys(obj: object, prefix = ""): string[] {
  return Object.entries(obj).flatMap(([k, v]) =>
    typeof v === "object" && v !== null ? keys(v, `${prefix}${k}.`) : [`${prefix}${k}`],
  );
}

describe("käännökset", () => {
  it("kaikilla kielillä on samat avaimet", () => {
    const base = keys(fi).sort();
    expect(keys(sv).sort()).toEqual(base);
    expect(keys(en).sort()).toEqual(base);
  });
});

describe("reitit", () => {
  it("käännetyt polut vastaavat packages/i18n:n pathSegments-arvoja", () => {
    const p = routing.pathnames;
    for (const l of locales) {
      expect(p["/renkaanvaihto/[city]"][l]).toBe(`/${pathSegments.tireChange[l]}/[city]`);
      expect(p["/tarjoajat/[slug]"][l]).toBe(`/${pathSegments.providers[l]}/[slug]`);
      expect(p["/haku"][l]).toBe(`/${pathSegments.search[l]}`);
      expect(p["/tarjoajaksi"][l]).toBe(`/${pathSegments.becomeProvider[l]}`);
      expect(p["/tarjoajaksi/hakemus"][l]).toBe(`/${pathSegments.becomeProvider[l]}/${pathSegments.application[l]}`);
      expect(p["/kirjaudu"][l]).toBe(`/${pathSegments.signIn[l]}`);
    }
  });
});

describe("kaupunkisivun suodatin", () => {
  const petonen: District = {
    id: "d1",
    code: "petonen",
    name: { fi: "Petonen" },
    providerCount: 3,
    slugs: { fi: "petonen", sv: "petonen", en: "petonen" },
  };

  it("tunnistaa paikan kielittäin", () => {
    expect(parseFilter("kotipihalla", "fi", [])).toEqual({ kind: "location", locationType: "mobile" });
    expect(parseFilter("pa-verkstad", "sv", [])).toEqual({ kind: "location", locationType: "workshop" });
    expect(parseFilter("at-home", "en", [])).toEqual({ kind: "location", locationType: "mobile" });
  });

  it("tunnistaa julkaistun kaupunginosan ja hylkää tuntemattoman", () => {
    expect(parseFilter("petonen", "fi", [petonen])).toEqual({ kind: "district", district: petonen });
    expect(parseFilter("jynkka", "fi", [petonen])).toBeNull();
  });

  it("toisen kielen paikkasegmentti ei kelpaa", () => {
    expect(parseFilter("hemma", "fi", [])).toBeNull();
  });
});

describe("muotoilu", () => {
  it("hinnat euroina", () => {
    expect(formatPrice(3900, "fi")).toMatch(/^39\s€$/);
    expect(formatPrice(4550, "en")).toBe("€45.50");
  });

  it("ajat Helsingin ajassa myös kesäajan vaihtuessa", () => {
    expect(formatTime("2027-03-26T06:00:00Z", "fi")).toBe("08.00");
    expect(formatTime("2027-03-29T05:00:00Z", "fi")).toBe("08.00");
    expect(isoDate(new Date("2026-11-06T22:30:00Z"))).toBe("2026-11-07");
  });
});

describe("JSON-LD", () => {
  it("estää script-tagin katkaisun", () => {
    expect(jsonLdHtml({ name: "</script><b>" }).__html).not.toContain("</script>");
  });
});

describe("päivämäärät", () => {
  it("hylkää mahdottomat päivät", () => {
    expect(isValidIsoDate("2026-02-28")).toBe(true);
    expect(isValidIsoDate("2028-02-29")).toBe(true);
    expect(isValidIsoDate("2026-02-30")).toBe(false);
    expect(isValidIsoDate("2026-13-01")).toBe(false);
    expect(isValidIsoDate("2026-1-01")).toBe(false);
  });

  it("ei hyppää päivän yli kesäaikaan siirryttäessä", () => {
    const days = Array.from({ length: 3 }, (_, i) => addDays("2027-03-27", i));
    expect(days).toEqual(["2027-03-27", "2027-03-28", "2027-03-29"]);
    expect(days.map((d) => isoDate(dateFromIso(d)))).toEqual(days);
  });

  it("vaihtaa kuukauden ja vuoden", () => {
    expect(addDays("2026-12-31", 1)).toBe("2027-01-01");
  });
});

describe("tarjoajahakemus", () => {
  const base: ProviderApplication = {
    id: "a1",
    kind: "individual",
    status: "draft",
    display_name: "Testi",
    business_id: null,
    city_id: "c1",
    district_id: null,
    location_types: ["mobile"],
    description: null,
    tools_description: null,
    contact_email: null,
    contact_phone: null,
    invoicing_service: "ukko",
    invoicing_reference: null,
    identity_verified_at: "2026-11-06T00:00:00Z",
    is_adult: true,
    course_completed_at: "2026-11-06T00:00:00Z",
    terms_accepted_at: "2026-11-06T00:00:00Z",
    rejection_reason: null,
    submitted_at: null,
  };
  const docs = [
    { id: "d1", storage_path: "u/a/tunkki.jpg", kind: "tools" as const },
    { id: "d2", storage_path: "u/a/vakuutus.pdf", kind: "insurance" as const },
  ];

  it("valmis hakemus ei puutu mitään", () => {
    expect(missingRequirements(base, docs)).toEqual([]);
  });

  it("puuttuvat kohdat samoilla koodeilla kuin kannassa", () => {
    expect(missingRequirements({ ...base, terms_accepted_at: null, invoicing_service: "none" }, [docs[0]!])).toEqual([
      "terms",
      "invoicing_service",
      "insurance",
    ]);
    expect(missingRequirements({ ...base, kind: "company" }, docs)).toEqual(["business_id"]);
  });

  it("yritykseltä ei vaadita laskutuspalvelua eikä yksityiseltä Y-tunnusta", () => {
    expect(applicableRequirements("company")).not.toContain("invoicing_service");
    expect(applicableRequirements("individual")).not.toContain("business_id");
  });

  it("Y-tunnuksen tarkiste", () => {
    expect(isValidBusinessId("0112038-9")).toBe(true);
    expect(isValidBusinessId("0112038-8")).toBe(false);
    expect(isValidBusinessId("112038-9")).toBe(false);
  });

  it("paluuosoite vain omalle sivustolle", () => {
    expect(safeNext("/bli-leverantor/ansokan")).toBe("/bli-leverantor/ansokan");
    expect(safeNext("//evil.example")).toBe("/tarjoajaksi/hakemus");
    expect(safeNext("https://evil.example")).toBe("/tarjoajaksi/hakemus");
    expect(safeNext("/\\evil.example")).toBe("/tarjoajaksi/hakemus");
    expect(safeNext(null)).toBe("/tarjoajaksi/hakemus");
    // Selain poistaa sarkaimen ja rivinvaihdon: "/<TAB>/evil" olisi "//evil".
    expect(safeNext("/" + String.fromCharCode(9) + "/evil.example")).toBe("/tarjoajaksi/hakemus");
    expect(safeNext("/" + String.fromCharCode(10) + "/evil.example")).toBe("/tarjoajaksi/hakemus");
    expect(safeNext("/ /evil.example")).toBe("/tarjoajaksi/hakemus");
    // Normalisoinnin jälkeinen "//" ("/.//evil" → "//evil").
    for (const v of ["/.//evil.example", "/a/..//evil.example", "/%2e//evil.example", "/./%2e//evil.example"]) {
      expect(safeNext(v)).toBe("/tarjoajaksi/hakemus");
    }
    expect(safeNext("/sv/logga-in?next=%2F#x")).toBe("/sv/logga-in?next=%2F#x");
  });

  it("hakuparametrin ensimmäinen arvo", () => {
    expect(firstParam(["a", "b"])).toBe("a");
    expect(firstParam("c")).toBe("c");
    expect(firstParam(undefined)).toBeUndefined();
  });

  it("liitteen tyyppi myös ilman selaimen MIME-tyyppiä (HEIC)", () => {
    expect(documentContentType("kuva.HEIC", "")).toBe("image/heic");
    expect(documentContentType("kuva.heif", "image/heif")).toBe("image/heic");
    expect(documentContentType("todistus.pdf", "application/pdf")).toBe("application/pdf");
    expect(documentContentType("virus.exe", "application/x-msdownload")).toBeNull();
    expect(documentContentType("teksti.txt", "")).toBeNull();
    expect(randomId()).toMatch(/^[0-9a-f]{32}$/);
  });

  it("tiedostonimi Storage-polkuun", () => {
    expect(safeFileName("Tunkki ja Pyörä (1).JPG")).toBe("tunkki-ja-pyora-1.jpg");
    expect(safeFileName("../../etc/passwd")).toBe("passwd");
    expect(safeFileName("C:\\fakepath\\kuva.png")).toBe("kuva.png");
    expect(safeFileName("....")).toBe("liite");
  });
});
