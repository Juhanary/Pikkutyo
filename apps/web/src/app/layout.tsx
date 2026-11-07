import type { ReactNode } from "react";

// Juuritason layout vain välittää sisällön: <html> ja <body> tulevat kielikohtaisesta
// layoutista ([locale]/layout.tsx) tai juuren not-found.tsx:stä. Next.js vaatii juuren
// layoutin, kun app/not-found.tsx on olemassa (muuten tuotantobuild kaatuu).
export default function RootLayout({ children }: { children: ReactNode }) {
  return children;
}
