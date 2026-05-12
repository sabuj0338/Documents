#!/bin/bash

PROJECT_NAME=$1

if [ -z "$PROJECT_NAME" ]; then
  echo "Please provide a project name. Example: bash setup.sh my-app"
  exit 1
fi

echo "🚀 Scaffolding Next.js & Shadcn UI for: $PROJECT_NAME..."

# 1. Initialize Next.js (Non-interactive)
pnpm create next-app@latest "$PROJECT_NAME" --ts --tailwind --eslint --app --src-dir --import-alias "@/*" --use-pnpm --yes

cd "$PROJECT_NAME" || exit

echo "🎨 Initializing ShadCN UI..."
pnpm dlx shadcn@latest init -d

echo "📦 Installing additional dependencies in bulk..."

# 2. Install all regular dependencies at once
pnpm add @reduxjs/toolkit react-redux \
  react-hook-form zod @hookform/resolvers \
  @tanstack/react-table axios cookies-next \
  @sentry/nextjs next-intl next-themes nextjs-toploader \
  clsx tailwind-merge lucide-react class-variance-authority \
  react-phone-number-input date-fns react-day-picker

# 3. Install all dev dependencies
pnpm add -D vitest @testing-library/react @testing-library/jest-dom jsdom playwright openapi-typescript prettier prettier-plugin-tailwindcss eslint-config-prettier

# 4. Add ShadCN components (Non-interactive)
echo "🎨 Adding ShadCN UI components..."
pnpm dlx shadcn@latest add button input label form card dialog alert-dialog \
  table dropdown-menu select textarea badge skeleton sheet separator \
  sonner avatar scroll-area tooltip popover command calendar -y

echo "✅ Setup Complete! You can now apply the boilerplate files from the guide."
