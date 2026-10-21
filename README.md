# GP Costing Studio – public web deployment

This is a mobile-responsive Flutter costing calculator. It supports GP margin targets (30%, 40%, 50%, and custom), editable costing categories, product photos, project storage in the browser, and PDF/CSV exports.

## How to publish via GitHub Pages

1. On GitHub, create a new **public** repository called `gp-costing-studio` (any name works, but this is used in examples). Do **not** initialise it with a README.
2. Extract this ZIP on your computer. The extracted folder has `lib`, `test`, `pubspec.yaml`, `.github/workflows/deploy.yml`, and others.
3. Open the extracted folder in VS Code. In **Terminal → New Terminal**, run:

   ```powershell
   git init
   git add .
   git commit -m "First GP Costing Studio release"
   git branch -M main
   git remote add origin https://github.com/YOUR-USERNAME/gp-costing-studio.git
   git push -u origin main
   ```

   Replace `YOUR-USERNAME` with your actual GitHub username, and the repository name if different. You must have Git installed and be signed in with permission to push.
4. In the repository, select **Settings → Pages → Build and deployment → Source: GitHub Actions**.
5. Open the **Actions** tab and check the workflow. If necessary, click **Publish Costing Studio to GitHub Pages → Run workflow**.
6. Once the deploy workflow completes successfully, the website URL is `https://YOUR-USERNAME.github.io/gp-costing-studio/`. The actual URL also appears under **Settings → Pages**.

A successful GitHub Actions run generates the missing Flutter `web/` scaffolding automatically, installs dependencies, runs tests, builds a release, and publishes the result. No local Flutter SDK is needed for this upload method. App compatibility has not been runtime-verified on this machine; check the Actions logs for any errors and test the published site before sharing.

## Keeping your costs private

This public-safe version starts with a **blank project** and does NOT contain any client pricing spreadsheet, prices, or customer names. Do not push confidential documents, passwords, private supplier quotations, or API keys into the public repository. Keep the original detailed costing ZIP private.

## Critical limitation: multi-user sharing

This is an independent, browser-local calculator; it does not have a shared database or login system. Projects saved on one user's computer or phone are not automatically synced to other devices or users. Browser storage can also be lost if data is cleared or a browser is changed. Export PDF/CSV backups as needed.

For actual multi-user use with shared project records and secure roles, add authenticated backend storage (for example Firebase or Supabase) before rolling out company-wide.
