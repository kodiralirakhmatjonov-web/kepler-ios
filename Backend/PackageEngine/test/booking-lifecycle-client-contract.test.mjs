import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const repoRoot = new URL('../../../', import.meta.url);
const models = fs.readFileSync(new URL('Sources/Models/BookingModels.swift', repoRoot), 'utf8');
const accountModels = fs.readFileSync(new URL('Sources/Models/IumrahAccountModels.swift', repoRoot), 'utf8');
const store = fs.readFileSync(new URL('Sources/State/BookingStore.swift', repoRoot), 'utf8');
const bookingsHome = fs.readFileSync(new URL('Sources/Views/Tabs/BookingsHomeView.swift', repoRoot), 'utf8');
const bookingDetail = fs.readFileSync(new URL('Sources/Views/Booking/BookingDetailView.swift', repoRoot), 'utf8');

test('client persists server status history alongside lifecycle deadlines', () => {
  assert.match(models, /struct BookingStatusHistoryEntry: Codable, Hashable/);
  assert.match(models, /var statusHistory: \[BookingStatusHistoryEntry\]\? = nil/);
  assert.match(models, /func latestStatusTimestamp\(matching statuses: Set<String>\)/);
  assert.match(accountModels, /let statusHistory: \[BookingStatusHistoryEntry\]\?/);
  assert.match(store, /mergeOperationalStatusHistory/);
});

test('Bookings tab renders a date for every reached lifecycle stage', () => {
  assert.match(bookingsHome, /lifecycleStageTimestamp\(index: index, session: session, isCancelled: isCancelled\)/);
  assert.match(bookingsHome, /case 2:[\s\S]*payment_pending/);
  assert.match(bookingsHome, /case 4:[\s\S]*ready_to_travel/);
  assert.match(bookingsHome, /case 6:[\s\S]*completed/);
});

test('countdowns have history and booking update fallbacks on both booking surfaces', () => {
  assert.match(bookingsHome, /latestStatusTimestamp\(matching: \["payment_pending"\]\)/);
  assert.match(bookingsHome, /latestStatusTimestamp\(matching: \["booking_confirmed", "paid"\]\)/);
  assert.match(bookingDetail, /latestStatusTimestamp\(matching: \["payment_pending"\]\)/);
  assert.match(bookingDetail, /latestStatusTimestamp\(matching: \["booking_confirmed", "paid"\]\)/);
});
