import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const repoRoot = new URL('../../../', import.meta.url);
const bookingsHome = fs.readFileSync(new URL('Sources/Views/Tabs/BookingsHomeView.swift', repoRoot), 'utf8');
const companions = fs.readFileSync(new URL('Sources/AppShell/IumrahTravelCompanionsView.swift', repoRoot), 'utf8');
const traveler = fs.readFileSync(new URL('Sources/AppShell/IumrahTravelerProfileView.swift', repoRoot), 'utf8');
const travelInfo = fs.readFileSync(new URL('Sources/Views/Booking/JourneyTravelInfoView.swift', repoRoot), 'utf8');
const project = fs.readFileSync(new URL('project.yml', repoRoot), 'utf8');

test('booking status is passport-first and gates later fulfillment stages', () => {
  assert.match(bookingsHome, /bookingFulfillmentCenter\(session, checkout: activeCheckout\)/);
  assert.match(bookingsHome, /IumrahBookingPassportsView/);
  assert.match(bookingsHome, /Прикрепить паспорт/);
  assert.match(bookingsHome, /Оплата откроется после подтверждения наличия/);
  assert.match(bookingsHome, /Авиабилеты, виза и номера бронирований/);
  assert.match(bookingsHome, /guideTransferStatusCard/);
  assert.match(bookingsHome, /IumrahGuideTransferView/);
  assert.doesNotMatch(bookingsHome, /KYC · iumrah Security/);
  assert.match(bookingsHome, /IumrahPolicyDetailView\(kind: \.refund\)/);
  assert.match(bookingsHome, /Color\.iumrahPrimaryButtonBackground/);
});

test('traveler flow accepts passport photo first and keeps manual fields optional', () => {
  assert.match(companions, /companionTripTitle\(session\)/);
  assert.match(companions, /session\.booking\.route\.originCode/);
  assert.match(companions, /session\.booking\.route\.outboundDestination/);
  assert.match(companions, /Прикрепите страницу загранпаспорта/);
  assert.match(traveler, /Достаточно чёткой фотографии страницы с данными/);
  assert.match(traveler, /Не обязательно/);
  assert.match(traveler, /ускорят оформление бронирования/);
  assert.match(traveler, /uploadPassport/);
});

test('travel info uses native segmented city switch and second-precision prayer timer', () => {
  assert.match(travelInfo, /\.pickerStyle\(\.segmented\)/);
  assert.match(travelInfo, /TimelineView\(\.periodic\(from: \.now, by: 1\)\)/);
  assert.match(travelInfo, /ДО СЛЕДУЮЩЕЙ МОЛИТВЫ/);
  assert.doesNotMatch(travelInfo, /scaleEffect\(x: 0\.94/);
});

test('client release metadata exposes valid numeric App Store versions', () => {
  assert.match(project, /MARKETING_VERSION: "[0-9]+(?:\.[0-9]+){1,2}"/);
  assert.match(project, /CURRENT_PROJECT_VERSION: "[0-9]+"/);
});
