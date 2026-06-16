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

pnpm dlx shadcn@latest add button input label form card dialog alert-dialog \
  table dropdown-menu select textarea badge skeleton sheet separator \
  sonner avatar scroll-area tooltip popover command calendar -y

echo "✅ Setup Complete!"
