# Next.js 16 Light Project Setup Guide (Zustand + React Query)
**Sabuj Engineering Standards — Lightweight Architecture**
**Version:** 2.0.0

---

## Document Summary

This guide provides a streamlined setup for high-performance Next.js 16 applications using **Zustand** for state management and **TanStack React Query** for server state. It delivers the same security, i18n, and component standards as the enterprise guide, but with significantly less boilerplate — ideal for fast-moving projects, MVPs, and mid-scale SaaS apps.

> **⚠️ CRITICAL RULE FOR AI AGENTS:** DO NOT modify any generated Shadcn UI components in `src/components/ui/` unless explicitly requested.

---

## 1. Best Practices & Security

### 1.1 Security Strategy
- **HttpOnly Cookies**: Never store JWTs in `localStorage`. Use secure server-side cookies.
- **Proxy-Level Protection**: Use `src/proxy.ts` (Next.js 16) to intercept requests for auth and i18n routing.
- **Validation**: Use Zod schemas for client and server boundary checks.
- **Minimal Client State**: Only keep UI-specific state in Zustand; React Query manages all server data.

### 1.2 Recommended Tools
- **pnpm**: Mandatory for all projects.
- **TanStack Query Devtools**: Essential for debugging API cache state.
- **Shadcn CLI**: Owned UI components, no library lock-in.

---

## 2. The Tech Stack (The "Why")

| Layer | Tool | Why this tool? |
|---|---|---|
| **Framework** | Next.js 16 (App Router) | Industry-standard React with SSR, SSG, and streaming. |
| **State** | **Zustand** | Zero-boilerplate state management. No reducers, no actions, no providers needed. |
| **Server State** | **TanStack React Query** | Best-in-class data fetching with automatic caching, refetching, and devtools. |
| **i18n** | next-intl | Type-safe internationalization for the App Router. |
| **UI** | ShadCN UI | Accessible, customizable components you own. |
| **Validation** | Zod | Single source of truth for runtime and compile-time validation. |
| **Tables** | TanStack Table | Headless table with server-side sort/filter/pagination. |
| **HTTP** | Axios | File uploads, manual API calls. |
| **Theming** | next-themes | Dark/light mode with zero flash. |
| **Page Loader** | nextjs-toploader | Top progress bar on navigation for perceived performance. |
| **Testing** | Vitest + Playwright | Fast unit tests + reliable E2E coverage. |

---

## 3. Setup Checklist

- [ ] **Step 1**: Run `setup-light.sh` to scaffold the project
- [ ] **Step 2**: Configure environment variables
- [ ] **Step 3**: Set up `next.config.ts` with next-intl plugin
- [ ] **Step 4**: Implement i18n infrastructure (`src/i18n/`)
- [ ] **Step 5**: Create Zustand stores (`src/store/`)
- [ ] **Step 6**: Set up React Query client (`src/providers/QueryProvider.tsx`)
- [ ] **Step 7**: Configure route proxy (`src/proxy.ts`)
- [ ] **Step 8**: Implement Root Layout with all providers
- [ ] **Step 9**: Create error boundary pages
- [ ] **Step 10**: Set up theming and dashboard layout
- [ ] **Step 11**: Add custom components (DataTable, Paginator, etc.)

---

## 4. Project Initialization

Save as `setup-light.sh` and run `bash setup-light.sh <project-name>`:

```bash
#!/bin/bash
PROJECT_NAME=$1
if [ -z "$PROJECT_NAME" ]; then
  echo "Please provide a project name. Example: bash setup-light.sh my-app"
  exit 1
fi

echo "🚀 Scaffolding Lightweight Next.js & Shadcn UI for: $PROJECT_NAME..."

pnpm create next-app@latest "$PROJECT_NAME" --ts --tailwind --eslint --app --src-dir --import-alias "@/*" --use-pnpm --yes
cd "$PROJECT_NAME" || exit
pnpm dlx shadcn@latest init -d

pnpm add zustand @tanstack/react-query \
  react-hook-form zod @hookform/resolvers \
  @tanstack/react-table axios cookies-next \
  @sentry/nextjs next-intl next-themes nextjs-toploader \
  clsx tailwind-merge lucide-react class-variance-authority \
  react-phone-number-input date-fns react-day-picker

pnpm add -D @tanstack/react-query-devtools \
  vitest @testing-library/react @testing-library/jest-dom jsdom playwright \
  openapi-typescript prettier prettier-plugin-tailwindcss eslint-config-prettier

pnpm dlx shadcn@latest add button input label field card dialog alert-dialog \
  table dropdown-menu select textarea badge skeleton sheet separator \
  sonner avatar scroll-area tooltip popover command calendar checkbox -y

echo "✅ Setup Complete!"
```

