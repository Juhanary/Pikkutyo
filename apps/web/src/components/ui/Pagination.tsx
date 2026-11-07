import type { ComponentProps } from "react";
import { Link } from "@/i18n/navigation";
import styles from "./Pagination.module.css";

type Href = ComponentProps<typeof Link>["href"];

/** Edellinen/seuraava-sivutus ja tilanne ("21–40 / 70"). Ei näy, jos sivuja on yksi. */
export function Pagination({
  page,
  pageCount,
  hrefFor,
  labels,
}: {
  page: number;
  pageCount: number;
  hrefFor: (page: number) => Href;
  labels: { nav: string; previous: string; next: string; status: string };
}) {
  if (pageCount <= 1) return null;
  return (
    <nav aria-label={labels.nav} className={styles.pagination}>
      {page > 1 ? (
        <Link href={hrefFor(page - 1)} rel="prev" className={styles.link}>
          {labels.previous}
        </Link>
      ) : (
        <span />
      )}
      <span className={`${styles.status} num`}>{labels.status}</span>
      {page < pageCount ? (
        <Link href={hrefFor(page + 1)} rel="next" className={styles.link}>
          {labels.next}
        </Link>
      ) : (
        <span />
      )}
    </nav>
  );
}
