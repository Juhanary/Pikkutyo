import type { ReactNode } from "react";
import styles from "./Notice.module.css";

type Tone = "info" | "success" | "error";

/** Ilmoitus. Virhe luetaan ruudunlukijalla heti (role=alert), muut kohteliaasti (role=status). */
export function Notice({ tone = "info", children }: { tone?: Tone; children: ReactNode }) {
  return (
    <div className={`${styles.notice} ${styles[tone]}`} role={tone === "error" ? "alert" : "status"}>
      {children}
    </div>
  );
}
