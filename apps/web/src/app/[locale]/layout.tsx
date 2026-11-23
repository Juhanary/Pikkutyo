import type { Metadata, Viewport } from "next";
import { Archivo } from "next/font/google";
import { notFound } from "next/navigation";
import { hasLocale, NextIntlClientProvider } from "next-intl";
import { getMessages, setRequestLocale } from "next-intl/server";
import type { ReactNode } from "react";
import { SiteFooter } from "@/components/SiteFooter";
import { SiteHeader } from "@/components/SiteHeader";
import { routing } from "@/i18n/routing";
import { env } from "@/lib/env";
import "../globals.css";

// Archivo leveysakselilla: otsikot kapeina (tienviittamainen), leipäteksti normaalina.
// next/font lataa fontin buildissa ja tarjoilee sen omasta domainista (ei pyyntöjä Googlelle).
const archivo = Archivo({ subsets: ["latin"], axes: ["wdth"], variable: "--font-archivo", display: "swap" });

export const viewport: Viewport = {
  themeColor: [
    { media: "(prefers-color-scheme: light)", color: "#ffffff" },
    { media: "(prefers-color-scheme: dark)", color: "#1f262e" },
  ],
};

export function generateStaticParams() {
  return routing.locales.map((locale) => ({ locale }));
}

export const metadata: Metadata = {
  metadataBase: new URL(env.siteUrl),
  title: { default: "Pikkutyö", template: "%s | Pikkutyö" },
};

export default async function LocaleLayout({
  children,
  params,
}: {
  children: ReactNode;
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  if (!hasLocale(routing.locales, locale)) notFound();
  setRequestLocale(locale);

  const messages = await getMessages();
  // Selaimeen vain asiakaskomponenttien tarvitsemat käännökset.
  const clientMessages = { common: messages.common, slots: messages.slots };

  return (
    <html lang={locale} className={archivo.variable}>
      <body>
        <NextIntlClientProvider locale={locale} messages={clientMessages}>
          <SiteHeader />
          <main id="sisalto" tabIndex={-1}>
            {children}
          </main>
          <SiteFooter locale={locale} />
        </NextIntlClientProvider>
      </body>
    </html>
  );
}