---

## 5. Folder Structure

```
src/
├── app/
│   ├── (auth)/login/page.tsx
│   ├── (dashboard)/
│   │   ├── dashboard/page.tsx
│   │   ├── users/page.tsx
│   │   └── layout.tsx
│   ├── not-found.tsx
│   ├── error.tsx
│   ├── global-error.tsx
│   └── layout.tsx
│
├── proxy.ts
├── i18n/ (request.ts)
├── messages/en.json
│
├── components/
│   ├── ui/               # ShadCN + custom primitives
│   ├── common/           # DataTable, Paginator, ConfirmDialog, etc.
│   ├── layout/           # DashboardLayout, Sidebar, Header, etc.
│   └── forms/            # Feature forms
│
├── store/                # Zustand stores
│   └── useAuthStore.ts
│
├── hooks/api/            # React Query hooks
│   ├── useAuth.ts
│   └── useUsers.ts
│
├── providers/
│   └── QueryProvider.tsx
│
├── lib/ (utils.ts, auth.ts, form-helper.ts, validations.ts)
├── services/api/client.ts
├── types/ (api.ts, auth.ts, pagination.ts)
├── security/ (permissions.ts, guards.ts, Can.tsx)
└── constants/index.ts
```

---

## 6. Environment & next.config.ts

Same as the enterprise guide — `.env.local`, `.env.example`, and `next.config.ts` with `withNextIntl`.

---

## 7. Internationalization (next-intl)

Identical to the enterprise guide: `request.ts` and `messages/en.json`. Note that `routing.ts` and `navigation.ts` are no longer needed since we use a cookie-based approach instead of Next.js routing middleware.

---

## 8. Auth Token Strategy

Same server-first cookie approach as the enterprise guide. Use `src/lib/auth.ts` for server-side cookie helpers.

---

## 9. Route Protection — Proxy (Next.js 16+)

Same `src/proxy.ts` implementation as the enterprise guide.

---

## 10. Zustand State Management

### `src/store/useAuthStore.ts`
```typescript
import { create } from 'zustand'
import { persist, createJSONStorage } from 'zustand/middleware'
import type { AuthUser } from '@/types/auth'

interface AuthState {
  user: AuthUser | null
  isAuthenticated: boolean
  setCredentials: (user: AuthUser) => void
  logout: () => void
}

export const useAuthStore = create<AuthState>()(
  persist(
    (set) => ({
      user: null,
      isAuthenticated: false,
      setCredentials: (user) => set({ user, isAuthenticated: true }),
      logout: () => set({ user: null, isAuthenticated: false }),
    }),
    {
      name: 'auth-storage',
      storage: createJSONStorage(() => localStorage),
    }
  )
)
```

### Creating additional stores
```typescript
// src/store/useUIStore.ts — for sidebar toggle, modals, etc.
import { create } from 'zustand'

interface UIState {
  sidebarOpen: boolean
  toggleSidebar: () => void
}

export const useUIStore = create<UIState>()((set) => ({
  sidebarOpen: true,
  toggleSidebar: () => set((state) => ({ sidebarOpen: !state.sidebarOpen })),
}))
```

---

## 11. TanStack React Query — API Layer

### `src/providers/QueryProvider.tsx`
```typescript
'use client'

import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { ReactQueryDevtools } from '@tanstack/react-query-devtools'
import { useState } from 'react'

export default function QueryProvider({ children }: { children: React.ReactNode }) {
  const [queryClient] = useState(
    () =>
      new QueryClient({
        defaultOptions: {
          queries: {
            staleTime: 5 * 60 * 1000,
            retry: 1,
          },
        },
      })
  )

  return (
    <QueryClientProvider client={queryClient}>
      {children}
      <ReactQueryDevtools initialIsOpen={false} />
    </QueryClientProvider>
  )
}
```

### `src/hooks/api/useAuth.ts`
```typescript
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import apiClient from '@/lib/axios'
import { useAuthStore } from '@/store/useAuthStore'
import type { AuthUser, LoginPayload, AuthResponse } from '@/types/auth'

export function useLogin() {
  const setCredentials = useAuthStore((state) => state.setCredentials)

  return useMutation({
    mutationFn: async (payload: LoginPayload) => {
      const { data } = await apiClient.post<AuthResponse>('/auth/login', payload)
      return data
    },
    onSuccess: (data) => {
      setCredentials(data.user)
    },
  })
}

export function useMe() {
  return useQuery({
    queryKey: ['auth', 'me'],
    queryFn: async () => {
      const { data } = await apiClient.get<AuthUser>('/auth/me')
      return data
    },
  })
}
```

