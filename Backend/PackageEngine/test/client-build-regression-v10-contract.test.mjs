import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(here, '../../..');
const bookingSwitcher = fs.readFileSync(path.join(repoRoot, 'Sources/Views/Booking/BookingPageSwitcher.swift'), 'utf8');
const bookingsHome = fs.readFileSync(path.join(repoRoot, 'Sources/Views/Tabs/BookingsHomeView.swift'), 'utf8');

function callBody(source, marker) {
  const start = source.indexOf(marker);
  assert.notEqual(start, -1, `${marker} must exist`);
  const open = source.indexOf('(', start);
  let depth = 0;
  for (let i = open; i < source.length; i += 1) {
    if (source[i] === '(') depth += 1;
    if (source[i] === ')') {
      depth -= 1;
      if (depth === 0) return source.slice(open + 1, i);
    }
  }
  throw new Error(`unterminated ${marker}`);
}

test('Booking page switcher keeps tint before allowsStaticGlass in the selected segment', () => {
  const marker = 'tint: selected ? Color.white.opacity(0.26) : nil';
  const tint = bookingSwitcher.indexOf(marker);
  const staticGlass = bookingSwitcher.indexOf('allowsStaticGlass: true', tint);
  assert.ok(tint >= 0, 'selected segment tint argument must be present');
  assert.ok(staticGlass > tint, 'tint must precede allowsStaticGlass for Swift compile');
});

test('Bookings empty state keeps the Explore packages button declaration', () => {
  assert.match(bookingsHome, /private\s+var\s+explorePackagesButton\s*:\s*some\s+View/);
  assert.match(bookingsHome, /bookingEmptyStatusCard[\s\S]*explorePackagesButton/);
});
