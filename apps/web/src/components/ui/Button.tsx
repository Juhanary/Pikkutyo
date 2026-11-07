import type { ComponentProps } from "react";
import { Link } from "@/i18n/navigation";
import styles from "./Button.module.css";

type Variant = "primary" | "secondary" | "ghost" | "marking";

export interface ButtonLook {
  variant?: Variant;
  size?: "md" | "sm";
  block?: boolean;
}

/** Painikkeen luokat tavalliselle elementille (esim. <a>, jonka polku on jo valmiiksi lokalisoitu). */
export function buttonClassName(look: ButtonLook = {}) {
  return classes(look);
}

function classes({ variant = "primary", size = "md", block }: ButtonLook, extra?: string) {
  return [styles.button, styles[variant], size === "sm" && styles.sm, block && styles.block, extra]
    .filter(Boolean)
    .join(" ");
}

/** Painike. Oletuksena type="button", jottei lomake lähde vahingossa. */
export function Button({ variant, size, block, className, type = "button", ...rest }: ComponentProps<"button"> & ButtonLook) {
  return <button type={type} className={classes({ variant, size, block }, className)} {...rest} />;
}

/** Painikkeen näköinen sivuston sisäinen linkki (lokalisoitu polku). */
export function ButtonLink({ variant, size, block, className, ...rest }: ComponentProps<typeof Link> & ButtonLook) {
  return <Link className={classes({ variant, size, block }, className)} {...rest} />;
}
