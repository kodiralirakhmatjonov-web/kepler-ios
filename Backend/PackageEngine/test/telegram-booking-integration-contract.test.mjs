import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve(process.cwd(), '..', '..');
const read = (file) => fs.readFileSync(path.join(root, file), 'utf8');

test('iOS exposes Telegram booking connection on Home, Account, Booking and completion surfaces', () => {
  const home = read('Sources/Views/Home/HomeDashboardView.swift');
  const account = read('Sources/AppShell/IumrahAccountView.swift');
  const bookings = read('Sources/Views/Tabs/BookingsHomeView.swift');
  const detail = read('Sources/Views/Booking/BookingDetailView.swift');
  const celebration = read('Sources/Views/Booking/IumrahBookingCelebrationView.swift');
  const service = read('Sources/Services/TelegramBookingIntegrationService.swift');

  assert.match(home, /IumrahTelegram(?:EntryCard\(language: settings\.language, large: true\)|IntegrationView\(preferredBookingID: bookings\.sessions\.first\?\.id\))/);
  assert.match(account, /telegramIntegrationSection/);
  assert.match(bookings, /IumrahTelegramConnectCard\(/);
  assert.match(detail, /IumrahTelegramConnectCard\(/);
  assert.match(celebration, /IumrahTelegramConnectCard\([\s\S]*style: \.dark/);
  assert.match(service, /\/api\/package\/booking\/\\\(bookingID\)\/telegram-link/);
  assert.match(service, /url\.host\?\.lowercased\(\) == "t\.me"/);
});

test('PackageEngine validates ownership before issuing a one-time Telegram link', () => {
  const index = read('Backend/PackageEngine/src/index.ts');
  const bridge = read('Backend/PackageEngine/src/telegram-bridge.ts');
  const renderConfig = read('Backend/PackageEngine/scripts/render-config.mjs');
  const env = read('Backend/PackageEngine/src/env.ts');

  assert.match(index, /bookingTelegramLinkMatch/);
  assert.match(bridge, /access_token_hash/);
  assert.match(bridge, /iumrah_account_sessions/);
  assert.match(bridge, /pilgrim_trips/);
  assert.match(bridge, /\/internal\/link-token/);
  assert.match(renderConfig, /TELEGRAM_BOT_ORIGIN/);
  assert.match(renderConfig, /anonymous-chat-bot/);
  assert.match(env, /TELEGRAM_BOT_ORIGIN\?: string/);
  assert.match(index, /telegramBotConfigured: Boolean\(env\.TELEGRAM_BOT_ORIGIN\)/);
});
