import type { ComponentProps } from "react";
import { Link } from "@/i18n/navigation";
import styles from "./Breadcrumbs.module.css";

export interface Crumb {
  label: string;
  href: ComponentProps<typeof Link>["href"];
}

/** Murupolku ylätasoille. Nykyistä sivua ei listata: otsikko kertoo sen. */
export function Breadcrumbs({ items, label }: { items: Crumb[]; label: string }) {
  return (
    <nav aria-label={label} className={styles.crumbs}>
      <ol>
        {items.map((c) => (
          <li key={c.label}>
            <Link href={c.href}>{c.label}</Link>
          </li>
        ))}
      </ol>
    </nav>
  );
}
