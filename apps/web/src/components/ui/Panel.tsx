import type { ComponentProps } from "react";
import styles from "./Panel.module.css";

/** Pinta yhteen kuuluvalle sisällölle (lomake, vapaat ajat). Ei koristeeksi. */
export function Panel({ raised, className, ...rest }: ComponentProps<"section"> & { raised?: boolean }) {
  return (
    <section className={[styles.panel, raised && styles.raised, className].filter(Boolean).join(" ")} {...rest} />
  );
}
