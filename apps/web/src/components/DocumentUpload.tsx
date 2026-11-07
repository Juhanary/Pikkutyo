"use client";

// Liitteen lataus: tiedosto suoraan Storageen (bucket application-documents, polku
// <user_id>/<application_id>/<tiedosto>) ja sen jälkeen kirjaus hakemukseen.
// Kanta hyväksyy kirjauksen vain, jos polku on hakijan oma ja tiedosto on ladattu.
import { useRouter } from "next/navigation";
import { useState } from "react";
import { DOCUMENT_ACCEPT, documentContentType, randomId, safeFileName, type DocumentKind } from "@/lib/auth";
import { getSupabaseBrowserClient } from "@/lib/supabase/browser";
import styles from "./DocumentUpload.module.css";
import { Button } from "./ui/Button";
import { Field } from "./ui/Field";
import { Notice } from "./ui/Notice";

const MAX_BYTES = 10 * 1024 * 1024;

export interface DocumentUploadLabels {
  kind: string;
  kinds: Record<DocumentKind, string>;
  file: string;
  upload: string;
  uploading: string;
  tooLarge: string;
  wrongType: string;
  failed: string;
}

export function DocumentUpload({
  userId,
  applicationId,
  labels,
}: {
  userId: string;
  applicationId: string;
  labels: DocumentUploadLabels;
}) {
  const router = useRouter();
  const [kind, setKind] = useState<DocumentKind>("tools");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function onSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const input = event.currentTarget.elements.namedItem("file") as HTMLInputElement;
    const file = input.files?.[0];
    if (!file) return;
    if (file.size > MAX_BYTES) return setError(labels.tooLarge);
    const contentType = documentContentType(file.name, file.type);
    if (!contentType) return setError(labels.wrongType);

    setBusy(true);
    setError(null);
    const supabase = getSupabaseBrowserClient();
    const bucket = supabase.storage.from("application-documents");
    const path = `${userId}/${applicationId}/${randomId()}-${safeFileName(file.name)}`;
    try {
      const upload = await bucket.upload(path, file, { contentType, upsert: false });
      if (upload.error) return setError(labels.failed);
      const insert = await supabase
        .from("application_documents")
        .insert({ application_id: applicationId, storage_path: path, kind });
      if (insert.error) {
        // Kirjaus epäonnistui (esim. hakemus lähetettiin toisessa välilehdessä): poistetaan
        // ladattu tiedosto, ettei Storageen jää orpoa liitettä.
        await bucket.remove([path]);
        return setError(labels.failed);
      }
      input.value = "";
      router.refresh();
    } catch {
      setError(labels.failed);
    } finally {
      setBusy(false);
    }
  }

  return (
    <form onSubmit={onSubmit} className={styles.form} aria-busy={busy}>
      <Field label={labels.kind}>
        <select value={kind} onChange={(e) => setKind(e.target.value as DocumentKind)}>
          {(Object.keys(labels.kinds) as DocumentKind[]).map((k) => (
            <option key={k} value={k}>
              {labels.kinds[k]}
            </option>
          ))}
        </select>
      </Field>
      <Field label={labels.file}>
        <input type="file" name="file" accept={DOCUMENT_ACCEPT} required />
      </Field>
      <Button type="submit" variant="secondary" disabled={busy} className={styles.submit}>
        {busy ? labels.uploading : labels.upload}
      </Button>
      {error && (
        <div className={styles.error}>
          <Notice tone="error">
            <p>{error}</p>
          </Notice>
        </div>
      )}
    </form>
  );
}
