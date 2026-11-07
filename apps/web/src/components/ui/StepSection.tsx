import type { ReactNode } from "react";
import styles from "./StepSection.module.css";

/**
 * Numeroitu vaihe monivaiheisessa lomakkeessa. Valmis vaihe näyttää ✓-merkin ja tekstin
 * `doneLabel` (merkki on piilotettu ruudunlukijalta, teksti ei).
 */
export function StepSection({
  id,
  number,
  title,
  done,
  doneLabel,
  children,
}: {
  id: string;
  number: number;
  title: ReactNode;
  done?: boolean;
  doneLabel?: string;
  children: ReactNode;
}) {
  return (
    <section className={[styles.step, done && styles.done].filter(Boolean).join(" ")} aria-labelledby={id}>
      <span className={styles.marker} aria-hidden="true">
        {done ? "✓" : number}
      </span>
      <div>
        <div className={styles.head}>
          <h2 id={id}>{title}</h2>
          {done && doneLabel && <span className={styles.state}>{doneLabel}</span>}
        </div>
        <div className={styles.body}>{children}</div>
      </div>
    </section>
  );
}
