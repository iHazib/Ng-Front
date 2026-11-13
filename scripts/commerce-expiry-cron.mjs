#!/usr/bin/env node
/**
 * Commerce order expiry cron job.
 * Automatically cancels orders stuck in PENDING_VERIFICATION without a valid
 * receipt after their payment deadline, freeing reserved inventory.
 *
 * Intended to be run on a schedule (e.g., every 15 minutes) via cron or
 * the hosting provider's scheduled job feature.
 *
 * Usage:
 *   node scripts/commerce-expiry-cron.mjs
 *
 * Environment variables required:
 *   NEXT_PUBLIC_SUPABASE_URL
 *   SUPABASE_SECRET_KEY (or SUPABASE_SERVICE_ROLE_KEY)
 */
import {readFile} from 'node:fs/promises';
import {parseEnv} from 'node:util';

for (const f of ['.env', '.env.local']) {
  try { Object.assign(process.env, parseEnv(await readFile(f, 'utf8'))); } catch {}
}

const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
const serviceKey = process.env.SUPABASE_SECRET_KEY || process.env.SUPABASE_SERVICE_ROLE_KEY;
if (!url || !serviceKey) {
  console.error('Missing NEXT_PUBLIC_SUPABASE_URL or SUPABASE_SECRET_KEY');
  process.exit(1);
}

const headers = {
  apikey: serviceKey,
  Authorization: `Bearer ${serviceKey}`,
  'Content-Type': 'application/json',
  Prefer: 'return=representation',
};

const report = {
  kind: 'commerce_expiry_cron',
  checked_at: new Date().toISOString(),
  expired: 0,
  errors: [],
};

try {
  // Call the existing expire_commerce_holds RPC (from migration 015)
  const r = await fetch(new URL('/rest/v1/rpc/expire_commerce_holds?p_limit=100', url), {
    method: 'POST',
    headers,
    cache: 'no-store',
    signal: AbortSignal.timeout(60000),
  });

  if (!r.ok) {
    const body = await r.text();
    report.errors.push({ status: r.status, body });
    console.error('Expiry RPC failed:', r.status, body);
    process.exit(1);
  }

  const result = await r.json();
  report.expired = typeof result === 'number' ? result : (result?.expired ?? 0);
  report.status = 'completed';

  console.log(JSON.stringify(report, null, 2));
  process.exit(0);
} catch (e) {
  report.status = 'failed';
  report.errors.push({ error: String(e) });
  console.error('Cron job failed:', e.message);
  process.exit(1);
}
