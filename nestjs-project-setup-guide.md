# NestJS Enterprise Project Setup Guide
**Sabuj Engineering Standards — Production-Ready Backend Architecture**
**Version:** 1.1.0

---

## Document Summary

This is a comprehensive blueprint for building **secure, scalable, internationalized, and feature-rich** NestJS applications. It covers project initialization, database configuration (TypeORM), Auth strategies (JWT, OTP), RBAC (Role-Based Access Control), multi-language support (i18n), Media management, Email/SMS notifications, and custom common utilities. This setup provides a complete boilerplate with Auth and Users modules ready, allowing developers to focus purely on building new feature modules.

> Share this document with your AI IDE and say:
> **"Set up a NestJS project called `<name>` following this guide exactly."**

---

## 1. The Tech Stack & Features

| Layer/Feature | Tool / Library | Why this tool? |
|---|---|---|
| **Framework** | NestJS | Robust, scalable, Angular-like architecture for Node.js. |
| **Language** | TypeScript (strict) | Compile-time type safety. |
| **Database ORM** | TypeORM | Powerful active-record/data-mapper ORM. |
| **Database** | PostgreSQL | Enterprise-grade relational DB. |
| **Validation** | class-validator & class-transformer | Built-in NestJS validation with decorators. |
| **Auth** | Passport, @nestjs/jwt, bcrypt | Standard JWT with access/refresh tokens and password hashing. |
| **i18n** | nestjs-i18n | Type-safe multi-language support. |
| **Email** | nodemailer | Reliable email sending. |
| **Media** | multer, @nestjs/platform-express | File upload handling and serving via `@nestjs/serve-static`. |
| **Rate Limiting** | @nestjs/throttler | Protects APIs from brute-force/DDoS attacks. |
| **API Docs** | @nestjs/swagger | Auto-generated OpenAPI documentation. |

---

## 2. Setup Script & Initialization

Save as `setup.sh` and run `bash setup.sh <project-name>`:

```bash
#!/bin/bash
PROJECT_NAME=$1
if [ -z "$PROJECT_NAME" ]; then
  echo "Please provide a project name. Example: bash setup.sh my-backend"
  exit 1
fi

echo "🚀 Scaffolding NestJS Project: $PROJECT_NAME..."
npx @nestjs/cli new "$PROJECT_NAME" --package-manager pnpm --strict

cd "$PROJECT_NAME" || exit

echo "📦 Installing core dependencies..."
pnpm add @nestjs/config @nestjs/typeorm typeorm pg @nestjs/jwt @nestjs/passport passport passport-jwt bcrypt
pnpm add class-validator class-transformer nestjs-i18n @nestjs/serve-static @nestjs/throttler @nestjs/swagger swagger-ui-express nodemailer
pnpm add libphonenumber-js date-fns

echo "📦 Installing dev dependencies..."
pnpm add -D @types/passport-jwt @types/bcrypt @types/multer @types/nodemailer

echo "✅ Setup Complete! Begin structuring modules."
```

---

## 3. Folder Structure

We strictly place all feature modules inside the `src/modules` directory to keep the root `src` clean.

```text
src/
├── app.module.ts              # Root module importing all others
├── main.ts                    # Bootstrap with Swagger, ValidationPipe, CORS
├── config/                    # Configuration files
│   ├── database.config.ts     # TypeORM config factory
│   └── jwt.config.ts          # JWT config factory
├── common/                    # Shared utilities across the app
│   ├── decorators/            # @CurrentUser, @Public, @RequirePermissions
│   ├── filters/               # HttpExceptionFilter (handles i18n errors)
│   ├── guards/                # JwtAuthGuard, PermissionsGuard
│   ├── interceptors/          # ResponseInterceptor (standardizes response payload)
│   ├── interfaces/            # ApiResponse, PaginatedResult, JwtPayload
│   └── utils/                 # Pagination, Hash, OTP helpers
├── database/                  # DB connection and seeds
│   ├── migrations/
│   ├── seeds/
│   └── typeorm.config.ts      # TypeORM CLI config
├── i18n/                      # Translations
│   ├── en/                    # English JSONs
│   └── bn/                    # Bengali JSONs
└── modules/                   # All feature modules go here
    ├── auth/                  # Authentication logic (Login, Register, OTP, Refresh)
    ├── rbac/                  # Role-Based Access Control (Roles & Permissions)
    ├── users/                 # User management (CRUD, Profile)
    ├── media/                 # File upload management
    ├── email/                 # Nodemailer service wrapper
    ├── sms/                   # SMS gateway wrapper
    └── notifications/         # In-app notifications
```

