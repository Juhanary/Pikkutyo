import type { Locale } from "@pikkutyo/i18n";
import { getTranslations } from "next-intl/server";
import { Link } from "@/i18n/navigation";
import { formatPrice, formatRating, formatTime } from "@/lib/format";
import type { SearchResult } from "@/lib/types";
import { Rating, Tags } from "./ui";
import styles from "./ProviderList.module.css";

/** Tarjoajat riveinä: nimi, ominaisuudet ja arviot vasemmalla, hinta oikealla. */
export async function ProviderList({
  results,
  locale,
  headingLevel = 3,
}: {
  results: SearchResult[];
  locale: Locale;
  headingLevel?: 2 | 3;
}) {
  const t = await getTranslations({ locale, namespace: "common" });
  const ts = await getTranslations({ locale, namespace: "search" });
  const tc = await getTranslations({ locale, namespace: "city" });

  if (results.length === 0) return <p className={styles.empty}>{tc("noProviders")}</p>;
  const Heading = `h${headingLevel}` as const;

  return (
    <ul className={styles.list}>
      {results.map((r) => {
        const rating = formatRating(r.rating_avg, locale);
        return (
          <li key={`${r.provider_id}-${r.location_type}`} className={styles.row}>
            <div className={styles.meta}>
              <Heading className={styles.name}>
                <Link href={{ pathname: "/tarjoajat/[slug]", params: { slug: r.slug } }}>{r.display_name}</Link>
              </Heading>
              <Tags
                items={[
                  r.location_type === "mobile" ? t("atHome") : t("atWorkshop"),
                  r.kind === "company" ? t("company") : t("individual"),
                  r.district_name,
                ]}
              />
              <Rating
                value={r.rating_avg}
                text={rating ? t("rating", { rating, count: r.rating_count }) : t("noRating")}
              />
              {r.free_slots != null &&
                (r.free_slots > 0 && r.first_free_at ? (
                  <span className={styles.next}>
                    {ts("firstFree", { time: formatTime(r.first_free_at, locale) })} ·{" "}
                    {t("freeSlots", { count: r.free_slots })}
                  </span>
                ) : (
                  <span className={styles.none}>{t("freeSlots", { count: 0 })}</span>
                ))}
            </div>
            <div className={styles.price}>
              <span className={styles.sub}>{t("from")}</span>
              <span className={`${styles.amount} num`}>{formatPrice(r.price_cents, locale)}</span>
              <span className={styles.sub}>
                {t("duration", { minutes: r.duration_min })}
                {r.travel_fee_cents > 0 && <> {t("travelFee", { price: formatPrice(r.travel_fee_cents, locale) })}</>}
              </span>
            </div>
          </li>
        );
      })}
    </ul>
  );
}
