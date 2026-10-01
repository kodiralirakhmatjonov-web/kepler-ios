import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve(process.cwd(), '..', '..');
const read = (file) => fs.readFileSync(path.join(root, file), 'utf8');

test('Hotel First variants are a peekable colored horizontal carousel with indicators', () => {
  const source = read('Sources/Views/Hotels/HotelDetailView.swift');
  assert.match(source, /ScrollView\(\.horizontal, showsIndicators: false\)/);
  assert.match(source, /carouselProxy\.size\.width \* 0\.82/);
  assert.match(source, /scrollTargetBehavior\(\.viewAligned/);
  assert.match(source, /selectedPackageVariantScrollID/);
  assert.match(source, /ForEach\(hotelPackagePreviews\.indices/);
  assert.match(source, /Color\(red: 1\.0, green: 0\.60, blue: 0\.10\)/);
  assert.match(source, /strokeBorder\(accent\.fill\.opacity\(0\.42\)/);
});

test('Booking and status switch in place with one native compact segmented control', () => {
  const detail = read('Sources/Views/Booking/BookingDetailView.swift');
  const checkout = read('Sources/Views/Booking/PilgrimCheckoutView.swift');
  const switcher = read('Sources/Views/Booking/BookingPageSwitcher.swift');
  assert.match(detail, /@State private var selectedPrimaryPage: BookingPrimaryPage = \.booking/);
  assert.match(detail, /BookingPageSwitcher\([\s\S]*selection: selectedPrimaryPage/);
  assert.match(detail, /selectedPrimaryPage = \.booking/);
  assert.match(detail, /selectedPrimaryPage = \.status/);
  assert.match(detail, /PilgrimCheckoutView\(bookingID: bookingID, presentation: \.bookingStatus\)/);
  assert.doesNotMatch(detail, /navigationDestination\(isPresented: \$showStatusPage/);
  assert.match(checkout, /BookingDetailView\(bookingID: bookingID, initialPage: \.status\)/);
  assert.match(switcher, /Picker\(/);
  assert.match(switcher, /\.pickerStyle\(\.segmented\)/);
  assert.doesNotMatch(switcher, /IumrahGlassGroup|\.iumrahGlass\(/);
});

test('obsolete booking lifecycle chain is disabled in favor of checkout status', () => {
  const source = read('Sources/Views/Booking/BookingStatusView.swift');
  assert.match(source, /canonical booking-status experience is PilgrimCheckoutView/);
  assert.match(source, /PilgrimCheckoutView\(bookingID: bookingID, presentation: \.screen\)/);
  assert.doesNotMatch(source, /Safar bosqichlari/);
});

test('booking included services open native detail sheets instead of dead rows', () => {
  const source = read('Sources/Views/Booking/BookingFlightFirstComponentsView.swift');
  assert.match(source, /@State private var serviceDetail/);
  assert.match(source, /\.sheet\(item: \$serviceDetail\)/);
  assert.match(source, /BookingIncludedServiceDetailSheet/);
  assert.match(source, /ToolbarItem\(placement: \.topBarLeading\)/);
  assert.match(source, /Image\(systemName: "xmark"\)/);
  assert.match(source, /presentationDetents\(\[\.medium, \.large\]\)/);
});

test('Account identity reuses booking dome animation language without activity dots', () => {
  const source = read('Sources/AppShell/IumrahAccountIdentityHeroCard.swift');
  assert.match(source, /Canvas\(rendersAsynchronously: true\)/);
  assert.match(source, /aspectRatio\(1\.60, contentMode: \.fit\)/);
  assert.match(source, /Text\("iumrah ID"\)/);
  assert.match(source, /isFlipped\.toggle\(\)/);
  assert.doesNotMatch(source, /IdentityActivityDots|BookingActivityDots/);
});

test('chat and deletion prefer permanent account authorization before stale booking proof', () => {
  const source = read('Sources/State/BookingStore.swift');
  const start = source.indexOf('private func clientHeaderCandidates');
  assert.ok(start >= 0);
  const helper = source.slice(start, start + 900);
  assert.ok(helper.indexOf('Authorization') >= 0);
  assert.ok(helper.indexOf('x-booking-token') > helper.indexOf('Authorization'));
  assert.match(source, /performWithClientAuthorization/);
  assert.match(source, /chatService\.loadChat/);
  assert.match(source, /bookingService\.deleteBooking/);
});

test('Care chat composer stays compact and maps authorization failures', () => {
  const source = read('Sources/Views/Chat/BookingChatView.swift');
  assert.match(source, /frame\(minHeight: 40, maxHeight: 86/);
  assert.match(source, /lineLimit\(1\.\.\.3\)/);
  assert.match(source, /chatErrorMessage\(error\)/);
  assert.match(source, /isAuthorizationError/);
});
