import { env } from "./env";
import type { LocationType } from "./types";

/**
 * Syvälinkki Flutter-sovelluksen varausnäkymään. Mobiilissa sama https-osoite
 * avaa sovelluksen (Universal Links / App Links), muuten Flutter webin.
 */
export function bookingUrl(params: {
  providerId: string;
  serviceCode: string;
  startsAt: string;
  locationType: LocationType;
}): string {
  const url = new URL("/varaa", env.appUrl);
  url.searchParams.set("provider", params.providerId);
  url.searchParams.set("service", params.serviceCode);
  url.searchParams.set("start", params.startsAt);
  url.searchParams.set("loc", params.locationType);
  return url.toString();
}
