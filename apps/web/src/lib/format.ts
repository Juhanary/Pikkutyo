import type { Locale } from "@pikkutyo/i18n";
import type { I18nText } from "./types";

export const TIME_ZONE = "Europe/Helsinki";

const intlLocale: Record<Locale, string> = { fi: "fi-FI", sv: "sv-FI", en: "en-GB" };

export function t(text: I18nText | null | undefined, locale: Locale): string {
  if (!text) return "";
  return text[locale] || text.fi;
}

export function formatPrice(cents: number, locale: Locale): string {
  return new Intl.NumberFormat(intlLocale[locale], {
    style: "currency",
    currency: "EUR",
    minimumFractionDigits: cents % 100 === 0 ? 0 : 2,
    maximumFractionDigits: 2,
  }).format(cents / 100);
}

export function formatTime(iso: string, locale: Locale): string {
  return new Intl.DateTimeFormat(intlLocale[locale], {
    hour: "2-digit",
    minute: "2-digit",
    timeZone: TIME_ZONE,
  }).format(new Date(iso));
}

export function formatDay(date: Date, locale: Locale): string {
  return new Intl.DateTimeFormat(intlLocale[locale], {
    weekday: "short",
    day: "numeric",
    month: "numeric",
    timeZone: TIME_ZONE,
  }).format(date);
}

/** Päivämäärä muodossa YYYY-MM-DD Helsingin ajassa. */
export function isoDate(date: Date): string {
  return new Intl.DateTimeFormat("sv-SE", { timeZone: TIME_ZONE }).format(date);
}

function parseIso(value: string): [number, number, number] | null {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value);
  return m ? [Number(m[1]), Number(m[2]), Number(m[3])] : null;
}

/** YYYY-MM-DD-päivän keskipäivä (UTC). Keskipäivä pitää päivän samana Helsingin ajassa. */
export function dateFromIso(iso: string, addDaysCount = 0): Date {
  const p = parseIso(iso);
  if (!p) throw new Error(`Virheellinen päivämäärä: ${iso}`);
  return new Date(Date.UTC(p[0], p[1] - 1, p[2] + addDaysCount, 12));
}

/** Onko merkkijono olemassa oleva kalenteripäivä muodossa YYYY-MM-DD (esim. 2026-02-30 ei ole). */
export function isValidIsoDate(value: string): boolean {
  const p = parseIso(value);
  if (!p) return false;
  const date = new Date(Date.UTC(p[0], p[1] - 1, p[2]));
  return date.getUTCFullYear() === p[0] && date.getUTCMonth() === p[1] - 1 && date.getUTCDate() === p[2];
}

/** Lisää kalenteripäiviä YYYY-MM-DD-päivään; kesäaikasiirtymä ei hyppää päivän yli. */
export function addDays(iso: string, days: number): string {
  return dateFromIso(iso, days).toISOString().slice(0, 10);
}

export function formatRating(value: number | null, locale: Locale): string | null {
  if (value == null) return null;
  return new Intl.NumberFormat(intlLocale[locale], {
    minimumFractionDigits: 1,
    maximumFractionDigits: 1,
  }).format(value);
}