### `src/hooks/api/useUsers.ts`
```typescript
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import apiClient from '@/lib/axios'
import type { AuthUser } from '@/types/auth'
import type { PaginatedResponse, PaginationParams } from '@/types/pagination'

export function useGetUsers(params: PaginationParams) {
  return useQuery({
    queryKey: ['users', params],
    queryFn: async () => {
      const { data } = await apiClient.get<PaginatedResponse<AuthUser>>('/users', { params })
      return data
    },
  })
}

export function useCreateUser() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (body: Partial<AuthUser>) => apiClient.post('/users', body),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['users'] }),
  })
}

export function useDeleteUser() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (id: string) => apiClient.delete(`/users/${id}`),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['users'] }),
  })
}
```

---

## 12. Theming — next-themes

Same as the enterprise guide: `ThemeProvider.tsx` and `ThemeToggle.tsx`.

---

## 13. Root Layout

### `src/app/layout.tsx`
```typescript
import type { Metadata } from 'next'
import { Inter } from 'next/font/google'
import { NextIntlClientProvider } from 'next-intl'
import { getLocale, getMessages } from 'next-intl/server'
import NextTopLoader from 'nextjs-toploader'
import './globals.css'
import QueryProvider from '@/providers/QueryProvider'
import { ThemeProvider } from '@/components/layout/ThemeProvider'
import { Toaster } from '@/components/ui/sonner'

const inter = Inter({ subsets: ['latin'] })

export const metadata: Metadata = {
  title: process.env.NEXT_PUBLIC_APP_NAME || 'My App',
  description: 'Built with Sabuj Engineering System',
}

export default async function RootLayout({ children }: { children: React.ReactNode }) {
  const locale = await getLocale()
  const messages = await getMessages()

  return (
    <html lang={locale} suppressHydrationWarning>
      <body className={inter.className}>
        <NextTopLoader color="#2563eb" showSpinner={false} />
        <QueryProvider>
          <ThemeProvider>
            <NextIntlClientProvider messages={messages}>
              {children}
              <Toaster />
            </NextIntlClientProvider>
          </ThemeProvider>
        </QueryProvider>
      </body>
    </html>
  )
}
```

### Page Loader (`nextjs-toploader`)
Notice the `<NextTopLoader />` component right below the `<body>` tag. This automatically intercepts Next.js link clicks and router navigation events to show a thin, YouTube-style progress bar at the top of the screen. This drastically improves perceived performance for users during server-side transitions.

---

## 14. Error & Not Found Pages

Same implementations as the enterprise guide (`not-found.tsx`, `error.tsx`, `global-error.tsx`).

---

## 15. Core Pages & Layouts

To avoid 404s when running the project, create these minimum required pages:

### `src/app/(auth)/login/page.tsx`
```typescript
import { useTranslations } from 'next-intl'

export default function LoginPage() {
  const t = useTranslations('auth')
  return (
    <div className="flex min-h-screen items-center justify-center bg-muted/50">
      <div className="w-full max-w-md p-8 space-y-6 bg-background rounded-lg shadow-md border">
        <div className="space-y-2 text-center">
          <h1 className="text-3xl font-bold">{t('loginTitle')}</h1>
          <p className="text-muted-foreground">{t('loginSubtitle')}</p>
        </div>
      </div>
    </div>
  )
}
```

### `src/app/(dashboard)/layout.tsx`
```typescript
import { UserMenu } from '@/components/layout/UserMenu'
import { ThemeToggle } from '@/components/layout/ThemeToggle'

export default function DashboardLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="flex h-screen overflow-hidden bg-background">
      <div className="w-64 border-r bg-muted/20 hidden md:block">
        <div className="p-4 border-b">
          <h2 className="text-lg font-bold">My App</h2>
        </div>
      </div>
      <div className="flex-1 flex flex-col h-screen overflow-hidden">
        <header className="h-16 border-b px-6 flex items-center justify-between bg-background">
          <div className="font-semibold md:hidden">My App</div>
          <div className="hidden md:block" />
          <div className="flex items-center gap-4">
            <ThemeToggle />
            <UserMenu />
          </div>
        </header>
        <main className="flex-1 overflow-y-auto p-6">
          {children}
        </main>
      </div>
    </div>
  )
}
```

