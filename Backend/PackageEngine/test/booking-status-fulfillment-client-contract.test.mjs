import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const repoRoot = new URL('../../../', import.meta.url);
const bookingsHome = fs.readFileSync(new URL('Sources/Views/Tabs/BookingsHomeView.swift', repoRoot), 'utf8');
const companions = fs.readFileSync(new URL('Sources/AppShell/IumrahTravelCompanionsView.swift', repoRoot), 'utf8');
const project = fs.readFileSync(new URL('project.yml', repoRoot), 'utf8');

test('booking status exposes receipt, individual documents and clear actions', () => {
  assert.match(bookingsHome, /bookingFulfillmentCenter\(session, checkout: activeCheckout\)/);
  assert.match(bookingsHome, /paymentReceiptStatusCard/);
  assert.match(bookingsHome, /documentReadinessCard/);
  assert.match(bookingsHome, /"ticket", "flight_ticket", "airline_ticket"/);
  assert.match(bookingsHome, /"voucher", "hotel_voucher", "hotel_booking", "hotel_confirmation"/);
  assert.match(bookingsHome, /IumrahPolicyDetailView\(kind: \.refund\)/);
  assert.match(bookingsHome, /Перейти к бронированию/);
  assert.match(bookingsHome, /Заполнить данные заранее/);
  assert.match(bookingsHome, /Color\.iumrahPrimaryButtonBackground/);
});

test('traveler cards keep a readable trip label without a hotel name', () => {
  assert.match(companions, /companionTripTitle\(session\)/);
  assert.match(companions, /session\.booking\.route\.originCode/);
  assert.match(companions, /session\.booking\.route\.outboundDestination/);
});

test('client release metadata advances for the booking status update', () => {
  assert.match(project, /MARKETING_VERSION: "2\.0\.4"/);
  assert.match(project, /CURRENT_PROJECT_VERSION: "20183"/);
});
