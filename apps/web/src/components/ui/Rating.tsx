import styles from "./Rating.module.css";

/** Tähdet (piilotettu ruudunlukijalta) ja teksti, esim. "4,6 / 5 (12 arviota)". */
export function Rating({ value, text }: { value: number | null; text: string }) {
  const full = value == null ? 0 : Math.min(5, Math.max(0, Math.round(value)));
  return (
    <span className={styles.rating}>
      {value != null && (
        <span className={styles.stars} aria-hidden="true">
          {"★".repeat(full)}
          {"☆".repeat(5 - full)}
        </span>
      )}
      <span>{text}</span>
    </span>
  );
}
