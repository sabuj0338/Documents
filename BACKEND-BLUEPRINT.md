# Go Fiber API Blueprint

A reusable blueprint taken from `xstore-backend`, a Go + Fiber modular monolith.
To reuse it, drop this file into a new project as `CLAUDE.md` / `AGENTS.md`, or tell your agent:
"Follow BACKEND-BLUEPRINT.md for architecture, auth and response structure."

Replace `<app>`, `<module>` and `github.com/<org>/<app>` with your own names. The xstore-specific parts
(vendor/store tenancy, storefront, provisioning) are marked **optional**.

It pairs with the frontend blueprint (`PROJECT-BLUEPRINT.md`): the React client expects exactly the
response envelope and auth flow described here.

---

## 1. Tech stack

| Concern | Choice |
|---|---|
| Language | **Go 1.25+** |
| HTTP | **gofiber/fiber v2** (`CaseSensitive: true`, custom `ErrorHandler`) |
| DB | **PostgreSQL 16** via **jackc/pgx v5** (`pgxpool`) |
| Queries | **sqlc** (`sql_package: pgx/v5`), one sqlc package per module |
| Migrations | **golang-migrate v4** (SQL files in `migrations/`, run on boot or via `cmd/migrate`) |
| Cache / rate limit | **redis/go-redis v9** |
| Auth | **golang-jwt/jwt v5** (HS256 access token) + opaque refresh token (SHA-256 hashed in DB) |
| Passwords | `golang.org/x/crypto/bcrypt` |
| Validation | **go-playground/validator v10** (struct tags) |
| Logging | **rs/zerolog** |
| Config | `joho/godotenv` + env vars → typed `Config` struct |
| IDs | `google/uuid` (UUID PKs, `gen_random_uuid()` / UUIDv7) |
| Files (optional) | aws-sdk-go-v2 S3 / R2 / Cloudinary / local storage behind one interface |
| Dev tooling | Air (hot reload), staticcheck, gofmt, Make |
| Deploy | Multi-stage Docker → static binary on Alpine, non-root user, `HEALTHCHECK /live` |

### Makefile targets

```make
run:          go run ./cmd/api
dev:          air -c .air.toml
build:        go build -o ./bin/api ./cmd/api
test:         go test ./...
lint:         go vet ./... && gofmt -l . (must be empty) && staticcheck ./...
sqlc:         sqlc generate
migrate-up:   go run ./cmd/migrate -direction up
migrate-down: go run ./cmd/migrate -direction down -steps 1
```

Before finishing any change: `make lint && make test && go build ./...`

### `.env.example`

```bash
APP_ENV=development
APP_NAME=<app>
SERVER_HOST=0.0.0.0
SERVER_PORT=8080
DATABASE_URL=postgres://<app>:<app>@localhost:5432/<app>?sslmode=disable
REDIS_URL=redis://localhost:6379/0
LOG_LEVEL=debug
TRACING_ENABLED=true
RATE_LIMIT_MAX=120
RATE_LIMIT_WINDOW_SECONDS=60
RATE_LIMIT_SENSITIVE_MAX=20          # login / forgot / reset, per IP per route
# PROXY_HEADER=CF-Connecting-IP
# TRUSTED_PROXIES=
RUN_MIGRATIONS_ON_BOOT=true
JWT_SECRET=change-me
JWT_REFRESH_SECRET=change-me-refresh
JWT_ISSUER=<app>
JWT_ACCESS_TTL_MINUTES=15
JWT_REFRESH_TTL_DAYS=7
```

---

## 2. Architecture: modular monolith

A single deployable app. Each business domain is a **module** (bounded context) under `internal/modules/`.

