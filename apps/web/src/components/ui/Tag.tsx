import styles from "./Tag.module.css";

/** Lyhyet ominaisuudet (paikka, tekijä, kaupunginosa) listana. Tyhjät jätetään pois. */
export function Tags({ items }: { items: (string | null | undefined | false)[] }) {
  const list = items.filter((i): i is string => Boolean(i));
  if (list.length === 0) return null;
  return (
    <ul className={styles.tags}>
      {list.map((i) => (
        <li key={i} className={styles.tag}>
          {i}
        </li>
      ))}
    </ul>
  );
}