### `src/app/(dashboard)/dashboard/page.tsx`
```typescript
import { useTranslations } from 'next-intl'

export default function DashboardPage() {
  const t = useTranslations('nav')
  return (
    <div className="space-y-6">
      <h1 className="text-3xl font-bold tracking-tight">{t('dashboard')}</h1>
      <div className="p-6 border rounded-lg bg-card">
        <p className="text-muted-foreground">Welcome to the dashboard!</p>
      </div>
    </div>
  )
}
```

### `src/app/(dashboard)/users/page.tsx`
```typescript
import { useTranslations } from 'next-intl'

export default function UsersPage() {
  const t = useTranslations('nav')
  return (
    <div className="space-y-6">
      <h1 className="text-3xl font-bold tracking-tight">{t('users')}</h1>
      <div className="p-6 border rounded-lg bg-card">
        <p className="text-muted-foreground">Manage users here.</p>
      </div>
    </div>
  )
}
```

---

## 15.5 Dashboard Layout Components

Same implementations as the enterprise guide, but `UserMenu.tsx` uses Zustand instead of Redux:

### `src/components/layout/UserMenu.tsx` (Light version)
```typescript
'use client'

import { useTranslations } from 'next-intl'
import { LogOut } from 'lucide-react'
import { useAuthStore } from '@/store/useAuthStore'
import { useRouter } from 'next/navigation'
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuLabel, DropdownMenuSeparator, DropdownMenuTrigger } from '@/components/ui/dropdown-menu'
import { Avatar, AvatarFallback } from '@/components/ui/avatar'
import { Button } from '@/components/ui/button'

export function UserMenu() {
  const t = useTranslations('auth')
  const router = useRouter()
  const { user, logout } = useAuthStore()

  const handleLogout = () => { logout(); router.push('/login') }
  const initials = user?.fullName?.split(' ').map((n) => n[0]).join('').toUpperCase()

  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button variant="ghost" className="relative h-9 w-9 rounded-full">
          <Avatar className="h-9 w-9"><AvatarFallback>{initials || 'U'}</AvatarFallback></Avatar>
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end">
        <DropdownMenuLabel>
          <p className="text-sm font-medium">{user?.fullName}</p>
          <p className="text-xs text-muted-foreground">{user?.email}</p>
        </DropdownMenuLabel>
        <DropdownMenuSeparator />
        <DropdownMenuItem onClick={handleLogout} className="cursor-pointer text-destructive">
          <LogOut className="mr-2 h-4 w-4" />{t('logout')}
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  )
}
```

---

## 16. Form & Field Component Usage

The latest Shadcn UI uses the `field` component (from Radix) instead of `form`. Here's how to build forms with React Hook Form and the `field` component:

### `src/components/forms/LoginForm.tsx`
```typescript
'use client'

import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import * as z from 'zod'
import { useTranslations } from 'next-intl'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Field, FieldControl, FieldDescription, FieldLabel, FieldMessage } from '@/components/ui/field'
import { useLogin } from '@/hooks/api/useAuth'
import { toast } from 'sonner'

const loginSchema = z.object({
  email: z.string().email('Invalid email address'),
  password: z.string().min(6, 'Password must be at least 6 characters'),
})

type LoginFormData = z.infer<typeof loginSchema>

export function LoginForm() {
  const t = useTranslations('auth')
  const { mutate: login, isPending } = useLogin()
  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<LoginFormData>({
    resolver: zodResolver(loginSchema),
  })

  const onSubmit = async (data: LoginFormData) => {
    try {
      login(data, {
        onSuccess: () => {
          toast.success(t('loginSuccess'))
        },
        onError: (error) => {
          toast.error(error.message || t('loginError'))
        },
      })
    } catch (error) {
      toast.error(t('loginError'))
    }
  }

  return (
    <form onSubmit={handleSubmit(onSubmit)} className="space-y-6">
      <Field>
        <FieldLabel>{t('emailLabel')}</FieldLabel>
        <FieldControl>
          <Input {...register('email')} placeholder="user@example.com" />
        </FieldControl>
        {errors.email && <FieldMessage>{errors.email.message}</FieldMessage>}
      </Field>

      <Field>
        <FieldLabel>{t('passwordLabel')}</FieldLabel>
        <FieldControl>
          <Input {...register('password')} type="password" placeholder="••••••••" />
        </FieldControl>
        <FieldDescription>{t('passwordHelp')}</FieldDescription>
        {errors.password && <FieldMessage>{errors.password.message}</FieldMessage>}
      </Field>

      <Button type="submit" disabled={isPending} className="w-full">
        {isPending ? t('loggingIn') : t('login')}
      </Button>
    </form>
  )
}
```

