# Forte Compass — Stage 1 (Landing and brand)

An AI-driven, multi-tenant OKR and performance platform. Stage 1 delivers the branded
gateway: the outcome-led positioning, the outcome ladder, and a live-board teaser that
resolves on sign-in. Supabase auth and tenancy arrive in Stage 2.

Built the same way as Qura and Girard: a single-file React app (`src/App.jsx`) on
Vite + React, deployable to Vercel.

## What is in this build

- `src/App.jsx` — the entire Stage 1 page, one file, brand tokens as CSS variables so a
  tenant can rebrand without a code change. Imade Forte defaults to Navy `#0E2240`,
  Gold `#B8924A`, and Lora.
- `index.html`, `src/main.jsx`, `vite.config.js` — the Vite shell.
- `vercel.json` — tells Vercel this is a Vite app and serves it as a single page.

The build was validated locally with `npm run build` (result: "built").

## Run it on your own machine (optional)

1. Install Node.js 18 or newer from nodejs.org.
2. Open a terminal in this folder.
3. Type `npm install` and press Enter. Wait for it to finish.
4. Type `npm run dev` and press Enter. Open the address it prints (usually
   http://localhost:5173).

## Put it online with GitHub and Vercel

Do these one at a time. No coding needed.

1. Create a free account at github.com if you do not have one.
2. On GitHub, click the plus sign, top right, then "New repository". Name it
   `forte-compass`. Leave everything else as is. Click "Create repository".
3. On the new repository page, click "uploading an existing file".
4. Drag every file and folder from this project into the box, then click
   "Commit changes". Do not upload the `node_modules` or `dist` folders; they are not
   needed and are excluded by `.gitignore`.
5. Create a free account at vercel.com and choose "Continue with GitHub".
6. In Vercel, click "Add New", then "Project". Pick your `forte-compass` repository and
   click "Import".
7. Leave the settings as they are. Vercel detects Vite automatically. Click "Deploy".
8. Wait about a minute. Vercel gives you a live web address. Open it. Forte Compass is
   online.

## Redeploy after a change

Whenever a file changes on GitHub, Vercel rebuilds and republishes on its own. To change
a file: open it on GitHub, click the pencil icon, edit, then "Commit changes". Your live
site updates within a minute.

## Environment variables

Stage 1 needs none. Stage 2 will add Supabase keys (a project URL and an anon key) and a
server-side AI key. Those go into Vercel under Project, then Settings, then Environment
Variables, and are never placed in the code.

## Next stage

Stage 2: the deployable Supabase stack, tenant isolation with row-level security, the
"Which best describes you?" role page, sign-in and account creation, and the per-user
identity map.