---

## 4. Coding Pattern: Repository Pattern

We enforce the **Repository Pattern** to separate business logic from database interactions. Every feature module should follow this structure:

- **Controller (`*.controller.ts`)**: Handles HTTP requests, applies routing, DTO validation, and guards. Does not contain business logic.
- **Service (`*.service.ts`)**: Contains pure business logic. Injects the repository to communicate with the database.
- **Repository**: We use TypeORM's built-in `Repository<Entity>`. Injected into the Service via `@InjectRepository(Entity)`. For complex custom queries, extend the base repository.
- **Entity (`*.entity.ts`)**: Represents the database table structure.
- **DTO (`*.dto.ts`)**: Data Transfer Objects for validating incoming requests using `class-validator`.

---

## 5. Standardized Interceptors & Responses

Always return data wrapped in standard interceptors and pagination formats to ensure frontend clients receive predictable data structures.

### Standard Response Format (`ResponseInterceptor`)
Create a global interceptor in `src/common/interceptors/response.interceptor.ts`. It wraps all successful responses.

```typescript
import { Injectable, NestInterceptor, ExecutionContext, CallHandler } from '@nestjs/common';
import { Observable } from 'rxjs';
import { map } from 'rxjs/operators';

export interface Response<T> {
  success: boolean;
  message: string;
  data: T;
  errors: null;
}

@Injectable()
export class ResponseInterceptor<T> implements NestInterceptor<T, Response<T>> {
  intercept(context: ExecutionContext, next: CallHandler): Observable<Response<T>> {
    return next.handle().pipe(
      map(data => ({
        success: true,
        message: data?.message || 'Operation successful',
        data: data?.data ?? data, // Support both returning raw data or an object with data/message
        errors: null,
      })),
    );
  }
}
```
Apply this globally in `main.ts` or `app.module.ts`.

### Paginated Result
```typescript
export interface PaginatedResult<T> {
  results: T[];
  page: number;
  limit: number;
  totalPages: number;
  totalResults: number;
}
```

---

## 6. Base Modules: Auth & Users

The boilerplate comes with fully functional Auth and Users modules.

### Users Module Schema (`User` Entity)
- `id`: UUID (Primary Key)
- `email`: String (Unique)
- `phone`: String (Optional, Unique)
- `password`: String (Hashed via bcrypt)
- `firstName`: String
- `lastName`: String
- `isActive`: Boolean (Default: true)
- `roles`: Many-to-Many relationship with `Role` Entity
- `createdAt`, `updatedAt`: Timestamps

### Auth Module Base APIs & Business Logic
All routes are prefixed with `/api/auth`. This module handles all authentication, 2FA, OTP flows, and current user profile management.

**Public Endpoints:**
- `POST /register`: Registers a new user. Validates input, hashes password, and creates the user record.
- `POST /login`: Authenticates a user with email/phone and password. Returns tokens or initiates 2FA if enabled.
- `POST /verify`: Verifies a user's registration or email using a token/OTP.
- `POST /refresh`: Accepts a valid Refresh Token and issues a new Access Token.
- `POST /resend-verification`: Resends the verification token to the user's email or phone.
- `POST /forgot-password`: Initiates the password recovery process. Generates a reset token and sends it.
- `POST /reset-password`: Resets the password using the provided reset token and new password.
- `POST /2fa/authenticate`: Authenticates the user with a 2FA code during the login flow.
- `POST /otp/login`: Initiates an OTP-based passwordless login flow using a phone number.
- `POST /otp/verify`: Verifies the OTP sent to the phone and returns authentication tokens.

