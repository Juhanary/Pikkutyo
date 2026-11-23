import { getTranslations } from "next-intl/server";
import { Link } from "@/i18n/navigation";
import { MobileNav } from "./MobileNav";
import { NavLink } from "./NavLink";
import styles from "./SiteHeader.module.css";

export async function SiteHeader() {
  const t = await getTranslations("nav");
  const tc = await getTranslations("common");
  return (
    <>
      <a href="#sisalto" className={styles.skip}>
        {tc("skipToContent")}
      </a>
      <header className={styles.header}>
        <div className={`container ${styles.bar}`}>
          <Link href="/" className={styles.brand}>
            {tc("brand")}
          </Link>
          {/* Leveällä näytöllä linkit ovat tässä, puhelimessa alavalikossa (MobileNav). */}
          <nav aria-label={t("main")} className={styles.nav}>
            <ul>
              <li>
                <NavLink href="/haku">{t("search")}</NavLink>
              </li>
              <li>
                <NavLink href="/tarjoajaksi">{t("becomeProvider")}</NavLink>
              </li>
              <li>
                <NavLink href="/kirjaudu">{t("signIn")}</NavLink>
              </li>
            </ul>
          </nav>
        </div>
      </header>
      <MobileNav />
    </>
  );
}
