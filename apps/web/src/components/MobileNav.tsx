import { getTranslations } from "next-intl/server";
import type { ReactNode } from "react";
import { NavLink, type NavHref } from "./NavLink";
import styles from "./MobileNav.module.css";

/** Ikonit piirretään viivoina tekstin värillä; ruudunlukija lukee vain otsikon. */
function Icon({ children }: { children: ReactNode }) {
  return (
    <svg
      width="24"
      height="24"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      {children}
    </svg>
  );
}

const ITEMS: { href: NavHref; label: "tabHome" | "search" | "tabProvider" | "signIn"; icon: ReactNode }[] = [
  {
    href: "/",
    label: "tabHome",
    icon: <path d="M3.5 10.5 12 3.5l8.5 7V20a.5.5 0 0 1-.5.5h-5v-6h-6v6H4a.5.5 0 0 1-.5-.5z" />,
  },
  {
    href: "/haku",
    label: "search",
    icon: (
      <>
        <circle cx="11" cy="11" r="6.5" />
        <path d="m16 16 4.5 4.5" />
      </>
    ),
  },
  {
    href: "/tarjoajaksi",
    label: "tabProvider",
    icon: (
      <>
        <rect x="3" y="7" width="18" height="13" rx="2.5" />
        <path d="M8.5 7V5.5a2 2 0 0 1 2-2h3a2 2 0 0 1 2 2V7M3 12.5h18" />
      </>
    ),
  },
  {
    href: "/kirjaudu",
    label: "signIn",
    icon: (
      <>
        <circle cx="12" cy="8" r="4" />
        <path d="M4 20.5c1.2-3.8 4.3-5.5 8-5.5s6.8 1.7 8 5.5" />
      </>
    ),
  },
];

/**
 * Puhelimen alavalikko: kelluva pilli sivun alalaidassa, sama rakenne kuin sovelluksen
 * alapalkissa. Näkyy vain kapealla näytöllä; leveällä näytöllä samat linkit ovat yläpalkissa.
 */
export async function MobileNav() {
  const t = await getTranslations("nav");
  return (
    <nav aria-label={t("tabs")} className={styles.bar}>
      <ul className={styles.list}>
        {ITEMS.map((item) => (
          <li key={item.href}>
            <NavLink href={item.href} className={styles.link}>
              <Icon>{item.icon}</Icon>
              <span>{t(item.label)}</span>
            </NavLink>
          </li>
        ))}
      </ul>
    </nav>
  );
}
