"use client";

import type { ComponentProps } from "react";
import { Link, usePathname } from "@/i18n/navigation";

type Href = "/haku" | "/tarjoajaksi" | "/kirjaudu";

/** Navigaatiolinkki, joka merkitsee nykyisen osion (aria-current). */
export function NavLink({ href, ...rest }: Omit<ComponentProps<typeof Link>, "href"> & { href: Href }) {
  const pathname = usePathname();
  const current = pathname === href || pathname.startsWith(`${href}/`);
  return <Link href={href} aria-current={current ? "page" : undefined} {...rest} />;
}