```text
cmd/
  api/main.go              # bootstrap only: config.Load() → app.New(cfg) → app.Run()
  migrate/main.go          # standalone migration runner
internal/
  kernel/                  # runtime plumbing, no business logic
    app/app.go             # wires DB, Redis, bus, modules, middleware, routes; graceful shutdown
    config/                # typed Config from env
    container/             # DI container passed to every module
    context/               # RequestContext / TenantContext stored in c.UserContext()
    database/              # pgxpool connect, migrations, RunInTransaction, AfterCommit
    cache/                 # Redis client + JSON helpers
    auth/                  # JWTAuth, RBAC, TenantGuard middleware, route→permission rules, public paths
    middleware/            # Recover, RequestID, Trace, RequestLogger, RateLimit, Maintenance…
    eventbus/              # in-memory pub/sub + transactional outbox
    scheduler/             # interval jobs (advisory-lock so one instance runs each job)
    logger/                # zerolog wrapper (WithRequestID, WithTenant)
    health/                # /health /live /ready
    storage/               # file storage providers (optional)
  shared/                  # pure helpers, no business logic, no module imports
    response/              # Response[T] envelope + OK/Created/Paginated/Fail/FromError
    errors/                # AppError, ValidationError + constructors
    pagination/            # Page, PaginatedResult[T], FromQuery, NewResult
    validator/             # go-playground wrapper → ValidationError
  modules/
    registry.go            # Module interface + Registry
    <module>/              # see §3
migrations/                # 000001_init.up.sql / .down.sql …
queries/                   # kernel-level sqlc queries (health etc.)
sqlc.yaml
```

### Module interface

```go
// internal/modules/registry.go
type Module interface {
    Name() string
    Register(app *fiber.App, c *container.Container) // routes
    RegisterEvents(bus eventbus.EventBus)            // subscriptions
    RegisterJobs()                                   // scheduler jobs
}
```

### Container (dependency injection)

```go
type Container struct {
    Config     *config.Config
    Logger     *logger.Logger
    DB         *database.DB        // Pool *pgxpool.Pool
    Redis      *cache.Redis
    EventBus   eventbus.EventBus
    Outbox     *eventbus.Outbox    // optional durable events
    Storage    storage.Storage     // optional
    Scheduler  scheduler.Scheduler
    Validator  *validator.Validator
    AppContext *contextx.ApplicationContext
}
```

### Bootstrap order (`kernel/app/app.go`)

1. Logger → run migrations (if `RUN_MIGRATIONS_ON_BOOT`) → connect Postgres → connect Redis.
2. Event bus (+ outbox), storage, scheduler, validator → `container.New(...)`.
3. Construct modules **in dependency order**, passing other modules' **facades** into constructors:
   `authModule := authmod.New(c)` → `userModule := usermod.New(c, authModule.Facade())` → …
4. `registry := modules.NewRegistry(...)` → `RegisterEvents(bus)` → `RegisterJobs()`.
5. `fiber.New(Config{AppName, ErrorHandler, CaseSensitive: true, ProxyHeader…})`.
6. Global middleware chain (order matters):

```go
f.Use(cors.New())
f.Use(middleware.Recover(log))
f.Use(middleware.RequestID())          // X-Request-ID → RequestContext
f.Use(middleware.Trace())              // X-Trace-ID / X-Span-ID (optional)
f.Use(middleware.RequestLogger(log))
f.Use(middleware.RateLimit(redis, max, window, env))                  // global, per IP
f.Use(middleware.RateLimitPaths(redis, sensitivePaths, sensMax, ...)) // login/forgot/reset
// optional: StoreResolver (tenant from Host), MaintenanceMode, Turnstile captcha
f.Use(auth.JWTAuth(authModule.JWTValidator()))
f.Use(auth.TenantGuard())              // optional: platform vs tenant separation
f.Use(auth.RBAC(authModule.PermissionChecker()))
health.RegisterRoutes(f, c)
registry.RegisterRoutes(f, c)
```

7. Start scheduler; `Run()` listens and on SIGINT/SIGTERM does `ShutdownWithContext` (10s) → stop scheduler → drain event bus → close Redis/DB.

---

## 3. Module layout & layer rules

