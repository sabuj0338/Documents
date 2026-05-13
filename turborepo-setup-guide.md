# Turborepo Fullstack Monorepo Setup Guide
**Sabuj Engineering Standards — Production-Ready Monorepo Architecture**
**Version:** 1.0.0

---

## Document Summary

This guide outlines the process of establishing a high-performance monorepo using **Turborepo** and **pnpm**. It combines our standardized **Next.js 16 Enterprise Frontend** and our **NestJS Enterprise Backend** into a single, unified workspace.

This structure allows you to share configurations, types, and utilities across both applications while maintaining the strict architectural boundaries defined in the individual Next.js and NestJS setup guides.

---

## 1. Prerequisites

Before starting, ensure you have the following installed:
- **Node.js** (v18+)
- **pnpm** (Mandatory for all Sabuj Engineering projects: `npm install -g pnpm`)
- **Git** (Required for Turborepo caching)

---

## 2. Step 1: Initialize the Turborepo Workspace

We will create a bare-bones pnpm workspace and manually scaffold our standardized applications into it, rather than using the default Turbo starter templates, to strictly enforce our boilerplate structures.

1. **Create the workspace directory:**
   ```bash
   mkdir my-monorepo
   cd my-monorepo
   ```

2. **Initialize a package.json for the root:**
   ```bash
   pnpm init
   ```
   Modify the root `package.json` to make it private and define the package manager:
   ```json
   {
     "name": "my-monorepo",
     "private": true,
     "scripts": {
       "build": "turbo run build",
       "dev": "turbo run dev",
       "lint": "turbo run lint",
       "test": "turbo run test"
     },
     "packageManager": "pnpm@9.x.x" 
   }
   ```

3. **Create the `pnpm-workspace.yaml` file:**
   Create this file at the root to define your workspaces.
   ```yaml
   packages:
     - "apps/*"
     - "packages/*"
   ```

4. **Install Turborepo:**
   Turborepo recommends installing `turbo` both globally (for convenient workflows) and as a devDependency in your repository (to pin the version).

   **Global Installation:**
   ```bash
   pnpm add turbo --global
   ```

   **Repository Installation:**
   ```bash
   pnpm add turbo --save-dev --ignore-workspace-root-check
   ```

5. **Create the workspace folders:**
   ```bash
   mkdir apps packages
   ```

---

## 3. Step 2: Configure `turbo.json`

Create a `turbo.json` file in the root directory. This configures the task pipeline for Turborepo.

```json
{
  "$schema": "https://turbo.build/schema.json",
  "pipeline": {
    "build": {
      "dependsOn": ["^build"],
      "outputs": [".next/**", "!.next/cache/**", "dist/**"]
    },
    "test": {
      "dependsOn": ["build"],
      "outputs": ["coverage/**", "test-results/**"]
    },
    "lint": {
      "dependsOn": ["^lint"]
    },
    "dev": {
      "cache": false,
      "persistent": true
    }
  }
}
```

---

## 4. Step 3: Scaffold the NestJS Backend

We will use the **NestJS Enterprise Setup Script** to scaffold the backend inside the `apps` directory.

1. **Navigate to the `apps` directory:**
   ```bash
   cd apps
   ```

2. **Run the NestJS setup script:**
   Create a temporary `setup-backend.sh` script containing the exact script from the `nestjs-project-setup-guide.md` and run it:
   ```bash
   # Assuming the script is saved as setup-backend.sh
   bash setup-backend.sh backend
   ```
   *Note: Ensure the script uses `--package-manager pnpm` as defined in the standard.*

3. **Verify Backend Configuration:**
   The backend code should now reside in `apps/backend`. 
   - Update the `apps/backend/package.json` name to match the workspace convention (e.g., `"name": "@my-monorepo/backend"`).
   - Ensure the backend's `package.json` contains a `dev` script (e.g., `"dev": "nest start --watch"`), so turbo can execute it.

---

## 5. Step 4: Scaffold the Next.js Frontend

We will use the **Next.js 16 Enterprise Setup Script** to scaffold the frontend inside the `apps` directory.

1. **Ensure you are in the `apps` directory:**
   ```bash
   pwd # Should be /path/to/my-monorepo/apps
   ```

2. **Run the Next.js setup script:**
   Create a temporary `setup-frontend.sh` script containing the exact script from the `nextjs-project-setup-guide.md` and run it:
   ```bash
   # Assuming the script is saved as setup-frontend.sh
   bash setup-frontend.sh frontend
   ```
   *Note: This script automatically handles ShadCN UI initialization, Redux/RTK Query setups, and pnpm dependencies.*

3. **Verify Frontend Configuration:**
   The frontend code should now reside in `apps/frontend`.
   - Update the `apps/frontend/package.json` name to match the workspace convention (e.g., `"name": "@my-monorepo/frontend"`).
   - Verify the Next.js `package.json` has a `dev` script (e.g., `"dev": "next dev"`).

---

## 6. Step 5: Setting Up Shared Packages (Optional but Recommended)

To maximize the benefits of a monorepo, create shared configurations inside the `packages` directory.

1. **Create Shared ESLint / TypeScript Configs:**
   Inside `packages/config`, you can place shared `eslint-config-custom` and `tsconfig` settings that both `apps/frontend` and `apps/backend` can extend.

2. **Create Shared Types:**
   If you aren't using OpenAPI codegen, you can create a `packages/types` directory to hold shared interfaces (like `AuthUser`, `PaginatedResponse`) and import them in both apps.
   ```bash
   # In apps/frontend or apps/backend:
   pnpm add @my-monorepo/types --workspace
   ```

---

## 7. Step 6: Running the Full Stack

Now that the monorepo is fully configured, you can run everything from the root directory.

1. **Install all dependencies across the workspace:**
   ```bash
   cd .. # Back to the root of my-monorepo
   pnpm install
   ```

2. **Start the development servers:**
   ```bash
   pnpm run dev
   ```
   Turborepo will concurrently start the Next.js frontend (typically on port 3000) and the NestJS backend (typically on port 3001), streaming their logs into a single, unified terminal view.

---

## 8. Environment Variables Note

Before running `pnpm run dev`, make sure to configure the environment variables for both applications:
- **Frontend:** Create `apps/frontend/.env.local` setting `API_URL=http://localhost:3001/api/v1`
- **Backend:** Create `apps/backend/.env` with your database credentials, JWT secrets, and ensure it runs on port 3001 (or whatever port your proxy.ts expects).