### Form Submit Handler Helper
Create `src/lib/form-helper.ts` for reusable form submission logic:

```typescript
import { AxiosError } from 'axios'
import { toast } from 'sonner'

export function createFormSubmitHandler<T, R = any>(
  mutationFn: (data: T) => Promise<R>,
  options?: {
    onSuccess?: (data: R) => void | Promise<void>
    onError?: (error: string) => void
    successMessage?: string
    errorMessage?: string
  }
) {
  return async (data: T) => {
    try {
      const result = await mutationFn(data)
      options?.onSuccess?.(result)
      if (options?.successMessage) {
        toast.success(options.successMessage)
      }
      return result
    } catch (error) {
      const message =
        error instanceof AxiosError
          ? error.response?.data?.message || error.message
          : 'An error occurred'
      options?.onError?.(message)
      if (options?.errorMessage) {
        toast.error(options.errorMessage)
      }
      throw error
    }
  }
}

export function handleFormResponse(response: any, defaultMessage?: string) {
  if (response?.success) {
    toast.success(response?.message || defaultMessage || 'Success!')
    return true
  } else {
    toast.error(response?.message || defaultMessage || 'Failed!')
    return false
  }
}
```

### Advanced Form Example with Dynamic Fields
```typescript
'use client'

import { useForm, useFieldArray } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import * as z from 'zod'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Field, FieldControl, FieldLabel, FieldMessage } from '@/components/ui/field'
import { Textarea } from '@/components/ui/textarea'
import { X } from 'lucide-react'
import { createFormSubmitHandler } from '@/lib/form-helper'
import apiClient from '@/lib/axios'

const productSchema = z.object({
  name: z.string().min(1, 'Product name is required'),
  description: z.string().min(10, 'Description must be at least 10 characters'),
  price: z.number().positive('Price must be positive'),
  tags: z.array(z.object({ value: z.string().min(1) })).min(1, 'Add at least one tag'),
})

type ProductFormData = z.infer<typeof productSchema>

export function ProductForm() {
  const {
    register,
    handleSubmit,
    control,
    formState: { errors, isSubmitting },
  } = useForm<ProductFormData>({
    resolver: zodResolver(productSchema),
    defaultValues: {
      tags: [{ value: '' }],
    },
  })

  const { fields, append, remove } = useFieldArray({
    control,
    name: 'tags',
  })

  const onSubmit = handleSubmit(
    createFormSubmitHandler(
      (data) => apiClient.post('/products', data),
      {
        successMessage: 'Product created successfully!',
        errorMessage: 'Failed to create product',
      }
    )
  )

  return (
    <form onSubmit={onSubmit} className="space-y-6 max-w-2xl">
      <Field>
        <FieldLabel>Product Name</FieldLabel>
        <FieldControl>
          <Input {...register('name')} placeholder="Enter product name" />
        </FieldControl>
        {errors.name && <FieldMessage>{errors.name.message}</FieldMessage>}
      </Field>

      <Field>
        <FieldLabel>Description</FieldLabel>
        <FieldControl>
          <Textarea {...register('description')} placeholder="Product details..." rows={4} />
        </FieldControl>
        {errors.description && <FieldMessage>{errors.description.message}</FieldMessage>}
      </Field>

      <Field>
        <FieldLabel>Price</FieldLabel>
        <FieldControl>
          <Input {...register('price', { valueAsNumber: true })} type="number" placeholder="0.00" />
        </FieldControl>
        {errors.price && <FieldMessage>{errors.price.message}</FieldMessage>}
      </Field>

      <div className="space-y-2">
        <FieldLabel>Tags</FieldLabel>
        {fields.map((field, index) => (
          <div key={field.id} className="flex gap-2">
            <Field className="flex-1">
              <FieldControl>
                <Input {...register(`tags.${index}.value`)} placeholder="Add a tag" />
              </FieldControl>
            </Field>
            <Button
              type="button"
              variant="ghost"
              size="sm"
              onClick={() => remove(index)}
              disabled={fields.length === 1}
            >
              <X className="h-4 w-4" />
            </Button>
          </div>
        ))}
        <Button
          type="button"
          variant="outline"
          size="sm"
          onClick={() => append({ value: '' })}
        >
          Add Tag
        </Button>
        {errors.tags && <FieldMessage>{errors.tags.message}</FieldMessage>}
      </div>

      <Button type="submit" disabled={isSubmitting}>
        {isSubmitting ? 'Creating...' : 'Create Product'}
      </Button>
    </form>
  )
}
```