```text
internal/modules/<module>/
  module.go                      # New(c, deps...) wires repo → service → facade; implements Module
  delivery/http/handler.go       # Handler struct, handlers, RegisterRoutes(app, h)
  application/service.go         # use cases: orchestration, transactions, events
  domain/
    entity/                      # entities, constants, invariants (no HTTP/SQL)
    event/events.go              # event names + payload structs
    service/                     # pure domain helpers (e.g. password hashing)
  dto/<module>.go                # request/response structs with json + validate tags
  mapper/<module>.go             # entity ↔ DTO
  facade/facade.go               # the ONE public interface other modules may use
  permissions/permissions.go     # permission slug constants
  queries/<module>.sql           # sqlc queries
  infrastructure/
    persistence/repository.go    # wraps sqlc; SQL + mapping only
    persistence/sqlc/            # generated — do not edit
    cache/ token/ mailer/ …      # adapters to external systems
```

**Request flow:** `delivery/http` → `facade` → `application` → `domain` + `infrastructure`

| Layer | Allowed | Forbidden |
|---|---|---|
| Handler | Parse body/query/params, `validator.Validate`, read context, call facade, choose status, map via `response.*` | Business logic, SQL, transactions |
| Application (service) | Use cases, transactions (`database.RunInTransaction`), calling other facades, publishing events, returning `apperrors.*` | Raw SQL, Fiber types |
| Domain | Entities, constants, invariants | HTTP, SQL |
| Repository | SQL via sqlc, row mapping | Business rules |

**Boundaries**
- A module owns its tables. Never read or write another module's tables or call its repository.
- Cross-module **read or action** → that module's **Facade** (an interface, passed into `New`).
- Cross-module **notification** → **Event** on the bus. Long-running work → **Job**. External service → infrastructure adapter.
- DTO ≠ entity: always map at the boundary (`mapper/`).
- `shared/` never imports a module.

### module.go template

```go
package <module>mod

type Module struct {
    facade  facade.<Module>Facade
    service *application.Service
}

func New(c *container.Container, other otherfacade.OtherFacade) *Module {
    repo := persistence.NewRepository(c.DB.Pool)
    svc := application.NewService(repo, c.EventBus, other)
    return &Module{facade: facade.New(svc), service: svc}
}

func (m *Module) Name() string { return "<module>" }
func (m *Module) Register(app *fiber.App, c *container.Container) {
    h := http.NewHandler(m.facade, c.Validator)
    http.RegisterRoutes(app, h)
}
func (m *Module) RegisterEvents(bus eventbus.EventBus) {
    // bus.Subscribe(otherevent.Something, m.service.OnSomething)
}
func (m *Module) RegisterJobs()                     {}
func (m *Module) Facade() facade.<Module>Facade      { return m.facade }
```

### Handler template

```go
type Handler struct {
    facade    facade.ThingFacade
    validator *validator.Validator
}

func (h *Handler) Create(c *fiber.Ctx) error {
    var req dto.CreateThingRequest
    if err := c.BodyParser(&req); err != nil {
        return response.Fail(c, fiber.StatusBadRequest, "Invalid request body", map[string]string{"code": "BAD_REQUEST"})
    }
    if err := h.validator.Validate(req); err != nil {
        return response.FromError(c, err) // 422 with field errors
    }
    result, err := h.facade.Create(c.UserContext(), req)
    if err != nil {
        return response.FromError(c, err)
    }
    return response.Created(c, "Thing created successfully", result)
}

func (h *Handler) List(c *fiber.Ctx) error {
    result, err := h.facade.List(c.UserContext(), pagination.FromQuery(c))
    if err != nil {
        return response.FromError(c, err)
    }
    return response.Paginated(c, "Things retrieved successfully", result)
}

func RegisterRoutes(app *fiber.App, h *Handler) {
    g := app.Group("/api/v1/admin/things")
    g.Get("/", h.List)
    g.Post("/", h.Create)
    g.Get("/:id", h.Get)
    g.Patch("/:id", h.Update)
    g.Delete("/:id", h.Delete)
}
```

