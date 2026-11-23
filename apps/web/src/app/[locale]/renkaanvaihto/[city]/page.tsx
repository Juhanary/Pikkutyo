import type { Locale } from "@pikkutyo/i18n";
import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { setRequestLocale } from "next-intl/server";
import { CityView, cityMetadata } from "@/components/CityView";
import { loadCityPage } from "@/lib/cityPage";

// ISR: sivu renderöidään ensimmäisellä pyynnöllä ja pidetään välimuistissa.
// Tarjoajan muutokset mitätöivät sen heti /api/revalidate-kutsulla.
export const revalidate = 3600;

type Props = { params: Promise<{ locale: Locale; city: string }> };

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { locale, city } = await params;
  const data = await loadCityPage(locale, city);
  return data ? cityMetadata(data, locale) : {};
}

export default async function CityPage({ params }: Props) {
  const { locale, city } = await params;
  setRequestLocale(locale);
  const data = await loadCityPage(locale, city);
  if (!data) notFound();
  return <CityView data={data} locale={locale} />;
}
