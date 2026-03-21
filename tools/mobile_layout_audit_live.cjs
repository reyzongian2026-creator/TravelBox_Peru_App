/* eslint-disable no-console */
const fs = require('fs');
const path = require('path');
const { chromium, webkit, devices } = require('playwright');

const BASE_URL = (process.env.BASE_URL || '').trim();
const AUDIT_ONLY_ROUTE = (process.env.AUDIT_ONLY_ROUTE || '').trim();
const ADMIN_EMAIL = (process.env.E2E_ADMIN_EMAIL || '').trim();
const ADMIN_PASSWORD = (process.env.E2E_ADMIN_PASSWORD || '').trim();
const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
const OUTPUT_DIR =
  process.env.OUTPUT_DIR ||
  path.join(process.cwd(), 'artifacts', `mobile-layout-audit-live-${timestamp}`);

function requireEnv(name, value) {
  if (!value) {
    throw new Error(`Missing required env: ${name}`);
  }
}

function ensureDir(target) {
  fs.mkdirSync(target, { recursive: true });
}

function normalizedRoute(routePath) {
  if (!routePath) return '/';
  return routePath.startsWith('/') ? routePath : `/${routePath}`;
}

function toHashUrl(routePath) {
  const route = normalizedRoute(routePath);
  const root = BASE_URL.endsWith('/') ? BASE_URL.slice(0, -1) : BASE_URL;
  if (root.includes('#')) {
    return `${root.split('#')[0]}#${route}`;
  }
  return `${root}/#${route}`;
}

async function waitForUi(page, delayMs = 900) {
  await page.waitForTimeout(delayMs);
}

async function firstExisting(locators) {
  for (const locator of locators) {
    if ((await locator.count()) > 0) {
      return locator.first();
    }
  }
  return null;
}

async function waitUntilNotLogin(page, timeoutMs = 45000) {
  await page.waitForFunction(
    () => !window.location.hash.includes('/login'),
    {},
    { timeout: timeoutMs },
  );
}

async function performLogin(page) {
  await page.goto(toHashUrl('/login'), { waitUntil: 'domcontentloaded' });
  await page.waitForSelector('input', { timeout: 30000 });
  await waitForUi(page, 800);

  const emailInput = await firstExisting([
    page.locator('input[type="email"]'),
    page.locator('input[name*="email" i]'),
    page.locator('input[autocomplete="username"]'),
    page.locator('form input').first(),
  ]);
  if (!emailInput) {
    throw new Error('Could not locate email input on login page.');
  }
  await emailInput.fill(ADMIN_EMAIL);

  const passwordInput = await firstExisting([
    page.locator('input[type="password"]'),
    page.locator('input[name*="password" i]'),
  ]);
  if (!passwordInput) {
    throw new Error('Could not locate password input on login page.');
  }
  await passwordInput.fill(ADMIN_PASSWORD);

  const loginButton = await firstExisting([
    page.getByRole('button', {
      name: /iniciar|ingresar|acceder|login|interno|internal/i,
    }),
    page.locator('button[type="submit"]'),
  ]);

  if (loginButton) {
    await loginButton.click();
  } else {
    await passwordInput.press('Enter');
  }

  await waitUntilNotLogin(page);
  await waitForUi(page, 1200);

  const url = page.url();
  if (/#\/(verify-email|onboarding|profile\/complete|password-reset)/.test(url)) {
    throw new Error(`Admin account is not ready for backoffice flow. Current URL: ${url}`);
  }
  if (/#\/login/.test(url)) {
    throw new Error('Login did not complete. Still at /login.');
  }
}

async function captureStates(page, screenSlug, screenDir) {
  const topPath = path.join(screenDir, `${screenSlug}-top-visible.png`);
  const downPath = path.join(screenDir, `${screenSlug}-scroll-down-hide.png`);
  const upPath = path.join(screenDir, `${screenSlug}-scroll-up-reveal.png`);
  const bottomPath = path.join(screenDir, `${screenSlug}-bottom-end.png`);

  await page.evaluate(() => window.scrollTo(0, 0));
  await waitForUi(page, 700);
  await page.screenshot({ path: topPath, fullPage: false });

  await page.evaluate(() => window.scrollBy(0, 430));
  await waitForUi(page, 700);
  await page.screenshot({ path: downPath, fullPage: false });

  await page.evaluate(() => window.scrollBy(0, -250));
  await waitForUi(page, 700);
  await page.screenshot({ path: upPath, fullPage: false });

  await page.evaluate(() => window.scrollTo(0, document.body.scrollHeight));
  await waitForUi(page, 900);
  await page.screenshot({ path: bottomPath, fullPage: false });
}

