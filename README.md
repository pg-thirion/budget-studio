# Ledger / Budget Studio

Private ZAR monthly budget workspace. No financial figures or personal data are committed.

## Mobile app

Android and iOS setup, testing and build steps are in [mobile/README.md](mobile/README.md).

## Configure Supabase
Create a project and run the SQL migration in `supabase/migrations`. Enable email/password sign-ups and email confirmation in Authentication. Set Site URL to https://budget-studio-taupe.vercel.app and add that exact URL to the redirect allowlist. The registration screen requires a password of at least 12 characters. Never use a service-role key in this frontend.

## Deploy to Vercel
Import this private repository as a Vite project. Set `VITE_SUPABASE_URL` and `VITE_SUPABASE_PUBLISHABLE_KEY` to the project URL and publishable key (legacy anon key also supported). Use Node.js 22, npm install and npm run build, then deploy.

## Use
Create an account, confirm your email if required, then sign in. Import your original Ledger JSON backup from the local prototype, and click Save to upload it to your private workspace. Otherwise, enter budget values manually. Save explicitly after changes. Concurrent saves use revision checks. Export a backup before replacing your workspace or resolving a conflict.

## Local development
Copy .env.example to .env.local and fill in the two public values. Run npm install and npm run dev.

## Status
Initial integration. Production authentication, row-level isolation, build and end-to-end sync must be verified against a real Supabase project before importing private data.