### Service list template

```go
func (s *Service) List(ctx context.Context, page pagination.Page) (pagination.PaginatedResult[dto.ThingResponse], error) {
    limit, offset := int32(page.Limit), int32((page.Page-1)*page.Limit)
    rows, err := s.repo.List(ctx, limit, offset)
    if err != nil {
        return pagination.PaginatedResult[dto.ThingResponse]{}, apperrors.Internal("Failed to list things")
    }
    total, err := s.repo.Count(ctx)
    if err != nil {
        return pagination.PaginatedResult[dto.ThingResponse]{}, apperrors.Internal("Failed to count things")
    }
    out := make([]dto.ThingResponse, 0, len(rows))
    for _, r := range rows {
        out = append(out, mapper.ToThingResponse(r))
    }
    return pagination.NewResult(out, page, int(total)), nil
}
```

Conventions: JSON fields are **camelCase**, timestamps are RFC3339 UTC strings, success messages are human sentences ("X retrieved successfully").

---

## 4. Response structure

Every endpoint returns the same envelope. **Never** call `c.JSON` directly in handlers. Always use `shared/response`.

```go
// shared/response/response.go
type Response[T any] struct {
    Success bool        `json:"success"`
    Message string      `json:"message"`
    Data    T           `json:"data"`
    Errors  interface{} `json:"errors"`
}
```

### Builders (`shared/response/builder.go`)

| Function | Status | Use |
|---|---|---|
| `response.OK(c, msg, data)` | 200 | reads, updates, actions (`response.OK[any](c, msg, nil)` for no data) |
| `response.Created(c, msg, data)` | 201 | creates |
| `response.Paginated(c, msg, pagination.PaginatedResult[T])` | 200 | lists |
| `response.Fail(c, status, msg, errors)` | any | explicit failures (middleware, bad body) |
| `response.ValidationFail(c, map[string][]string)` | 422 | field errors |
| `response.FromError(c, err)` | mapped | turn any service error into the envelope |

`FromError` mapping:
- `*apperrors.ValidationError` → **422** `"Validation failed"`, `errors = { field: ["msg", …] }`
- `*apperrors.AppError` → `appErr.Status`, `errors = { "code": appErr.Code }`
- anything else → **500** `"An unexpected error occurred"`, `{ "code": "INTERNAL_ERROR" }` (never leak internals)

The Fiber `ErrorHandler` and the `Recover` middleware also go through `response.Fail` / `FromError`, so panics and router 404/405 responses use the same shape.

### Examples

```json
// 200 success
{ "success": true, "message": "Profile retrieved successfully", "data": { "id": "…", "email": "a@b.com" }, "errors": null }

// 200 paginated
{ "success": true, "message": "Things retrieved successfully",
  "data": { "results": [ … ], "page": 1, "limit": 20, "totalPages": 5, "totalResults": 93 },
  "errors": null }

// 422 validation
{ "success": false, "message": "Validation failed", "data": null,
  "errors": { "email": ["Email must be a valid email"], "password": ["Password must be at least 8 characters"] } }

// 401 / 404 / 409 app error
{ "success": false, "message": "Invalid email or password", "data": null, "errors": { "code": "UNAUTHORIZED" } }

// 403 RBAC
{ "success": false, "message": "You do not have permission to perform this action", "data": null,
  "errors": { "code": "FORBIDDEN", "required_permissions": ["users.invite"] } }
```

### Error codes

`BAD_REQUEST` 400 · `UNAUTHORIZED` 401 · `FORBIDDEN` 403 · `NOT_FOUND` 404 · `CONFLICT` 409 · validation 422 · `RATE_LIMITED` 429 · `INTERNAL_ERROR` 500 · `MAINTENANCE_MODE` / `NOT_READY` 503.

### App errors (`shared/errors`)

