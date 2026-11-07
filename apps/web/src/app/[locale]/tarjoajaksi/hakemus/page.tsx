import type { Locale } from "@vaihdarenkaat/i18n";
import type { Metadata } from "next";
import { getTranslations, setRequestLocale } from "next-intl/server";
import { DocumentUpload } from "@/components/DocumentUpload";
import { Button, Checklist, Notice, PageHeader, Panel, StepSection } from "@/components/ui";
import {
  applicableRequirements,
  firstParam,
  missingRequirements,
  REQUIREMENTS,
  type ApplicationDocument,
  type ProviderApplication,
  type Requirement,
} from "@/lib/auth";
import { getActiveCities } from "@/lib/data";
import { requireUser, testShortcutsEnabled } from "@/lib/supabase/server";
import { signOut } from "../../kirjaudu/actions";
import { acceptTerms, removeDocument, submitApplication, testCompleteCourse, testVerifyIdentity } from "./actions";
import { ApplicationForm, type DistrictOption } from "./ApplicationForm";
import styles from "./page.module.css";

export const dynamic = "force-dynamic";

type Props = {
  params: Promise<{ locale: Locale }>;
  searchParams: Promise<Record<string, string | string[] | undefined>>;
};

const APPLICATION_COLUMNS =
  "id, kind, status, display_name, business_id, city_id, district_id, location_types, description, " +
  "tools_description, contact_email, contact_phone, invoicing_service, invoicing_reference, " +
  "identity_verified_at, is_adult, course_completed_at, terms_accepted_at, rejection_reason, submitted_at";

const KNOWN_ERRORS = [
  "display_name",
  "business_id",
  "city",
  "district",
  "save",
  "not_draft",
  "already_open",
  "terms",
  "incomplete",
] as const;
function isKnownError(value: string): value is (typeof KNOWN_ERRORS)[number] {
  return (KNOWN_ERRORS as readonly string[]).includes(value);
}

/** Tiedoston näyttönimi Storage-polusta (ilman polkua ja satunnaista tunniste-etuliitettä). */
function fileName(path: string): string {
  return path.split("/").pop()?.replace(/^[0-9a-f-]{32,36}-/, "") ?? path;
}

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "application" });
  return { title: t("title"), robots: { index: false, follow: false } };
}

