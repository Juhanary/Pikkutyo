import { getTranslations } from "next-intl/server";
import { ButtonLink, PageHeader } from "@/components/ui";

export default async function NotFound() {
  const t = await getTranslations("notFound");
  return (
    <div className="container-narrow page">
      <PageHeader title={t("title")} lead={t("lead")}>
        <ButtonLink href="/">{t("back")}</ButtonLink>
        <ButtonLink href="/haku" variant="secondary">
          {t("search")}
        </ButtonLink>
      </PageHeader>
    </div>
  );
}