async function openAndCapture(page, routePath, screenSlug, screenDir, reachedRoutes) {
  await page.goto(toHashUrl(routePath), { waitUntil: 'domcontentloaded' });
  await waitForUi(page, 1200);

  const currentUrl = page.url();
  const hash = new URL(currentUrl).hash || '';
  reachedRoutes.push({ requested: routePath, actual: hash || currentUrl });
  console.log(`Ruta solicitada ${routePath} -> URL activa ${currentUrl}`);

  if (hash.includes('/login')) {
    throw new Error(`Unexpected redirect to /login when requesting ${routePath}.`);
  }

  await captureStates(page, screenSlug, screenDir);
}

function slugFromRoute(routePath) {
  return normalizedRoute(routePath)
    .replace(/^\/+/, '')
    .replace(/[^a-zA-Z0-9]+/g, '-')
    .replace(/(^-|-$)/g, '') || 'ruta';
}

async function runProfile(profile) {
  const screenDir = path.join(OUTPUT_DIR, profile.name);
  ensureDir(screenDir);
  const reachedRoutes = [];
  const browser = await profile.engine.launch({ headless: true });
  const context = await browser.newContext({
    ...profile.device,
  });

  try {
    const page = await context.newPage();
    await performLogin(page);

    if (AUDIT_ONLY_ROUTE) {
      await openAndCapture(
        page,
        AUDIT_ONLY_ROUTE,
        slugFromRoute(AUDIT_ONLY_ROUTE),
        screenDir,
        reachedRoutes,
      );
    } else {
      await openAndCapture(page, '/admin/dashboard', 'dashboard', screenDir, reachedRoutes);
      await openAndCapture(page, '/discovery', 'mapa-lista', screenDir, reachedRoutes);
      await openAndCapture(page, '/admin/reservations', 'reservas', screenDir, reachedRoutes);
      await openAndCapture(page, '/admin/incidents', 'tickets', screenDir, reachedRoutes);
      await openAndCapture(page, '/admin/users', 'usuarios', screenDir, reachedRoutes);
      await openAndCapture(page, '/admin/warehouses', 'almacenes', screenDir, reachedRoutes);
    }

    fs.writeFileSync(
      path.join(screenDir, 'audit-report.json'),
      JSON.stringify(
        {
          profile: profile.name,
          baseUrl: BASE_URL,
          capturedAt: new Date().toISOString(),
          reachedRoutes,
        },
        null,
        2,
      ),
      'utf8',
    );
  } finally {
    await context.close();
    await browser.close();
  }
}

async function main() {
  requireEnv('BASE_URL', BASE_URL);
  requireEnv('E2E_ADMIN_EMAIL', ADMIN_EMAIL);
  requireEnv('E2E_ADMIN_PASSWORD', ADMIN_PASSWORD);
  ensureDir(OUTPUT_DIR);

  const iPhone = devices['iPhone 14 Pro'];
  const fullRunPlan = [
    {
      name: 'iphone-safari',
      engine: webkit,
      device: iPhone,
    },
    {
      name: 'chrome-mobile',
      engine: chromium,
      device: devices['iPhone 14 Pro'],
    },
    {
      name: 'android-chrome',
      engine: chromium,
      device: devices['Pixel 7'],
    },
    {
      name: 'windows-chrome',
      engine: chromium,
      device: {
        viewport: { width: 1366, height: 900 },
        deviceScaleFactor: 1,
        isMobile: false,
        hasTouch: false,
      },
    },
  ];

  const selectedProfiles = (process.env.AUDIT_PROFILES || '')
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean);
  const runPlan =
    selectedProfiles.length === 0
      ? fullRunPlan
      : fullRunPlan.filter((profile) => selectedProfiles.includes(profile.name));

  if (runPlan.length === 0) {
    throw new Error(
      `AUDIT_PROFILES no coincide con perfiles validos. Disponibles: ${fullRunPlan
        .map((profile) => profile.name)
        .join(', ')}`,
    );
  }

  for (const profile of runPlan) {
    console.log(`Capturando perfil: ${profile.name}`);
    await runProfile(profile);
  }

  console.log(`Capturas live listas en: ${OUTPUT_DIR}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
