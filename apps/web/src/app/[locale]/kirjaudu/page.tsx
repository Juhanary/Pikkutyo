import type { Locale } from "@pikkutyo/i18n";
import type { Metadata } from "next";
import { getTranslations, setRequestLocale } from "next-intl/server";
import { Button, buttonClassName, Field, Notice, PageHeader, Panel } from "@/components/ui";
import { firstParam, safeNext } from "@/lib/auth";
import { getAuthContext } from "@/lib/supabase/server";
import { sendSignInLink, signOut } from "./actions";
import styles from "./page.module.css";

// Kirjautuminen luetaan evästeistä, joten sivu on aina dynaaminen eikä sitä indeksoida.
export const dynamic = "force-dynamic";

type Props = {
  params: Promise<{ locale: Locale }>;
  searchParams: Promise<Record<string, string | string[] | undefined>>;
};

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "auth" });
  return { title: t("title"), robots: { index: false, follow: false } };
}

export default async function SignInPage({ params, searchParams }: Props) {
  const { locale } = await params;
  setRequestLocale(locale);
  const sp = await searchParams;
  const t = await getTranslations("auth");
  const next = safeNext(firstParam(sp.next));
  const error = firstParam(sp.error);
  const auth = await getAuthContext();

  const errorNotice = error && (
    <Notice tone="error">
      <p>{t(error === "email" || error === "rate_limit" || error === "link" ? `errors.${error}` : "errors.send")}</p>
    </Notice>
  );

  return (
    <div className="container-narrow page">
      <PageHeader title={t("title")} lead={auth ? undefined : t("lead")} />
      {errorNotice}
      <Panel raised>
        {auth ? (
          <>
            <p>{t("signedInAs", { email: auth.email ?? "" })}</p>
            <div className={styles.actions}>
              {/* Tavallinen linkki: next on jo lokalisoitu polku (safeNext rajaa sen omalle sivustolle). */}
              <a href={next} className={buttonClassName()}>
                {t("continue")}
              </a>
              <form action={signOut}>
                <input type="hidden" name="locale" value={locale} />
                <Button type="submit" variant="secondary">
                  {t("signOut")}
                </Button>
              </form>
            </div>
          </>
        ) : firstParam(sp.sent) === "1" ? (
          <Notice tone="success">
            <p>{t("sent")}</p>
          </Notice>
        ) : (
          <form action={sendSignInLink} className={styles.form}>
            <input type="hidden" name="locale" value={locale} />
            <input type="hidden" name="next" value={next} />
            <Field label={t("email")}>
              <input type="email" name="email" required autoComplete="email" inputMode="email" />
            </Field>
            <Button type="submit" block>
              {t("send")}
            </Button>
          </form>
        )}
      </Panel>
    </div>
  );
}
