"use client";

import type { Locale } from "@pikkutyo/i18n";
import { createClient } from "@supabase/supabase-js";
import { useLocale, useTranslations } from "next-intl";
import { useEffect, useMemo, useState } from "react";
import { bookingUrl } from "@/lib/booking";
import { env } from "@/lib/env";
import { addDays, dateFromIso, formatDay, formatPrice, formatTime, isoDate } from "@/lib/format";
import type { LocationType, Slot } from "@/lib/types";
import styles from "./SlotPicker.module.css";
import { Field } from "./ui/Field";

export interface SlotService {
  code: string;
  label: string;
  locationType: LocationType;
  totalCents: number;
}

const DAYS = 7;
const supabase = createClient(env.supabaseUrl, env.supabasePublishableKey, {
  auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
});

/** Vapaat ajat haetaan selaimessa aina tuoreena; sivun muu sisältö on välimuistissa. */
export function SlotPicker({ providerId, services }: { providerId: string; services: SlotService[] }) {
  const t = useTranslations("slots");
  const locale = useLocale() as Locale;
  const [serviceIndex, setServiceIndex] = useState(0);
  // Tämä päivä selvitetään vasta selaimessa: sivu on ISR-välimuistissa, joten
  // palvelimen renderöintihetken päivä voi olla jo eilinen (ja aiheuttaisi hydraatiovirheen).
  const [today, setToday] = useState<string | null>(null);
  useEffect(() => setToday(isoDate(new Date())), []);
  const days = useMemo(
    () => (today ? Array.from({ length: DAYS }, (_, i) => addDays(today, i)) : []),
    [today],
  );
  const [selectedDay, setDay] = useState<string | null>(null);
  const day = selectedDay ?? today;
  const [slots, setSlots] = useState<Slot[] | null>(null);
  const [failed, setFailed] = useState(false);

  const service = services[serviceIndex];

  useEffect(() => {
    if (!service || !day) return;
    let cancelled = false;
    setSlots(null);
    setFailed(false);
    supabase
      .rpc(
        "get_available_slots",
        {
          p_provider_id: providerId,
          p_service_code: service.code,
          p_location_type: service.locationType,
          p_from: day,
          p_to: day,
        },
        { get: true },
      )
      .then(({ data, error }) => {
        if (cancelled) return;
        if (error) setFailed(true);
        else setSlots((data ?? []) as Slot[]);
      });
    return () => {
      cancelled = true;
    };
  }, [providerId, service, day]);

  if (!service) return null;

  return (
    <div className={styles.picker}>
      <noscript>
        <p>{t("noscript")}</p>
      </noscript>
      {services.length > 1 && (
        <Field label={t("service")}>
          <select value={serviceIndex} onChange={(e) => setServiceIndex(Number(e.target.value))}>
            {services.map((s, i) => (
              <option key={`${s.code}-${s.locationType}`} value={i}>
                {s.label} – {formatPrice(s.totalCents, locale)}
              </option>
            ))}
          </select>
        </Field>
      )}
      <div className={styles.days} role="group" aria-label={t("day")}>
        {days.map((value) => (
          <button
            key={value}
            type="button"
            className={styles.day}
            aria-pressed={value === day}
            onClick={() => setDay(value)}
          >
            {formatDay(dateFromIso(value), locale)}
          </button>
        ))}
      </div>
      <div aria-live="polite" aria-busy={slots == null && !failed}>
        {failed ? (
          <p role="alert" className={styles.message}>
            {t("error")}
          </p>
        ) : slots == null ? (
          <p className={styles.message}>{t("loading")}</p>
        ) : slots.length === 0 ? (
          <p className={styles.message}>{t("none")}</p>
        ) : (
          <ul className={styles.slots} aria-label={t("times")}>
            {slots.map((s) => (
              <li key={s.starts_at}>
                <a
                  className={`${styles.slot} num`}
                  href={bookingUrl({
                    providerId,
                    serviceCode: service.code,
                    startsAt: s.starts_at,
                    locationType: service.locationType,
                  })}
                  rel="nofollow"
                >
                  {formatTime(s.starts_at, locale)}
                </a>
              </li>
            ))}
          </ul>
        )}
      </div>
      <p className={styles.total}>
        <span>{service.label}</span>
        <strong className="num">{formatPrice(service.totalCents, locale)}</strong>
      </p>
    </div>
  );
}