```go
type AppError struct { Code, Message string; Status int }
type ValidationError struct { Fields map[string][]string }

apperrors.BadRequest(msg)   // 400 BAD_REQUEST
apperrors.Unauthorized(msg) // 401 UNAUTHORIZED
apperrors.Forbidden(msg)    // 403 FORBIDDEN
apperrors.NotFound(msg)     // 404 NOT_FOUND
apperrors.Conflict(msg)     // 409 CONFLICT
apperrors.Internal(msg)     // 500 INTERNAL_ERROR
apperrors.New(code, msg, status)
apperrors.Validation(map[string][]string{"currentPassword": {"Current password is incorrect"}})
```

Services return these errors and handlers only pass them on with `response.FromError`.

### Pagination (`shared/pagination`)

```go
type Page struct{ Page, Limit int }
type PaginatedResult[T any] struct {
    Results      []T `json:"results"`      // never null: nil becomes []
    Page         int `json:"page"`
    Limit        int `json:"limit"`
    TotalPages   int `json:"totalPages"`
    TotalResults int `json:"totalResults"`
}
// FromQuery(c): ?page=1&limit=20, defaults 1/20, max limit 100
// NewResult(items, page, total)
```

### Validator (`shared/validator`)

Wraps go-playground; `Validate(struct)` returns `*apperrors.ValidationError` with `field → []message`
("X is required", "X must be a valid email", "X must be at least N characters"…). Field names in the error
map should use the **same key as the JSON field** (camelCase) so the frontend can attach errors to inputs.

---

## 5. Auth API structure

### Data model (migration)

```sql
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NULL,                         -- optional (xstore: vendor_id); NULL = platform operator
  email VARCHAR(255) NOT NULL UNIQUE,
  full_name VARCHAR(255) NOT NULL DEFAULT '',
  phone VARCHAR(50), avatar_url TEXT,
  password_hash VARCHAR(255) NOT NULL DEFAULT '',
  status VARCHAR(50) NOT NULL DEFAULT 'active', -- active | invited | suspended
  token_version INT NOT NULL DEFAULT 1,        -- bump to kill all access tokens
  last_login_at TIMESTAMPTZ,
  invite_token_hash VARCHAR(255), invite_expires_at TIMESTAMPTZ,
  password_reset_token_hash VARCHAR(255), password_reset_expires_at TIMESTAMPTZ,
  is_email_verified BOOLEAN NOT NULL DEFAULT FALSE,
  email_verification_token_hash VARCHAR(255), email_verification_expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(), updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TABLE roles (id UUID PK, name VARCHAR(100) UNIQUE, description TEXT, is_static BOOLEAN, …);
CREATE TABLE permissions (id UUID PK, key VARCHAR(100) UNIQUE, description TEXT, …);   -- 'users.read'
CREATE TABLE user_roles (user_id → users, role_id → roles, PK(user_id, role_id));
CREATE TABLE role_permissions (role_id → roles, permission_id → permissions, PK(role_id, permission_id));
CREATE TABLE refresh_tokens (
  id UUID PK, user_id UUID → users ON DELETE CASCADE,
  token_hash VARCHAR(255) NOT NULL, expires_at TIMESTAMPTZ NOT NULL,
  is_revoked BOOLEAN NOT NULL DEFAULT FALSE, created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
-- seed: permissions, a static 'super-admin' role with all permissions, other fixed roles
```

Permission slugs follow `<resource>.<action>`: `users.read`, `users.invite`, `users.assign-role`, `roles.read`, …

### Endpoints

Mounted per surface, with the same handlers on each, e.g. `/api/v1/admin/auth/*` (tenant users) and `/api/v1/platform/auth/*` (platform operators). Use just one group if you have one surface.