export default async function ApplicationPage({ params, searchParams }: Props) {
  const { locale } = await params;
  setRequestLocale(locale);
  const sp = await searchParams;
  const t = await getTranslations("application");

  const { supabase, userId, email } = await requireUser(locale);

  // Uusin hakemus: keskeneräinen, käsittelyssä oleva tai viimeisin ratkaistu.
  // Hakuvirhe ei saa näyttää tyhjää lomaketta: käyttäjä luulisi hakemuksensa kadonneen.
  const [appsResult, cities, districtsResult] = await Promise.all([
    supabase.from("provider_applications").select(APPLICATION_COLUMNS).order("created_at", { ascending: false }).limit(1),
    getActiveCities(),
    supabase.from("districts").select("id, city_id, name").order("code"),
  ]);
  if (appsResult.error) throw new Error(`hakemus: ${appsResult.error.message}`);
  if (districtsResult.error) throw new Error(`kaupunginosat: ${districtsResult.error.message}`);
  const app = ((appsResult.data ?? []) as unknown as ProviderApplication[])[0] ?? null;
  const districts = (districtsResult.data ?? []) as DistrictOption[];
  let docs: ApplicationDocument[] = [];
  if (app) {
    const { data, error } = await supabase
      .from("application_documents")
      .select("id, storage_path, kind")
      .eq("application_id", app.id);
    if (error) throw new Error(`liitteet: ${error.message}`);
    docs = data as ApplicationDocument[];
  }

  const error = firstParam(sp.error);
  const missingFromServer = (firstParam(sp.missing) ?? "")
    .split(",")
    .filter((m): m is Requirement => (REQUIREMENTS as readonly string[]).includes(m));
  const formProps = { locale, cities, districts, email };

  const header = (
    <>
      <PageHeader title={t("title")} lead={app?.status === "draft" || !app ? t("lead") : undefined}>
        <span className={styles.account}>{t("signedInAs", { email: email ?? "" })}</span>
        <form action={signOut}>
          <input type="hidden" name="locale" value={locale} />
          <Button type="submit" variant="ghost" size="sm">
            {t("signOut")}
          </Button>
        </form>
      </PageHeader>
      {firstParam(sp.saved) === "1" && (
        <Notice tone="success">
          <p>{t("saved")}</p>
        </Notice>
      )}
      {firstParam(sp.submitted) === "1" && (
        <Notice tone="success">
          <p>{t("submittedNotice")}</p>
        </Notice>
      )}
      {error && (
        <Notice tone="error">
          <p>{t(`errors.${isKnownError(error) ? error : "save"}`)}</p>
          {missingFromServer.length > 0 && (
            <ul>
              {missingFromServer.map((m) => (
                <li key={m}>{t(`requirements.${m}`)}</li>
              ))}
            </ul>
          )}
        </Notice>
      )}
    </>
  );

  // Lähetetty tai ratkaistu hakemus: vain tila. Hylätyn tai perutun jälkeen voi aloittaa uuden.
  if (app && app.status !== "draft") {
    const canStartNew = app.status === "rejected" || app.status === "withdrawn";
    return (
      <div className="container-narrow page">
        {header}
        <Panel raised aria-labelledby="status-title">
          <h2 id="status-title">{t(`status.${app.status}`)}</h2>
          <p>{t(`statusLead.${app.status}`)}</p>
          {app.status === "rejected" && app.rejection_reason && (
            <p>
              <strong>{t("rejectionReason")}:</strong> {app.rejection_reason}
            </p>
          )}
        </Panel>
        {canStartNew && (
          <StepSection id="new-basics" number={1} title={t("form.sectionBasics")}>
            <ApplicationForm app={null} {...formProps} />
          </StepSection>
        )}
      </div>
    );
  }

  const missing = app ? missingRequirements(app, docs) : [...REQUIREMENTS];
  const done = (...rs: Requirement[]) => rs.every((r) => !missing.includes(r));
  const kind = app?.kind ?? "individual";
  const hidden = app && (
    <>
      <input type="hidden" name="locale" value={locale} />
      <input type="hidden" name="application_id" value={app.id} />
    </>
  );

  return (
    <div className="container page">
      {header}
      <div className={styles.layout}>
        <div>
          <StepSection
            id="step-basics"
            number={1}
            title={t("form.sectionBasics")}
            done={app != null && done("location_types")}
            doneLabel={t("stepDone")}
          >
            <ApplicationForm app={app} {...formProps} />
          </StepSection>

          {app && (
            <>
              <StepSection
                id="step-documents"
                number={2}
                title={t("documents.title")}
                done={done("tools_photos", "insurance")}
                doneLabel={t("stepDone")}
              >
                <p>{t("documents.lead")}</p>
                {docs.length === 0 ? (
                  <p className={styles.muted}>{t("documents.none")}</p>
                ) : (
                  <ul className={styles.files}>
                    {docs.map((d) => (
                      <li key={d.id}>
                        <span>
                          <strong>{t(`documents.kinds.${d.kind}`)}</strong> {fileName(d.storage_path)}
                        </span>
                        <form action={removeDocument}>
                          {hidden}
                          <input type="hidden" name="document_id" value={d.id} />
                          <Button type="submit" variant="ghost" size="sm">
                            {t("documents.remove")}
                          </Button>
                        </form>
                      </li>
                    ))}
                  </ul>
                )}
                <DocumentUpload
                  userId={userId}
                  applicationId={app.id}
                  labels={{
                    kind: t("documents.kind"),
                    kinds: {
                      tools: t("documents.kinds.tools"),
                      insurance: t("documents.kinds.insurance"),
                      other: t("documents.kinds.other"),
                    },
                    file: t("documents.file"),
                    upload: t("documents.upload"),
                    uploading: t("documents.uploading"),
                    tooLarge: t("documents.tooLarge"),
                    wrongType: t("documents.wrongType"),
                    failed: t("documents.failed"),
                  }}
                />
              </StepSection>

              <StepSection
                id="step-verification"
                number={3}
                title={t("verification.title")}
                done={done("identity", "adult", "course")}
                doneLabel={t("stepDone")}
              >
                <Checklist
                  doneLabel={t("verification.done")}
                  todoLabel={t("verification.todo")}
                  items={[
                    { key: "identity", label: t("verification.identity"), done: done("identity", "adult") },
                    { key: "course", label: t("verification.course"), done: done("course") },
                  ]}
                />
                {!done("identity", "adult", "course") && <p className={styles.muted}>{t("verification.comingSoon")}</p>}
                {testShortcutsEnabled() && !done("identity", "adult", "course") && (
                  <div className={styles.test}>
                    <p>
                      <small>{t("verification.testNote")}</small>
                    </p>
                    <div className={styles.row}>
                      {!done("identity", "adult") && (
                        <form action={testVerifyIdentity}>
                          {hidden}
                          <Button type="submit" variant="secondary" size="sm">
                            {t("verification.testIdentity")}
                          </Button>
                        </form>
                      )}
                      {!done("course") && (
                        <form action={testCompleteCourse}>
                          {hidden}
                          <Button type="submit" variant="secondary" size="sm">
                            {t("verification.testCourse")}
                          </Button>
                        </form>
                      )}
                    </div>
                  </div>
                )}
              </StepSection>

              <StepSection
                id="step-terms"
                number={4}
                title={t("terms.title")}
                done={done("terms")}
                doneLabel={t("terms.accepted")}
              >
                {!app.terms_accepted_at && (
                  <form action={acceptTerms} className={styles.terms}>
                    {hidden}
                    <p>{t("terms.text")}</p>
                    <label className={styles.check}>
                      <input type="checkbox" name="accept" required /> {t("terms.accept")}
                    </label>
                    <div>
                      <Button type="submit">{t("terms.submit")}</Button>
                    </div>
                  </form>
                )}
                {app.terms_accepted_at && <p className={styles.muted}>{t("terms.text")}</p>}
              </StepSection>
            </>
          )}
        </div>

        <aside className={styles.aside} aria-labelledby="submit-title">
          <Panel raised>
            <h2 id="submit-title">{t("submit.title")}</h2>
            <Checklist
              doneLabel={t("verification.done")}
              todoLabel={t("verification.todo")}
              items={applicableRequirements(kind).map((r) => ({
                key: r,
                label: t(`requirements.${r}`),
                done: done(r),
              }))}
            />
            {app && missing.length === 0 ? (
              <form action={submitApplication}>
                {hidden}
                <p>{t("submit.ready")}</p>
                <Button type="submit" block>
                  {t("submit.button")}
                </Button>
              </form>
            ) : (
              <p className={styles.muted}>{t("submit.missing")}</p>
            )}
          </Panel>
        </aside>
      </div>
    </div>
  );
}
