import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve(process.cwd(), '..', '..');
const read = (file) => fs.readFileSync(path.join(root, file), 'utf8');

test('Account owns active/past trip switching and exposes full trip history', () => {
  const account = read('Sources/AppShell/IumrahAccountView.swift');
  const history = read('Sources/AppShell/IumrahTripsHistoryView.swift');
  assert.match(account, /private enum IumrahAccountTripScope/);
  assert.match(account, /Picker\("", selection: \$tripScope\)/);
  assert.match(account, /IumrahTripsHistoryView/);
  assert.match(history, /navigationBarTitleDisplayMode\(\.large\)/);
  assert.match(history, /toolbar\(\.visible, for: \.navigationBar\)/);
});

test('Bookings tab no longer owns active/past scope and routes status to stable status page', () => {
  const source = read('Sources/Views/Tabs/BookingsHomeView.swift');
  assert.doesNotMatch(source, /private enum BookingScope/);
  assert.doesNotMatch(source, /@State private var bookingScope/);
  assert.match(source, /BookingStatusView\(bookingID: session\.id\)/);
});

test('Booking components page uses native navigation and Flight First component design after itinerary', () => {
  const detail = read('Sources/Views/Booking/BookingDetailView.swift');
  const components = read('Sources/Views/Booking/BookingFlightFirstComponentsView.swift');
  assert.match(detail, /bookingIdentityStrip\(session\)/);
  assert.match(detail, /BookingItineraryCalendarView/);
  assert.match(detail, /BookingFlightFirstComponentsView/);
  assert.match(detail, /toolbar\(\.visible, for: \.navigationBar\)/);
  assert.doesNotMatch(detail, /safeAreaInset\(edge: \.top[^\n]*\{ topBar \}/);
  assert.match(components, /AirlineLogoView/);
  assert.match(components, /BookingFlightFirstHotelCard/);
  assert.match(components, /includedServicesCard/);
});

test('Booking status page never replaces operational state with raw checkout auth error', () => {
  const source = read('Sources/Views/Booking/BookingStatusView.swift');
  assert.match(source, /checkout = try\? await accountService\.checkout/);
  assert.match(source, /await bookings\.refreshAll\(\)/);
  assert.doesNotMatch(source, /UNAUTHORIZED/);
  assert.doesNotMatch(source, /error\.localizedDescription/);
});

test('Ziyarats uses system navigation and native sheet detents instead of custom overlay entry', () => {
  const ziyarats = read('Sources/Ziyarats/ZiyaratViews.swift');
  const home = read('Sources/Views/Home/HomeDashboardView.swift');
  assert.match(ziyarats, /\.sheet\(isPresented: \$panelPresented\)/);
  assert.match(ziyarats, /\.presentationDetents/);
  assert.match(ziyarats, /\.presentationDragIndicator\(\.visible\)/);
  assert.match(ziyarats, /toolbar\(\.visible, for: \.navigationBar\)/);
  assert.match(home, /navigationDestination\(isPresented: \$showZiyarats\)/);
});

test('Standalone Transfer reuses selection experience without search and preserves package-only business rule', () => {
  const source = read('Sources/Views/Home/HomeAppleStoreSections.swift');
  const start = source.indexOf('struct IumrahTransferServiceView');
  assert.ok(start >= 0);
  const transfer = source.slice(start);
  assert.match(transfer, /vehiclePicker/);
  assert.match(transfer, /Haramain High Speed Railway/);
  assert.match(transfer, /packageOnlyNotice/);
  assert.doesNotMatch(transfer, /@State private var searched/);
  assert.doesNotMatch(transfer, /searchTransferTitle/);
});

test('Push registration prefers permanent account auth and falls back to booking proof', () => {
  const source = read('Sources/State/BookingStore.swift');
  const helperStart = source.indexOf('private func pushHeaderCandidates');
  assert.ok(helperStart >= 0);
  const helper = source.slice(helperStart, helperStart + 1000);
  const accountIndex = helper.indexOf('Authorization');
  const bookingIndex = helper.indexOf('x-booking-token');
  assert.ok(accountIndex >= 0 && bookingIndex > accountIndex);
  assert.match(source, /for headers in candidates/);
  assert.match(source, /isAuthorizationFailure\(error\)/);
  assert.match(source, /accountService\.tripDetail/);
});

test('Main tab headers expose both notifications and sidebar chrome', () => {
  const source = read('Sources/Views/Components/IumrahRootPageTitle.swift');
  assert.match(source, /chrome\.openNotifications\(\)/);
  assert.match(source, /chrome\.openSidebar\(\)/);
  assert.match(source, /bell\.badge\.fill/);
  assert.match(source, /line\.3\.horizontal/);
});
