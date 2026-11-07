// database.ts generoidaan komennolla `npm run db:types` (Supabase CLI).
// Älä muokkaa database.ts:ää käsin.
export type { Database, Json } from "./database";

import type { Database } from "./database";

type PublicSchema = Database["public"];

export type Tables<T extends keyof PublicSchema["Tables"]> =
  PublicSchema["Tables"][T]["Row"];
export type Views<T extends keyof PublicSchema["Views"]> =
  PublicSchema["Views"][T]["Row"];
export type Enums<T extends keyof PublicSchema["Enums"]> =
  PublicSchema["Enums"][T];
export type RpcArgs<T extends keyof PublicSchema["Functions"]> =
  PublicSchema["Functions"][T]["Args"];
export type RpcResult<T extends keyof PublicSchema["Functions"]> =
  PublicSchema["Functions"][T]["Returns"];
