// Kirjautumisen ja tarjoajahakemuksen yhteiset apufunktiot (ilman Supabase-riippuvuuksia,
// joten ne voi testata yksikkötesteillä).
import { isLocale, type Locale } from "@vaihdarenkaat/i18n";
import type { LocationType, ProviderKind } from "./types";

/** Ehtojen versio, jonka hakija hyväksyy. Muuta, kun ehdot muuttuvat. */
export const TERMS_VERSION = "2026-11-1";

/**
 * Hyväksyy vain saman sivuston polun ("/..."), ei ulkoista osoitetta ("//evil", "https://...").
 * Selaimen URL-jäsennin poistaa sarkaimet ja rivinvaihdot (esim. "/<TAB>/evil" → "//evil"), joten
 * ohjausmerkit, välilyönnit ja kenoviivat hylätään, ja lopuksi polku jäsennetään kuten selain.
 */
export function safeNext(value: string | null | undefined, fallback = "/tarjoajaksi/hakemus"): string {
  if (!value || !value.startsWith("/") || value.startsWith("//")) return fallback;
  // Ohjausmerkit (0x00–0x1f, 0x7f), välilyönti ja kenoviiva.
  if (/[\x00-\x1f\x7f \\]/.test(value)) return fallback;
  const base = "https://vaihdarenkaat.invalid";
  try {
    const url = new URL(value, base);
    if (url.origin !== base) return fallback;
    return `${url.pathname}${url.search}${url.hash}`;
  } catch {
    return fallback;
  }
}

/** Ensimmäinen arvo hakuparametrista (?a=1&a=2 → "1"). */
export function firstParam(value: string | string[] | undefined): string | undefined {
  return Array.isArray(value) ? value[0] : value;
}

/** Lomakkeen kieli; tuntematon arvo → suomi. */
export function localeOf(formData: FormData): Locale {
  const value = String(formData.get("locale") ?? "");
  return isLocale(value) ? value : "fi";
}

export type ApplicationStatus = "draft" | "submitted" | "in_review" | "approved" | "rejected" | "withdrawn";
export type InvoicingService = "none" | "ukko" | "eezy" | "other";
export type DocumentKind = "tools" | "insurance" | "other";

export interface ProviderApplication {
  id: string;
  kind: ProviderKind;
  status: ApplicationStatus;
  display_name: string;
  business_id: string | null;
  city_id: string;
  district_id: string | null;
  location_types: LocationType[];
  description: string | null;
  tools_description: string | null;
  contact_email: string | null;
  contact_phone: string | null;
  invoicing_service: InvoicingService;
  invoicing_reference: string | null;
  identity_verified_at: string | null;
  is_adult: boolean | null;
  course_completed_at: string | null;
  terms_accepted_at: string | null;
  rejection_reason: string | null;
  submitted_at: string | null;
}

export interface ApplicationDocument {
  id: string;
  storage_path: string;
  kind: DocumentKind;
}

/** Lähetyksen vaatimukset samassa järjestyksessä ja samoilla koodeilla kuin submit_provider_application. */
export const REQUIREMENTS = [
  "location_types",
  "identity",
  "adult",
  "course",
  "terms",
  "business_id",
  "invoicing_service",
  "tools_photos",
  "insurance",
] as const;
export type Requirement = (typeof REQUIREMENTS)[number];

/** Puuttuvat kohdat. Sama logiikka kuin kannassa, jotta käyttäjä näkee ne ennen lähetystä. */
export function missingRequirements(app: ProviderApplication, docs: ApplicationDocument[]): Requirement[] {
  const missing: Requirement[] = [];
  if (app.location_types.length === 0) missing.push("location_types");
  if (!app.identity_verified_at) missing.push("identity");
  if (app.is_adult !== true) missing.push("adult");
  if (!app.course_completed_at) missing.push("course");
  if (!app.terms_accepted_at) missing.push("terms");
  if (app.kind === "company" && !app.business_id) missing.push("business_id");
  if (app.kind === "individual" && app.invoicing_service === "none") missing.push("invoicing_service");
  if (!docs.some((d) => d.kind === "tools")) missing.push("tools_photos");
  if (!docs.some((d) => d.kind === "insurance")) missing.push("insurance");
  return missing;
}

/** Vaatimukset, jotka koskevat tätä hakijaa (Y-tunnus vain yrityksille, laskutuspalvelu vain yksityisille). */
export function applicableRequirements(kind: ProviderKind): Requirement[] {
  return REQUIREMENTS.filter((r) =>
    r === "business_id" ? kind === "company" : r === "invoicing_service" ? kind === "individual" : true,
  );
}

/** Tiedostonimi Storage-polkuun: vain turvalliset merkit, pituus rajattu. */
export function safeFileName(name: string): string {
  // Vain tiedoston nimi, ei polkua (selain voi antaa myös "C:\\fakepath\\..." tai "../").
  const file = name.split(/[\\/]/).pop() ?? "";
  const dot = file.lastIndexOf(".");
  const rawExt = dot > 0 ? file.slice(dot + 1).toLowerCase() : "";
  const ext = /^[a-z0-9]{1,8}$/.test(rawExt) ? rawExt : "";
  const base = (ext ? file.slice(0, dot) : file)
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 60);
  return `${base || "liite"}${ext ? `.${ext}` : ""}`;
}

const DOCUMENT_TYPES: Record<string, string> = {
  jpg: "image/jpeg",
  jpeg: "image/jpeg",
  png: "image/png",
  webp: "image/webp",
  heic: "image/heic",
  heif: "image/heic",
  pdf: "application/pdf",
};

/** Tiedostovalitsimen accept-arvo: tyypit ja päätteet (osa selaimista ei tunnista HEIC-tyyppiä). */
export const DOCUMENT_ACCEPT = [...new Set(Object.values(DOCUMENT_TYPES)), "image/heif", ".heic", ".heif"].join(",");

/**
 * Liitteen MIME-tyyppi tai null, jos tyyppiä ei tueta. Selain antaa HEIC-kuvalle usein tyhjän
 * tai "image/heif"-tyypin, joten silloin päätellään tiedostopäätteestä.
 */
export function documentContentType(name: string, type: string): string | null {
  const known = new Set(Object.values(DOCUMENT_TYPES));
  if (known.has(type)) return type;
  if (type && type !== "image/heif" && type !== "application/octet-stream") return null;
  const ext = name.split(".").pop()?.toLowerCase() ?? "";
  return DOCUMENT_TYPES[ext] ?? null;
}

/** Satunnainen tunniste. crypto.randomUUID puuttuu suojaamattomalta http-sivulta, getRandomValues ei. */
export function randomId(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(16));
  return Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join("");
}

/** Y-tunnuksen muoto (1234567-8) ja tarkistenumero. */
export function isValidBusinessId(value: string): boolean {
  const m = /^(\d{7})-(\d)$/.exec(value);
  if (!m) return false;
  const weights = [7, 9, 10, 5, 8, 4, 2];
  const sum = [...m[1]!].reduce((s, d, i) => s + Number(d) * weights[i]!, 0);
  const rest = sum % 11;
  if (rest === 1) return false;
  return (rest === 0 ? 0 : 11 - rest) === Number(m[2]);
}
