import type { ReactNode } from "react";
import styles from "./Field.module.css";

/** Kentän otsikko, kenttä ja ohje. Label ympäröi kentän, joten id:itä ei tarvita. */
export function Field({
  label,
  hint,
  className,
  children,
}: {
  label: ReactNode;
  hint?: ReactNode;
  className?: string;
  children: ReactNode;
}) {
  return (
    <label className={[styles.field, className].filter(Boolean).join(" ")}>
      <span className={styles.label}>{label}</span>
      {children}
      {hint && <span className={styles.hint}>{hint}</span>}
    </label>
  );
}

/** Valintaruutu- tai radioryhmä otsikkoineen. */
export function ChoiceGroup({ legend, children }: { legend: ReactNode; children: ReactNode }) {
  return (
    <fieldset>
      <legend>{legend}</legend>
      <div className={styles.choices}>{children}</div>
    </fieldset>
  );
}

/** Yksi valinta (input + teksti) laatikkona. */
export function Choice({ children }: { children: ReactNode }) {
  return <label className={styles.choice}>{children}</label>;
}
