import type { Locale } from "@pikkutyo/i18n";
import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { setRequestLocale } from "next-intl/server";
import { CityView, cityMetadata } from "@/components/CityView";
import { loadCityPage } from "@/lib/cityPage";

export const revalidate = 3600;

type Props = { params: Promise<{ locale: Locale; city: string; filter: string }> };

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { locale, city, filter } = await params;
  const data = await loadCityPage(locale, city, filter);
  return data ? cityMetadata(data, locale) : {};
}

// /renkaanvaihto/kuopio/kotipihalla, /korjaamolla tai /petonen (kaupunginosa, jos ≥ 3 tarjoajaa).
export default async function CityFilterPage({ params }: Props) {
  const { locale, city, filter } = await params;
  setRequestLocale(locale);
  const data = await loadCityPage(locale, city, filter);
  if (!data) notFound();
  return <CityView data={data} locale={locale} />;
}