**Protected Endpoints (Requires JWT):**
- `POST /logout`: Revokes the current user's refresh token to invalidate the session.
- `POST /change-password`: Allows the authenticated user to change their password securely.
- `GET /me`: Returns the currently authenticated user's full profile details.
- `PUT /me`: Updates the currently authenticated user's profile information.
- `POST /2fa/generate`: Generates a new 2FA secret (e.g., for Google Authenticator) for the user.
- `POST /2fa/enable`: Enables 2FA for the user after successfully verifying the first code.
- `POST /2fa/disable`: Disables 2FA for the user's account.

### Users Module Base APIs & Business Logic
All routes are prefixed with `/api/users`. This module is designed for administrative user and role management.

**Admin Endpoints (Requires JWT & Specific Permissions):**
- `POST /:id/roles`: Assigns or updates roles for a specific user. Requires `@RequirePermissions('users.assign-role')`.
- `POST /assign-roles`: Bulk assigns roles to multiple users at once. Requires `@RequirePermissions('users.assign-role')`.
- `GET /`: Lists all users with pagination, sorting, and advanced filtering. Requires `@RequirePermissions('users.read')`.
- `GET /:id`: Fetches detailed information of a single user by their ID. Requires `@RequirePermissions('users.read')`.
- `POST /`: Directly creates a new user (admin/staff creation). Requires `@RequirePermissions('users.create')`.
- `PATCH /:id`: Updates an existing user's details or status. Requires `@RequirePermissions('users.update')`.
- `DELETE /:id`: Soft deletes or deactivates a user. Requires `@RequirePermissions('users.delete')`.
- `GET /:id/roles`: Retrieves the roles assigned to a specific user. Requires `@RequirePermissions('users.read', 'roles.read')`.
- `GET /:id/permissions`: Retrieves the effective permissions of a specific user. Requires `@RequirePermissions('users.read', 'permissions.read')`.

---

## 7. RBAC (Role-Based Access Control)

Implement dynamic RBAC with `User` -> `Role` -> `Permission` many-to-many relationships.

### Entities:
- **Permission**: `id`, `slug` (e.g., `'users.create'`), `description`.
- **Role**: `id`, `name` (e.g., `'admin'`), `isStatic` (boolean to prevent deletion of system roles), `permissions` (Many-to-Many).
- **User**: `roles` (Many-to-Many).

### Decorator & Guard:
Create `@RequirePermissions(...permissions: string[])` decorator.
Create `PermissionsGuard` that checks if the `CurrentUser`'s roles include the required permissions. Apply this guard strictly on sensitive controller endpoints.

### RBAC Module Base APIs & Business Logic
All routes are protected by JWT and require specific `PermissionsGuard` permissions.

**Roles Endpoints (`/api/roles`):**
- `POST /`: Create a new role. Requires `@RequirePermissions('roles.manage', 'roles.create')`.
- `GET /`: Retrieve a paginated list of all roles. Requires `@RequirePermissions('roles.manage', 'roles.read')`.
- `GET /list`: Retrieve a non-paginated list of roles. Requires `@RequirePermissions('roles.manage', 'roles.read')`.
- `GET /:id`: Fetch details of a specific role. Requires `@RequirePermissions('roles.manage', 'roles.read')`.
- `PATCH /:id`: Update an existing role's details. Requires `@RequirePermissions('roles.manage', 'roles.update')`.
- `DELETE /:id`: Delete a role. Requires `@RequirePermissions('roles.manage', 'roles.delete')`.
- `POST /:id/permissions`: Assign or replace permissions for a specific role. Requires `@RequirePermissions('roles.manage', 'roles.assign-permission')`.

**Permissions Endpoints (`/api/permissions`):**
- `POST /`: Create a new permission. Requires `@RequirePermissions('permissions.manage', 'permissions.create')`.
- `GET /`: Retrieve a list of all permissions. Requires `@RequirePermissions('permissions.manage', 'permissions.read')`.
- `GET /:id`: Fetch details of a specific permission. Requires `@RequirePermissions('permissions.manage', 'permissions.read')`.
- `PATCH /:id`: Update an existing permission. Requires `@RequirePermissions('permissions.manage', 'permissions.update')`.
- `DELETE /:id`: Delete a permission. Requires `@RequirePermissions('permissions.manage', 'permissions.delete')`.

---

## 8. Notifications Module Base APIs & Business Logic