| Method | Path | Auth | Body | `data` returned |
|---|---|---|---|---|
| POST | `/auth/login` | public, rate-limited, optional captcha | `{ email, password }` | `AuthTokenResponse` |
| POST | `/auth/refresh` | public | `{ refreshToken }` | `AuthTokenResponse` (refresh rotated) |
| POST | `/auth/logout` | public | `{ refreshToken }` | `null` |
| POST | `/auth/forgot-password` | public, rate-limited | `{ email }` | `null` (always 200, no user enumeration) |
| POST | `/auth/reset-password` | public, rate-limited | `{ token, newPassword }` | `null` |
| POST | `/auth/verify-email` | public | `{ token }` | `null` |
| POST | `/auth/resend-verification` | public | `{ email }` | `null` (always 200) |
| POST | `/auth/accept-invite` | public | `{ token, password, fullName }` | `AuthTokenResponse` |
| POST | `/auth/invite` | JWT + `users.invite` | `{ email, fullName, roleIds[] }` | `{ userId, inviteToken }` (201) |
| GET | `/auth/me` | JWT | none | `UserResponse` |
| PATCH | `/auth/me` | JWT | `{ fullName, phone?, avatarUrl? }` | `UserResponse` |
| POST | `/auth/change-password` | JWT | `{ currentPassword, newPassword }` | `null` |

Public paths are listed explicitly in `kernel/auth/public.go`; everything else under the protected prefixes requires a JWT.

### DTOs

```go
type LoginRequest struct {
    Email    string `json:"email" validate:"required,email"`
    Password string `json:"password" validate:"required,min=8"`
    Audience string `json:"-"` // set by handler from the route prefix
}
type RefreshRequest   struct { RefreshToken string `json:"refreshToken" validate:"required"` }
type ResetPasswordRequest struct {
    Token       string `json:"token" validate:"required"`
    NewPassword string `json:"newPassword" validate:"required,min=8"`
}
type AcceptInviteRequest struct {
    Token    string `json:"token" validate:"required"`
    Password string `json:"password" validate:"required,min=8"`
    FullName string `json:"fullName" validate:"required,min=2"`
}

type UserResponse struct {
    ID          string   `json:"id"`
    Email       string   `json:"email"`
    FullName    string   `json:"fullName"`
    Phone       *string  `json:"phone"`
    AvatarURL   *string  `json:"avatarUrl"`
    TenantID    *string  `json:"tenantId"`     // xstore: vendorId
    Roles       []string `json:"roles"`
    Permissions []string `json:"permissions"`  // frontend uses this for <Can> and menu filtering
}
type AuthTokenResponse struct {
    User         UserResponse `json:"user"`
    AccessToken  string       `json:"accessToken"`
    RefreshToken string       `json:"refreshToken"`
}
```

Login response:

```json
{
  "success": true,
  "message": "Login successful",
  "data": {
    "user": { "id": "…", "email": "admin@x.com", "fullName": "Admin", "phone": null, "avatarUrl": null,
              "tenantId": null, "roles": ["super-admin"], "permissions": ["users.read", "users.invite"] },
    "accessToken": "eyJhbGciOiJIUzI1NiIs…",
    "refreshToken": "q3J…opaque-base64url…"
  },
  "errors": null
}
```

### Tokens

**Access token**: JWT, HS256, short TTL (15 min).

```go
type accessClaims struct {
    Email        string   `json:"email"`
    TenantID     string   `json:"tenant_id,omitempty"`
    TokenVersion int      `json:"token_version"`
    Permissions  []string `json:"permissions"`
    Roles        []string `json:"roles"`
    jwt.RegisteredClaims  // sub=userID, iss=JWT_ISSUER, aud=[surface], exp, iat
}
```

Validation: the signing method must be HS256, the issuer must match, `exp` is required, and there must be **exactly one audience**.

**Refresh / invite / reset / verify tokens**: 32 random bytes, base64url, **opaque**. Only the **SHA-256 hex** goes into the DB, so it can be found with an equality lookup. Don't use bcrypt here because it isn't deterministic. TTLs: refresh 7d, invite 72h, reset 1h.

### Flows (application service)

