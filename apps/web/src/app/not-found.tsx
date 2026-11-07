import "./globals.css";

// Kielen ulkopuoliset tuntemattomat polut (proxy ohjaa yleensä kielelliseen 404:ään).
export default function GlobalNotFound() {
  return (
    <html lang="fi">
      <body>
        <main className="container-narrow page">
          <h1>Sivua ei löytynyt</h1>
          <p>
            <a href="/">Etusivulle</a>
          </p>
        </main>
      </body>
    </html>
  );
}