### Key Points for Field Component Usage

1. **Import**: Use `Field`, `FieldControl`, `FieldLabel`, `FieldDescription`, and `FieldMessage` from `@/components/ui/field`
2. **Structure**: Wrap each input with `<Field>` and `<FieldControl>`
3. **Error Handling**: Display validation errors with `<FieldMessage>`
4. **Accessibility**: `FieldLabel` automatically links to inputs via proper ID/htmlFor attributes
5. **Descriptions**: Use `<FieldDescription>` for helper text below labels

---

## 17. Custom Components

All custom components from the enterprise guide are **fully reusable** in the light version:

- **DataTable** — Same implementation. Use React Query hooks instead of RTK Query hooks.
- **Paginator** — Identical.
- **ConfirmDialog** — Identical.
- **StatusBadge** — Identical.
- **PageHeader** — Identical.
- **EmptyState** — Identical.
- **DynamicSearchControls** — Identical.
- **PhoneInput** — Identical.
- **Timeline** — Identical.
- **Form Helpers** — Identical (`handleFormResponse`, `createFormSubmitHandler`).

The only difference is in the **data source**: use React Query hooks instead of RTK Query hooks.

```typescript
// Enterprise: const { data, isLoading } = useGetUsersQuery({ page, limit })
// Light:     const { data, isLoading } = useGetUsers({ page, limit })
```

---

## 18. RBAC Layer

Same `permissions.ts` and `guards.ts` as the enterprise guide.

### `src/auth/Can.tsx` (Light version — uses Zustand)
```typescript
'use client'

import { hasPermission } from './permissions'
import { useAuthStore } from '@/store/useAuthStore'

export function Can({ permission, children, fallback = null }: {
  permission: string; children: React.ReactNode; fallback?: React.ReactNode
}) {
  const user = useAuthStore((state) => state.user)
  if (!hasPermission(user, permission)) return fallback
  return children
}
```

---

## 19. TypeScript Types, Constants, Axios Client

All identical to the enterprise guide. See sections 21-23 of the enterprise guide.

---

## 20. Architecture Rules

### Data Flow (Light Version)
```
Page → Server Component (requireAuth/requirePermission)
  → Client component (interaction boundary)
    → DynamicSearchControls + DataTable + Paginator
      → React Query hook (useGetUsers)
        → Axios client → API
  → Forms → createFormSubmitHandler() → handleFormResponse()
```

### State Rules
- **Server cache**: TanStack React Query (never `useState` + `useEffect` for API calls)
- **Global UI state**: Zustand (sidebar toggle, modals)
- **Auth state**: Zustand with `persist` middleware
- **Form state**: React Hook Form + Zod
- **Tokens**: Server-owned cookies, never Zustand/localStorage

---

## 21. Anti-Patterns

```
❌ useEffect + fetch for data → use React Query hooks
❌ localStorage for tokens → use HttpOnly cookies
❌ Manual try/catch in every form → use createFormSubmitHandler()
❌ Hardcoded UI strings → use next-intl messages
❌ Editing ShadCN-generated files → use shadcn CLI
❌ Building custom filter UIs per page → use DynamicSearchControls
❌ Putting server data in Zustand → let React Query cache it
```

---

## 22. How to Add a New Feature

1. **Types** → `src/types/product.ts`
2. **Validation** → `src/lib/validations.ts`
3. **API Hooks** → `src/hooks/api/useProducts.ts` (React Query)
4. **Form** → `src/components/forms/ProductForm.tsx`
5. **Page** → `src/app/(dashboard)/products/page.tsx` with DataTable
6. **Permissions** → add to PERMISSIONS + `<Can />`
7. **Nav** → add to `NAV_ITEMS` in Sidebar
8. **Messages** → add to `messages/en.json`
9. **Tests** → Vitest for validation, Playwright for CRUD

---

## 23. Version Notes

| Package | Version | Notes |
|---|---|---|
| Next.js | 16.x | Proxy at `src/proxy.ts` |
| Zustand | 5.x | Lightweight state management |
| TanStack Query | 5.x | Server state / API caching |
| TanStack Table | 8.x | Advanced tables |
| next-intl | 4.x | `localePrefix: 'never'` |
| CVA | 0.7.x | Component variants |
