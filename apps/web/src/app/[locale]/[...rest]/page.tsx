import { notFound } from "next/navigation";

// Tuntemattomat polut kielen alla → lokalisoitu 404-sivu.
export default function CatchAll() {
  notFound();
}
