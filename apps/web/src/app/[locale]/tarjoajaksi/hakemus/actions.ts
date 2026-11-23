"use server";

// Tarjoajahakemuksen toiminnot. Kaikki kirjoitukset tehdään käyttäjän omilla oikeuksilla
// (RLS ja sarakekohtaiset oikeudet: käyttäjä muokkaa vain omaa luonnostaan ja vain
// sisältökenttiä). Tila, tunnistus ja kurssi kirjataan RPC:illä tai palvelun puolella.
import type { Locale } from "@pikkutyo/i18n";
import { redirect } from "next/navigation";
import { getPathname } from "@/i18n/navigation";
import { isValidBusinessId, localeOf, TERMS_VERSION } from "@/lib/auth";
import { createSupabaseAdmin, requireUser, testShortcutsEnabled } from "@/lib/supabase/server";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

function back(locale: Locale, params: Record<string, string> = {}): never {
  const query = new URLSearchParams(params).toString();
  redirect(`${getPathname({ locale, href: "/tarjoajaksi/hakemus" })}${query ? `?${query}` : ""}`);
}

const text = (formData: FormData, name: string, max: number): string | null => {
  const value = String(formData.get(name) ?? "").trim();
  return value ? value.slice(0, max) : null;
};

function applicationId(formData: FormData): string | null {
  const id = String(formData.get("application_id") ?? "");
  return UUID.test(id) ? id : null;
}

/** Luo luonnoksen tai tallentaa sen muutokset. */
export async function saveApplication(formData: FormData) {
  const locale = localeOf(formData);
  const { supabase } = await requireUser(locale);

  const kind = formData.get("kind") === "company" ? "company" : "individual";
  const displayName = text(formData, "display_name", 80);
  const businessId = text(formData, "business_id", 9);
  const cityId = String(formData.get("city_id") ?? "");
  const districtId = String(formData.get("district_id") ?? "");
  const invoicing = String(formData.get("invoicing_service") ?? "none");

  if (!displayName || displayName.length < 2) back(locale, { error: "display_name" });
  if (businessId && !isValidBusinessId(businessId)) back(locale, { error: "business_id" });
  if (kind === "company" && !businessId) back(locale, { error: "business_id" });
  if (!UUID.test(cityId)) back(locale, { error: "city" });
  // Kaupunginosan on oltava valitussa kaupungissa (lomake listaa kaikkien kaupunkien osat).
  if (UUID.test(districtId)) {
    const { data: district } = await supabase
      .from("districts")
      .select("id")
      .eq("id", districtId)
      .eq("city_id", cityId)
      .maybeSingle();
    if (!district) back(locale, { error: "district" });
  }

  const fields = {
    kind,
    display_name: displayName,
    business_id: businessId,
    city_id: cityId,
    district_id: UUID.test(districtId) ? districtId : null,
    location_types: formData
      .getAll("location_types")
      .map(String)
      .filter((v) => v === "workshop" || v === "mobile"),
    description: text(formData, "description", 2000),
    tools_description: text(formData, "tools_description", 2000),
    contact_email: text(formData, "contact_email", 200),
    contact_phone: text(formData, "contact_phone", 40),
    invoicing_service: ["none", "ukko", "eezy", "other"].includes(invoicing) ? invoicing : "none",
    invoicing_reference: text(formData, "invoicing_reference", 200),
  };

  const id = applicationId(formData);
  if (id) {
    // Nolla päivitettyä riviä = hakemus on jo lähetetty (esim. toisessa välilehdessä) tai ei ole oma.
    const { data, error } = await supabase
      .from("provider_applications")
      .update(fields)
      .eq("id", id)
      .eq("status", "draft")
      .select("id");
    if (error) back(locale, { error: "save" });
    if (!data?.length) back(locale, { error: "not_draft" });
  } else {
    const { error } = await supabase.from("provider_applications").insert(fields);
    // Käyttäjällä voi olla vain yksi keskeneräinen hakemus (provider_applications_one_open).
    if (error) back(locale, { error: error.code === "23505" ? "already_open" : "save" });
  }
  back(locale, { saved: "1" });
}

export async function acceptTerms(formData: FormData) {
  const locale = localeOf(formData);
  const { supabase } = await requireUser(locale);
  const id = applicationId(formData);
  if (!id || formData.get("accept") !== "on") back(locale, { error: "terms" });
  const { error } = await supabase.rpc("accept_provider_terms", {
    p_application_id: id,
    p_terms_version: TERMS_VERSION,
  });
  if (error) back(locale, { error: "save" });
  back(locale, { saved: "1" });
}

export async function submitApplication(formData: FormData) {
  const locale = localeOf(formData);
  const { supabase } = await requireUser(locale);
  const id = applicationId(formData);
  if (!id) back(locale, { error: "save" });
  const { error } = await supabase.rpc("submit_provider_application", { p_application_id: id });
  if (error) {
    if (error.message === "application_incomplete") back(locale, { error: "incomplete", missing: error.details ?? "" });
    back(locale, { error: "save" });
  }
  back(locale, { submitted: "1" });
}

export async function removeDocument(formData: FormData) {
  const locale = localeOf(formData);
  const { supabase } = await requireUser(locale);
  const id = String(formData.get("document_id") ?? "");
  if (!UUID.test(id)) back(locale, { error: "save" });
  // RLS sallii poiston vain omasta luonnoksesta. Ensin kirjaus, sitten tiedosto: Storage
  // sallii vain kirjaamattoman tiedoston poiston.
  const { data, error } = await supabase
    .from("application_documents")
    .delete()
    .eq("id", id)
    .select("storage_path");
  if (error) back(locale, { error: "save" });
  const removed = data?.[0];
  if (!removed) back(locale, { error: "not_draft" });
  // Tiedoston poiston epäonnistuminen ei estä käyttäjää: orpo tiedosto ei näy hakemuksessa.
  await supabase.storage.from("application-documents").remove([removed.storage_path]);
  back(locale, { saved: "1" });
}

// ---------------------------------------------------------------------------
// Testikytkimet: tunnistus ja kurssi ilman oikeaa palvelua (ALLOW_TEST_SHORTCUTS=true).
// Oikeassa käytössä nämä kirjaa Edge Function (Signicat/Criipto) ja kurssialusta.
// ---------------------------------------------------------------------------
async function testUpdate(formData: FormData, fields: Record<string, unknown>) {
  const locale = localeOf(formData);
  if (!testShortcutsEnabled()) back(locale, { error: "save" });
  const { userId } = await requireUser(locale);
  const id = applicationId(formData);
  if (!id) back(locale, { error: "save" });
  const { data, error } = await createSupabaseAdmin()
    .from("provider_applications")
    .update(fields)
    .eq("id", id)
    .eq("user_id", userId)
    .eq("status", "draft")
    .select("id");
  if (error) back(locale, { error: "save" });
  if (!data?.length) back(locale, { error: "not_draft" });
  back(locale, { saved: "1" });
}

export async function testVerifyIdentity(formData: FormData) {
  await testUpdate(formData, {
    identity_provider: "criipto",
    identity_subject: `test-${crypto.randomUUID()}`,
    identity_verified_at: new Date().toISOString(),
    is_adult: true,
  });
}

export async function testCompleteCourse(formData: FormData) {
  await testUpdate(formData, { course_version: "test", course_completed_at: new Date().toISOString() });
}
