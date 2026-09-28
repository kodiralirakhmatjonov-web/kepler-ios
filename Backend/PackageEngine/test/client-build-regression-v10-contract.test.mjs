import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(here, '../../..');
const bookingStatus = fs.readFileSync(path.join(repoRoot, 'Sources/Views/Booking/BookingStatusView.swift'), 'utf8');
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

test('BookingStatus uses iumrahGlass labels in Swift declaration order', () => {
  const call = callBody(bookingStatus, '.iumrahGlass(');
  const tint = call.indexOf('tint:');
  const staticGlass = call.indexOf('allowsStaticGlass:');
  assert.ok(tint >= 0, 'tint argument must be present');
  assert.ok(staticGlass >= 0, 'allowsStaticGlass argument must be present');
  assert.ok(tint < staticGlass, 'tint must precede allowsStaticGlass for Swift compile');
});

test('Bookings empty state keeps the Explore packages button declaration', () => {
  assert.match(bookingsHome, /private\s+var\s+explorePackagesButton\s*:\s*some\s+View/);
  assert.match(bookingsHome, /bookingEmptyStatusCard[\s\S]*explorePackagesButton/);
});