All routes are prefixed with `/api/admin/notifications`. This module handles creating and managing in-app notifications.

**Admin Endpoints (Requires JWT & Specific Permissions):**
- `POST /`: Create a new notification. Requires `@RequirePermissions('notifications.manage', 'notifications.create')`.
- `GET /`: Retrieve a paginated list of notifications with filtering. Requires `@RequirePermissions('notifications.manage', 'notifications.read')`.
- `GET /:id`: Fetch details of a specific notification by ID. Requires `@RequirePermissions('notifications.manage', 'notifications.read')`.
- `PATCH /:id`: Update a notification. Requires `@RequirePermissions('notifications.manage', 'notifications.update')`.
- `PATCH /:id/read`: Mark a specific notification as read. Requires `@RequirePermissions('notifications.manage', 'notifications.update')`.
- `DELETE /:id`: Delete a notification. Requires `@RequirePermissions('notifications.manage', 'notifications.delete')`.

---

## 9. Multi-Language (i18n)

Use `nestjs-i18n`. Store translations in `src/i18n/{lang}/{file}.json`.

- Set fallback language to `'bn'` or `'en'`.
- Catch `I18nValidationException` in a custom `HttpExceptionFilter` to format errors beautifully.

---

## 10. Creating a New Module Guide

When you need to add a new feature (e.g., `Products`), strictly follow these steps to maintain boilerplate consistency.

### Step 1: Generate Module, Controller, and Service
Use the Nest CLI and place them inside the `modules` directory.
```bash
nest g module modules/products
nest g controller modules/products
nest g service modules/products
```

### Step 2: Create Entity & DTOs
Inside `src/modules/products`:
- Create an `entities` folder. Add `product.entity.ts`.
- Create a `dto` folder. Add `create-product.dto.ts` and `update-product.dto.ts`.

### Step 3: Implement Repository Pattern
- In `products.module.ts`, import `TypeOrmModule.forFeature([Product])`.
- In `products.service.ts`, inject the repository:
  ```typescript
  import { Injectable } from '@nestjs/common';
  import { InjectRepository } from '@nestjs/typeorm';
  import { Repository } from 'typeorm';
  import { Product } from './entities/product.entity';

  @Injectable()
  export class ProductsService {
    constructor(
      @InjectRepository(Product)
      private readonly productRepository: Repository<Product>,
    ) {}
    
    // Add business logic methods here...
  }
  ```

### Step 4: Add Business Logic and Endpoints
- Write database interaction logic inside `products.service.ts`.
- Call these service methods from `products.controller.ts`.
- Secure endpoints using `@UseGuards(JwtAuthGuard)` and `@RequirePermissions('products.create')`.

### Step 5: Document APIs
Decorate controller methods with Swagger decorators (`@ApiOperation`, `@ApiResponse`, `@ApiBody`).

---

## 11. Database Seeding & Migrations

- Define all TypeORM configurations in `src/database/typeorm.config.ts`.
- Create a `seed.ts` script to insert default `Permissions`, `Roles` (`super-admin`, `admin`, `user`), and a default `System Admin` user.
- Run migrations for all schema changes in production.

---

## 12. Testing (Unit & E2E)

We use **Jest** as our core testing framework, which comes pre-configured with NestJS.

### Unit Tests
Unit tests should be placed alongside the files they test (e.g., `products.service.spec.ts`).

- **Services:** Test business logic independently by mocking external dependencies, especially the TypeORM repositories. Use `jest.spyOn()` or create mock repository objects.
- **Controllers:** Test HTTP route handlers by mocking the underlying service methods. The controller tests should only verify that the correct service methods are called and correct responses are returned.

**Run unit tests:**
```bash
pnpm test
pnpm test:watch # During active development
```

### End-to-End (E2E) Tests
E2E tests should be placed in the `/test` directory.

- Use **Supertest** to test the HTTP layer, ensuring the Controller, Service, and Database integrate correctly.
- Use an in-memory database (like SQLite) or a dedicated test database (e.g., PostgreSQL on a different port/schema) for E2E tests to avoid corrupting development data.
- E2E tests must verify the standard response formats and error handling.

**Run E2E tests:**
```bash
pnpm test:e2e
```