- **Login**: normalize the email (lowercase, trim). Return the same message, `"Invalid email or password"`, for an unknown email and a wrong password. Check `status == active`, then `bcrypt.Compare`, then email verification (can be switched off in settings). Load roles and permissions, and check the audience matches the surface *after* the password check. Issue tokens and update `last_login_at`.
- **issueTokens**: sign the access JWT, generate the refresh token, store its hash with `expires_at`, and return `{ user, accessToken, refreshToken }`.
- **Refresh**: hash the token and look it up (not revoked, not expired). Re-check the user's status and verification, **revoke the old token (rotation)**, reload RBAC and issue a new pair.
- **Logout**: revoke the refresh token by its hash. An unknown token is not an error.
- **ForgotPassword**: always succeeds. Only for active users who have a password, it stores the hashed reset token and publishes a `PasswordResetRequested` event. A notification module sends the email.
- **ResetPassword**: find the user by token hash and check it hasn't expired. Set the new bcrypt hash and mark the email as verified. **Revoke all refresh tokens** and invalidate the RBAC cache.
- **ChangePassword**: verify the current password (on failure return a `ValidationError` on `currentPassword`). Reject a new password that equals the old one. Then update, revoke all refresh tokens and invalidate the cache.
- **Invite**: validate the roles, create the user with `status=invited` and an invite token hash, assign roles, and publish `UserCreated` and `UserInvited` events (with the plain token so it can be emailed). **AcceptInvite** sets the password and name, activates the user and returns a token pair.
- Role or permission change: publish `RoleUpdated`. The auth module subscribes and invalidates the RBAC cache for every affected user. Bump `token_version` to force access tokens to be rejected right away.

### Middleware chain (`kernel/auth`)

1. **JWTAuth(validator)**: only on protected prefixes that aren't public. It reads `Authorization: Bearer <jwt>` and calls `validator.Validate`. On failure it returns a **401 `UNAUTHORIZED`**. On success it writes `UserID` into `RequestContext` and `TenantID`/`Permissions` into the tenant context (`c.SetUserContext`).
   The validator parses the JWT, then loads the user identity `{tokenVersion, status, tenantId}` from the **Redis cache** (DB on a miss). It rejects the token if `token_version` doesn't match (stale), if the user isn't active, or if the audience is wrong for the surface.
2. **TenantGuard** (optional, multi-tenant): on `/platform/*` it requires a platform operator. On `/admin/*` it requires a tenant membership. Tenant identity comes **only from the token**, never from the Host header.
3. **RBAC(checker)**: route-based and **deny-by-default**. `kernel/auth/routes.go` holds `routeRules` with `{method, path segments with "*" wildcards, permission}`. Session endpoints under `/auth/` (except `/invite`) need no permission. A guarded route with no rule gets **403**. When the caller lacks the permission it gets **403** with `required_permissions`.
4. Inside handlers, `auth.RequirePermission(c, checker, perm)` handles finer checks.

Every new protected route needs a `routeRules` entry, or it will return 403.

### Request context (`kernel/context`)

```go
type RequestContext struct { RequestID, UserID string; IsPlatform bool }
type TenantContext  struct { TenantID string; Permissions []string } // xstore: StoreContext{VendorID, StoreID, …}
rc := contextx.RequestFrom(c.UserContext())
```

Pass `c.UserContext()` (it carries these values) to the facade/service.

---

## 6. Database

- Schema lives only in `migrations/NNNNNN_name.up.sql` / `.down.sql`. Seed data (permissions, roles, settings) also goes in migrations.
- sqlc: one entry per module in `sqlc.yaml` → `internal/modules/<m>/infrastructure/persistence/sqlc`. Overrides: `uuid → string` (nullable → `*string`), `timestamptz → time.Time`, `emit_json_tags`, `emit_empty_slices`, `emit_pointers_for_null_types`.
- Repositories wrap sqlc and use `database.Querier(ctx, pool)` so they automatically join a transaction carried by ctx.
- Transactions start and end **only in the application layer**:

