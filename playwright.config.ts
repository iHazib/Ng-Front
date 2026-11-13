import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './tests/browser',
  fullyParallel: false,
  workers: 1,
  timeout: 60_000,
  reporter: 'list',
  use: {
    baseURL: process.env.PLAYWRIGHT_BASE_URL || 'http://127.0.0.1:3100',
    channel: process.env.PLAYWRIGHT_CHANNEL,
    trace: 'retain-on-failure',
    reducedMotion: 'reduce',
  },
  projects: [
    { name: 'desktop', use: { viewport: { width: 1440, height: 1000 } } },
    { name: 'mobile', use: { ...devices['iPhone 13'], defaultBrowserType: 'chromium' } },
  ],
  webServer: process.env.PLAYWRIGHT_BASE_URL ? undefined : {
    command: 'npm run dev -- --port 3100',
    url: 'http://127.0.0.1:3100',
    env: { APP_ENV: 'development', NEXT_TELEMETRY_DISABLED: '1' },
    reuseExistingServer: false,
    timeout: 120_000,
  },
});
