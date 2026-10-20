
### Feature API + hooks template

```ts
// features/<domain>/api.ts
import { apiRequest } from "@/lib/api/client";
import type { Paginated } from "@/types/api";
import type { Thing, CreateThingInput } from "@/types/<domain>";

export type ThingListQuery = { page?: number; limit?: number };

export const thingKeys = {
  all: ["things"] as const,
  list: (q: ThingListQuery) => [...thingKeys.all, "list", q.page ?? 1, q.limit ?? 20] as const,
  detail: (id: string) => [...thingKeys.all, "detail", id] as const,
};

export function fetchThings(q: ThingListQuery = {}) {
  const params = new URLSearchParams({ page: String(q.page ?? 1), limit: String(q.limit ?? 20) });
  return apiRequest<Paginated<Thing>>(`/things?${params.toString()}`);
}
export function fetchThing(id: string) {
  return apiRequest<Thing>(`/things/${id}`);
}
export function createThing(body: CreateThingInput) {
  return apiRequest<Thing>("/things", { method: "POST", body });
}
export function deleteThing(id: string) {
  return apiRequest<null>(`/things/${id}`, { method: "DELETE" });
}
```

```ts
// features/<domain>/hooks.ts
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { createThing, deleteThing, fetchThing, fetchThings, thingKeys, type ThingListQuery } from "@/features/<domain>/api";

export function useThings(q: ThingListQuery = {}) {
  return useQuery({ queryKey: thingKeys.list(q), queryFn: () => fetchThings(q) });
}
export function useThing(id: string, enabled = true) {
  return useQuery({ queryKey: thingKeys.detail(id), queryFn: () => fetchThing(id), enabled: Boolean(id) && enabled });
}
export function useCreateThing() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: createThing,
    onSuccess: () => { void qc.invalidateQueries({ queryKey: thingKeys.all }); },
  });
}
export function useDeleteThing() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => deleteThing(id),
    onSuccess: () => { void qc.invalidateQueries({ queryKey: thingKeys.all }); },
  });
}
```

Naming: `fetchX` / `createX` / `updateX` / `removeX` for API functions, `useX` / `useCreateX` for hooks, `xKeys` for the key factory.

---

## 5. Auth & permissions

- **Tokens** in localStorage (`lib/auth-tokens.ts`, every access wrapped in try/catch). **User snapshot** in a persisted Zustand store; `partialize` keeps only `user` + `isAuthenticated`.
- Store exposes `setSession({ user, accessToken, refreshToken })`, `setUser`, `clearSession`, `logout`, and a `_hasHydrated` flag set in `onRehydrateStorage` (deferred with `queueMicrotask` to avoid TDZ). Rehydration reconciles user vs tokens (stale user without tokens → logged out).
- `useLogin` / `useAcceptInvite` mutations call `setSession` and seed `authKeys.me`. `useLogout` revokes refresh token best-effort, then `clearSession()` + `queryClient.clear()`.
- **Guards** (layout routes rendering `<Outlet/>`):
  - `ProtectedRoute`: wait for hydration (show `RouteSkeleton`); no user + no tokens → `<Navigate to="/login" state={{ from }} />`; tokens but no user → bootstrap via `/auth/me` once. Do **not** refresh on every reload.
