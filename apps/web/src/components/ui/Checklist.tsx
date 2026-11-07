import styles from "./Checklist.module.css";

/** Tarkistuslista. Tila kerrotaan myös tekstinä (`doneLabel`/`todoLabel`) ruudunlukijalle. */
export function Checklist({
  items,
  doneLabel,
  todoLabel,
}: {
  items: { key: string; label: string; done: boolean }[];
  doneLabel: string;
  todoLabel: string;
}) {
  return (
    <ul className={styles.list}>
      {items.map((i) => (
        <li key={i.key} className={[styles.item, i.done && styles.done].filter(Boolean).join(" ")}>
          <span>
            {i.label}
            <span className="visually-hidden">: {i.done ? doneLabel : todoLabel}</span>
          </span>
        </li>
      ))}
    </ul>
  );
}