```go
err := database.RunInTransaction(ctx, pool, func(ctx context.Context) error {
    if err := s.repo.Create(ctx, …); err != nil { return err }
    database.AfterCommit(ctx, func() { s.bus.PublishAsync(ctx, evt) }) // side effects only after commit
    return nil
})
```

- Multi-tenant (optional): every business table has `tenant_id` (xstore: `vendor_id`, `store_id`) and every query is scoped by it.

## 7. Events & jobs

```go
type Event struct { Name string; Payload any; TenantID, EntityID string; OccurredAt time.Time }
bus.Publish(ctx, e) / bus.PublishAsync(ctx, e) / bus.Subscribe(name, handler)
```

In-memory bus with retries (3 × 25ms), an error hook, and drain on shutdown. An optional **outbox** table makes delivery durable, and the scheduler re-dispatches it every 30s. Event names are PascalCase constants in `domain/event/events.go`, each with a typed payload struct.

## 8. Cross-cutting

- **Health**: `/health`, `/live` (process up), `/ready` (DB + Redis ping → 503 `NOT_READY`).
- **Logging**: zerolog. Each request logs method, path, status, duration, request_id, trace_id and user_id.
- **Rate limiting**: Redis fixed window via a Lua script (INCR + PEXPIRE, atomic), falling back to in-memory. A global per-IP limit plus a stricter per-route limit on credential endpoints. Loopback is skipped in development.
- **Proxy**: set `PROXY_HEADER` + `TRUSTED_PROXIES` behind a CDN so limits see the real IP.
- **Production guards**: refuse seeded dev passwords and dev tokens when `APP_ENV=production`.

## 9. Docker

```dockerfile
FROM --platform=$BUILDPLATFORM golang:1.25-alpine AS builder
WORKDIR /src
COPY go.mod go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod go mod download
COPY . .
ARG TARGETOS TARGETARCH
RUN CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH go build -trimpath -ldflags="-s -w" -o /out/api ./cmd/api

FROM alpine:3.21
RUN apk add --no-cache ca-certificates tzdata curl && adduser -D -u 10001 app
WORKDIR /app
COPY --from=builder /out/api /app/api
COPY migrations /app/migrations
USER app
EXPOSE 8080
HEALTHCHECK CMD curl -fsS http://127.0.0.1:8080/live || exit 1
ENTRYPOINT ["/app/api"]
```

---

## 10. Agent checklist: adding a module

1. Migration `migrations/NNNNNN_<module>.up/down.sql` (+ permission seed rows).
2. `internal/modules/<m>/queries/<m>.sql` → add a sqlc entry → `make sqlc`.
3. `domain/entity`, `dto` (json camelCase + `validate` tags), `mapper`, `permissions`.
4. `infrastructure/persistence/repository.go` (SQL only).
5. `application/service.go` (rules, transactions, `apperrors.*`, events).
6. `facade/facade.go` (interface + impl), the only thing other modules import.
7. `delivery/http/handler.go`: BodyParser → Validate → facade → `response.*`. Add `RegisterRoutes`.
8. `module.go` implementing `Module`; construct it in `app.go` and add it to `NewRegistry(...)`.
9. Add `routeRules` entries for every protected route (deny-by-default).
10. Tests: unit tests for domain/application, plus `app.Test(httptest…)` for handlers and middleware.
11. `make lint && make test && go build ./...`

## Forbidden

- Raw `c.JSON(...)` responses: always go through `shared/response`
- Business logic in handlers, repositories or `shared/`
- Transactions outside the application layer
- Cross-module repository/SQL access or importing another module's internals (use its facade or events)
- Storing plain refresh, reset or invite tokens (store the SHA-256 hash only)
- Leaking whether an email exists (forgot-password, resend-verification, login messages)
- Protected routes without an RBAC rule
- Editing generated `sqlc/` code by hand
