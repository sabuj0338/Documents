[PROJECT-BLUEPRINT.md](https://github.com/user-attachments/files/33714624/PROJECT-BLUEPRINT.md)
# React Admin SPA Blueprint

A reusable blueprint taken from the xstore `admin` app (React 19 + Vite admin panel).
To reuse it, drop this file into a new project as `CLAUDE.md` / `AGENTS.md`, or point your agent at it:
"Follow PROJECT-BLUEPRINT.md for architecture, patterns and libraries."

Replace `<app>`, `<domain>` and `/api/v1/<scope>` with your own names.

---

## 1. Tech stack

| Concern | Choice | Notes |
|---|---|---|
| Framework | **React 19** (SPA, no SSR) | `StrictMode`, function components only (class only for ErrorBoundary) |
| Build | **Vite 8** + `@vitejs/plugin-react` | `@` alias → `./src` |
| Language | **TypeScript (strict)** | `noUnusedLocals`, `noUnusedParameters`, `verbatimModuleSyntax`, `erasableSyntaxOnly`, `moduleResolution: bundler` |
| Routing | **react-router v7+** (`createBrowserRouter`) | Data router, nested layouts, `lazy()` pages |
| Server state | **@tanstack/react-query v5** | Query-key factories per feature, invalidate on mutation |
| Client state | **zustand v5** (+ `persist`) | Auth session snapshot + UI state only |
| HTTP | **axios** | One instance, interceptors for auth + refresh-once on 401 |
| Forms | **react-hook-form** + **zod v4** + `@hookform/resolvers` | `z.infer<typeof schema>` for types |
| UI kit | **shadcn/ui** (style `base-nova`, on **@base-ui/react**) | Generated into `src/components/ui/` — don't hand-edit |
| Styling | **Tailwind CSS v4** (`@tailwindcss/vite`), `tw-animate-css`, CSS variables theme | `cn()` = `clsx` + `tailwind-merge` |
| Tables | **@tanstack/react-table v8** | Wrapped in one shared `DataTable` |
| Icons | **lucide-react** | |
| Toasts | **sonner** | |
| Theme | **next-themes** | Light/dark via `.dark` class |
| Charts | **recharts** (via shadcn `chart`) | Code-split per route |
| Dates | **date-fns** | |
| Font | `@fontsource-variable/geist` | |
| Lint | **oxlint** | `oxlint src` |
| Monorepo | **pnpm workspaces** + **turborepo** | `apps/*`, `packages/*` |
| Deploy | Static: **Cloudflare Workers assets** (`wrangler`, SPA not-found handling) or **Docker** (multi-stage → `nginx-unprivileged`) | `VITE_*` baked at build time |

### Install (new project)

```bash
pnpm create vite <app> --template react-ts
pnpm add react-router @tanstack/react-query @tanstack/react-table axios zustand react-hook-form zod @hookform/resolvers sonner next-themes lucide-react date-fns clsx tailwind-merge class-variance-authority tw-animate-css @base-ui/react @fontsource-variable/geist
pnpm add -D tailwindcss @tailwindcss/vite @tanstack/react-query-devtools @types/node oxlint wrangler
pnpm dlx shadcn@latest init        # pick style: base-nova, base color: neutral, CSS variables: yes
pnpm dlx shadcn@latest add button input field select dialog alert-dialog table badge skeleton sidebar sonner tooltip dropdown-menu card checkbox switch textarea separator sheet popover avatar collapsible scroll-area label
```

### Scripts

```json
{
  "dev": "vite",
  "build": "tsc -b && vite build",
  "preview": "vite preview",
  "lint": "oxlint src",
  "typecheck": "tsc -b --pretty false",
  "deploy:cloudflare": "wrangler deploy"
}
```

### Environment (`.env.example`)

```bash
VITE_API_BASE_URL=http://localhost:8080      # no trailing slash
VITE_AUTH_KEY=<app>-auth                      # zustand persist key
VITE_ACCESS_TOKEN_KEY=<app>-access-token      # localStorage
VITE_REFRESH_TOKEN_KEY=<app>-refresh-token    # localStorage
VITE_MAX_UPLOAD_FILE_SIZE=512000              # keep in sync with backend
```

---

## 2. Folder structure

```text
src/
  main.tsx                 # createRoot + StrictMode + global.css
  App.tsx                  # AppProviders → ErrorBoundary(page) → Suspense → RouterProvider
  app/
    providers.tsx          # QueryClient, settings/theme/tooltip providers, Toaster, Devtools
    router.tsx             # createBrowserRouter, lazy() pages, guards, shells
    DashboardShell.tsx     # Layout + QueryErrorResetBoundary + ErrorBoundary(panel) + Suspense + <Outlet/>
  pages/<route>/
    index.tsx              # THIN route screen (default export)
    detail.tsx             # /<route>/:id
  features/<domain>/
    api.ts                 # query-key factory + fetch functions (pure, no React)
    hooks.ts               # useQuery / useMutation wrappers
    columns.tsx            # TanStack ColumnDef[] for the list table
    components/            # domain-only components
  components/
    ui/                    # shadcn CLI output — DO NOT EDIT unless asked
    common/                # DataTable, Paginator, PageHeader, EmptyState, ConfirmDialog,
                           # StatusBadge, AppErrorBoundary, AppErrorFallback, RouteErrorPage
                           # (no API calls in here)
    layout/                # AdminDashboardLayout, AppSidebar, SidebarNavUser, ThemeProvider,
                           # NavbarHeaderTitle
    forms/                 # one form per file (RHF + Zod)
    auth/                  # ProtectedRoute, PublicAuthRoute, AuthLayout
    skeletons/             # RouteSkeleton, TablePageSkeleton, DashboardSkeleton
  hooks/
    api/use-auth.ts        # auth mutations/queries
    use-mobile.ts ...      # generic hooks
  lib/
    api/client.ts          # axios instance, interceptors, apiRequest<T>, apiUpload<T>
    api/unwrap.ts          # Response<T> envelope → T or throw ApiError
    api/errors.ts          # ApiError class + fieldErrorsFromApi()
    api/auth.ts            # authApi object
    auth-tokens.ts         # localStorage token get/set/clear
    auth-store-bridge.ts   # lets axios update zustand without circular import
    utils.ts               # cn()
  stores/                  # zustand: auth-store.ts, navbar-title-store.ts (UI)
  security/
    permissions.ts         # PERMISSIONS const + hasPermission/hasAnyPermission
    Can.tsx                # <Can permission="x.y">…</Can>
  constants/
    nav.ts                 # sidebar menu groups + ROUTES const
    pagination.ts          # DEFAULT_PAGE, DEFAULT_LIMIT, PAGE_SIZE_OPTIONS
  types/                   # api.ts (ApiResponse<T>), auth.ts, <domain>.ts, sidebar.ts
  providers/               # extra React context providers (e.g. public settings)
  styles/global.css        # tailwind imports + theme tokens
```

**Rules**
- `pages/*` are thin: compose `PageHeader` + feature hooks + `DataTable` / forms. Business logic lives in `features/<domain>/`.
- `components/common/*` never call the API.
- Types live in `src/types/<domain>.ts`; import with `import type`.
- Import order: external packages → blank line → `@/` aliases. Always use the `@/` alias, never long relative paths.

---

## 3. State boundaries

| State | Lives in |
|---|---|
| API data, cache, loading, mutations | **TanStack Query** |
| Auth user snapshot (persisted) | **Zustand** (`persist`, `partialize`) |
| Access/refresh tokens | **localStorage** via `lib/auth-tokens.ts` |
| Sidebar / navbar title / ephemeral UI drafts | **Zustand** |
| Filters, page, limit, sort (shareable) | **URL search params** (`useSearchParams`) |

Never mirror the Query cache into Zustand. Never keep server lists only in Zustand.

QueryClient defaults:

```ts
new QueryClient({
  defaultOptions: { queries: { staleTime: 30_000, retry: 1, refetchOnWindowFocus: false } },
});
```

---

## 4. API layer

### Response envelope (backend contract)

```ts
// types/api.ts
export interface ApiResponse<T> {
  success: boolean;
  message: string;
  data: T;
  errors: unknown | null;   // field map { field: "msg" } and/or { code: "X" }
}

// paginated payload
export type Paginated<T> = {
  results: T[]; page: number; limit: number; totalPages: number; totalResults: number;
};
```

### Client rules (`lib/api/client.ts`)
- One axios instance: `baseURL = ${VITE_API_BASE_URL}/api/v1/<scope>`.
- Request interceptor attaches `Authorization: Bearer <access>` unless `skipAuth`; deletes `Content-Type` for `FormData`.
- Response interceptor: on **401**, refresh **once** (queue concurrent requests while refreshing), retry original; on refresh failure clear session and redirect to `/login`. `skipRefresh` opts out (login, refresh, logout, forgot/reset).
- Components only call `apiRequest<T>(path, { method, body, headers, skipAuth, skipRefresh, signal })` or `apiUpload<T>(path, formData)` — both unwrap the envelope and throw `ApiError`. **Never parse envelopes in components.**
- `auth-store-bridge.ts` breaks the `client.ts` ↔ `auth-store.ts` import cycle: the store registers `{ clearSession, setUser }` at module load; the client calls the bridge.

```ts
// lib/api/errors.ts
export class ApiError extends Error {
  readonly status: number; readonly errors: unknown | null; readonly code?: string;
  constructor(message: string, o: { status: number; errors?: unknown | null; code?: string }) {
    super(message); this.name = "ApiError";
    this.status = o.status; this.errors = o.errors ?? null; this.code = o.code;
  }
}
export function fieldErrorsFromApi(errors: unknown): Record<string, string> | null { /* map string | string[] values, skip "code" */ }
```

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
  - `PublicAuthRoute`: guest-only (login/forgot/reset/verify/accept-invite); authenticated → redirect home.
- **Permissions**: backend returns `user.permissions: string[]` (slugs like `users.read`). Keep a `PERMISSIONS` const in `security/permissions.ts`; gate UI with `<Can permission={PERMISSIONS.X}>` and filter sidebar items by `item.permission`.

---

## 6. Routing & loading

```tsx
// app/router.tsx
const DashboardPage = lazy(() => import("@/pages/dashboard"));
const ThingsPage = lazy(() => import("@/pages/things"));
const ThingDetailPage = lazy(() => import("@/pages/things/detail"));
const LoginPage = lazy(() => import("@/pages/login"));

export const router = createBrowserRouter([
  {
    errorElement: <RouteErrorPage />,
    children: [
      { element: <PublicAuthRoute />, children: [{ path: "/login", element: <LoginPage /> }] },
      {
        path: "/",
        element: <ProtectedRoute />,
        children: [
          {
            element: <DashboardShell />,
            children: [
              { index: true, element: <DashboardPage /> },
              { path: "things", element: <ThingsPage /> },
              { path: "things/:id", element: <ThingDetailPage /> },
            ],
          },
        ],
      },
      { path: "*", element: <Navigate to="/" replace /> },
    ],
  },
]);
```

```tsx
// app/DashboardShell.tsx — shell stays mounted, only <main> suspends
<AdminDashboardLayout>
  <QueryErrorResetBoundary>
    {({ reset }) => (
      <AppErrorBoundary variant="panel" onReset={reset}>
        <Suspense fallback={<TablePageSkeleton />}><Outlet /></Suspense>
      </AppErrorBoundary>
    )}
  </QueryErrorResetBoundary>
</AdminDashboardLayout>
```

- Lazy-load **every** top-level page. Code-split heavy libs (charts, editors) per route.
- Fallbacks are **skeletons**, never a full-page blank spinner. Skeletons are `aria-hidden`; respect `prefers-reduced-motion`.
- Two error boundaries: `variant="page"` at the app root, `variant="panel"` inside the shell (with Query reset).
- Use `startTransition` for non-urgent filter → URL updates. No `useMemo` / `useCallback` by default.

---

## 7. Layout & navigation

- shadcn `SidebarProvider` + `AppSidebar` (`collapsible="icon"`) + `SidebarInset`; content in `max-w-7xl` container.
- Skip link `#main-content` + `<main id="main-content" tabIndex={-1}>`.
- Menu config in `constants/nav.ts`:

```ts
export const app_nav_links: Record<string, SidebarMenu> = {
  mainMenu: { label: "Main", list: [{ title: "Dashboard", url: "/", icon: LayoutDashboard, isActive: false, permission: "x.read" }] },
  footerMenu: { label: "Account", list: [{ title: "Profile", url: "/profile", icon: Shield, isActive: false }] },
};
export const ROUTES = { HOME: "/", LOGIN: "/login", PROFILE: "/profile" } as const;
```

- `formatActivePath(menu, pathname, permissions)` filters by permission, marks `isActive` (`/` exact, others `url` or `url/…`), drops empty groups. `footerMenu` renders in the sidebar footer with `SidebarNavUser` (user menu + theme toggle). Active link gets `aria-current="page"`.
- Each page renders `<NavbarHeaderTitle title="Things" showBack? />` — a null-rendering component that pushes the title/back-button into `useNavbarTitleStore` and sets `document.title`.
- Use React Router `Link` (or `render={<Link to="…" />}` on Base UI components).

---

## 8. Page patterns

### List page

```tsx
export default function ThingsPage() {
  const [searchParams, setSearchParams] = useSearchParams();
  const page = Number(searchParams.get("page") ?? "1") || 1;
  const limit = PAGINATION.DEFAULT_LIMIT;
  const query = useThings({ page, limit });

  return (
    <>
      <NavbarHeaderTitle title="Things" />
      <div className="space-y-6">
        <PageHeader title="Things" description="Manage things." action={
          <Can permission={PERMISSIONS.THINGS_CREATE}><CreateThingDialog /></Can>
        } />
        {query.isError ? <EmptyState title="Could not load things" description="Try again." /> : null}
        <DataTable
          columns={thingColumns}
          data={query.data?.results ?? []}
          isLoading={query.isLoading}
          isFetching={query.isFetching}
          rowLink="/things/_link_"
          pagination={{
            currentPage: page,
            totalPages: query.data?.totalPages ?? 1,
            totalItems: query.data?.totalResults ?? 0,
            pageSize: limit,
            onPageChange: (p) => setSearchParams({ page: String(p) }),
          }}
        />
      </div>
    </>
  );
}
```

- One `h1` per page, via `PageHeader`. Empty → `EmptyState`. Error → message + retry.
- Columns in `features/<domain>/columns.tsx`; use `id: "actions"` for row actions (pinned right, click-isolated) and `id: "select-col"` for selection.
- `DataTable` is server-driven: `manualSorting` + `manualPagination`; page/limit/sort/filters live in the URL. Built-in skeleton rows when `isLoading`, dimmed when `isFetching`, `EmptyState` when empty, `rowLink` with `_link_` placeholder for the id.
- Destructive actions → `ConfirmDialog` (async `onConfirm`, keeps dialog open + spinner while pending, rethrow to keep it open on failure). Status → `StatusBadge`. Gate actions → `<Can />`.

---

## 9. Forms

RHF + Zod + shadcn `Field`. One form per file in `components/forms/` (small dialog forms may be colocated in the page/feature).

```tsx
const schema = z.object({
  email: z.string().email("Enter a valid email"),
  name: z.string().min(2, "Name is required"),
});
type Values = z.infer<typeof schema>;

export function ThingForm() {
  const create = useCreateThing();
  const { register, handleSubmit, setError, reset, formState: { errors } } =
    useForm<Values>({ resolver: zodResolver(schema), defaultValues: { email: "", name: "" } });

  const onSubmit = handleSubmit(async (values) => {
    try {
      await create.mutateAsync(values);
      toast.success("Created");
      reset();
    } catch (error) {
      if (error instanceof ApiError) {
        const fields = fieldErrorsFromApi(error.errors);
        if (fields) for (const [name, message] of Object.entries(fields)) {
          if (name in schema.shape) setError(name as keyof Values, { message });
        }
        toast.error(error.message || "Save failed");
        return;
      }
      toast.error("Save failed");
    }
  });

  return (
    <form onSubmit={onSubmit} aria-busy={create.isPending} noValidate className="space-y-4">
      <Field data-invalid={Boolean(errors.name) || undefined}>
        <FieldLabel htmlFor="name">Name</FieldLabel>
        <Input id="name" disabled={create.isPending} {...register("name")}
               aria-invalid={Boolean(errors.name) || undefined} />
        <FieldError errors={[errors.name]} />
      </Field>
      <Button type="submit" disabled={create.isPending}>
        {create.isPending ? "Saving…" : "Save"}
      </Button>
    </form>
  );
}
```

Rules:
- `data-invalid` on `Field`; `aria-invalid` on the control **after** `{...register()}`; always `<FieldError errors={[errors.x]} />` (it renders nothing when empty) — never ternary-wrap it.
- Pending: disable submit, change label text ("Saving…"), `aria-busy` on the form.
- Success: `toast.success` + invalidate query keys (done in the mutation hook). Failure: map API field errors with `fieldErrorsFromApi` → `setError`, then `toast.error`.
- Base UI `SelectValue` shows the raw value unless you pass the label as children — always render the human label.

---

## 10. UI rules

- **shadcn first**: check `src/components/ui/` → shadcn registry → `pnpm dlx shadcn@latest add <name>` → only then compose app-level UI in `common/`, `forms/` or `features/*`. No hand-rolled dialogs, badges, spinners, upload previews (use `Attachment`), etc.
- Never edit generated `components/ui/*` unless explicitly asked.
- Styling only with Tailwind utility classes + theme tokens (`bg-background`, `text-muted-foreground`, `border`, `text-destructive`…); merge with `cn()`.
- Icons from lucide, `className="size-4"`, decorative icons `aria-hidden`; icon-only buttons need `aria-label`.
- Status must not rely on color alone (badge text included).

## 11. Accessibility (WCAG 2.2 AA)

Skip link + `<main>` landmark; visible `:focus-visible`; labels on every input; `aria-invalid` + described-by for errors; `aria-current="page"` in nav; pending mutations announce text + `aria-busy`; don't break shadcn focus traps.

---

## 12. Deployment

**Cloudflare Workers (static assets)** — `wrangler.jsonc`:

```jsonc
{
  "name": "<app>",
  "compatibility_date": "2026-07-19",
  "assets": { "directory": "./dist", "not_found_handling": "single-page-application" },
  "observability": { "enabled": true }
}
```

**Docker** — multi-stage: `node:22-alpine` + `corepack` pnpm → `pnpm install --frozen-lockfile --filter <app>...` → `pnpm turbo run build --filter=<app>` with `ARG VITE_API_BASE_URL` → copy `dist` into `nginxinc/nginx-unprivileged:1.27-alpine` on port 8080. nginx: gzip, `/assets/` cached 1y immutable, `try_files $uri $uri/ /index.html` for SPA fallback.

---

## 13. Agent checklist (for every change)

1. New domain? Create `types/<domain>.ts` → `features/<domain>/api.ts` (keys + fetchers) → `hooks.ts` → `columns.tsx` → `pages/<domain>/index.tsx` → lazy route in `app/router.tsx` → menu item in `constants/nav.ts` (with `permission`) → `PERMISSIONS` entry.
2. Server data via Query hooks only; filters/pagination in URL; no server lists in Zustand.
3. Lists use `DataTable` + `Paginator`; deletes use `ConfirmDialog`; actions gated by `<Can>`.
4. Forms use RHF + Zod + `Field` error pattern; toast + invalidate on success.
5. Loading = skeletons, empty = `EmptyState`, errors = retry UI.
6. Never edit `components/ui/*`; add missing primitives with the shadcn CLI.
7. Run `pnpm typecheck` and `pnpm lint` before finishing.

## Forbidden

- Parsing the response envelope in components / calling axios directly from components
- Server lists stored only in Zustand, or mirroring Query cache into Zustand
- Full-page spinner as the default route loader
- One-off table / filter / dialog implementations when a shared component exists
- Editing generated shadcn `components/ui/*` without a request
- Skipping accessibility, skeleton or error states
