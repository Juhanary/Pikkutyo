"use client";

import { useTranslations } from "next-intl";
import { useEffect } from "react";
import { Button, ButtonLink, PageHeader } from "@/components/ui";

/** Virhesivu, kun sivun haku epäonnistuu (esim. tietokanta ei vastaa). Ei näytä teknisiä tietoja. */
export default function ErrorPage({ error, reset }: { error: Error & { digest?: string }; reset: () => void }) {
  const t = useTranslations("common");
  useEffect(() => {
    console.error(error);
  }, [error]);

  return (
    <div className="container-narrow page">
      <PageHeader title={t("errorTitle")} lead={t("errorLead")}>
        <Button onClick={reset}>{t("retry")}</Button>
        <ButtonLink href="/" variant="secondary">
          {t("home")}
        </ButtonLink>
      </PageHeader>
    </div>
  );
}
