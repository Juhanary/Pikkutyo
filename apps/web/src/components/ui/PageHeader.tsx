import type { ReactNode } from "react";
import styles from "./PageHeader.module.css";

/** Sivun otsikko, ingressi ja toiminnot. `before` on otsikon yläpuolelle (murupolku). */
export function PageHeader({
  title,
  lead,
  before,
  children,
}: {
  title: ReactNode;
  lead?: ReactNode;
  before?: ReactNode;
  children?: ReactNode;
}) {
  return (
    <header className={styles.header}>
      {before}
      <h1>{title}</h1>
      {lead && <p className={styles.lead}>{lead}</p>}
      {children && <div className={styles.actions}>{children}</div>}
    </header>
  );
}
