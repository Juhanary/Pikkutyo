import path from "node:path";
import { defineConfig } from "vitest/config";

export default defineConfig({
  resolve: { alias: { "@": path.resolve(import.meta.dirname, "src") } },
  test: {
    include: ["src/**/*.test.ts"],
    environment: "node",
    // next-intl tuo "next/navigation" ilman .js-päätettä; inline-tila ratkaisee sen.
    server: { deps: { inline: ["next-intl"] } },
  },
});
