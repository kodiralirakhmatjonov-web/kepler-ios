import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import { execFileSync } from 'node:child_process';

const here = new URL('../', import.meta.url);
const read = path => fs.readFileSync(new URL(path, here), 'utf8');

const itinerary = read('src/itinerary-planner.ts');
const email = read('src/client-account-security.ts');
const sourceRoot = new URL('../../Sources/', here);
const ios = path => fs.readFileSync(new URL(path, sourceRoot), 'utf8');
const widgets = fs.readFileSync(new URL('../../WidgetExtension/IumrahWidgets.swift', here), 'utf8');

// Node 22 is already the production workflow version; strip TypeScript type annotations
// and exercise the actual server planner without a network/DB dependency.
test('server itinerary returns Turkish and Indonesian for primary and regional locale tags', () => {
  const program = `
    import {buildBookingItinerary} from ${JSON.stringify(new URL('src/itinerary-planner.ts', here).href)};
    const booking = {
      input: {includeMadinah: false, flightTripType: 'oneWay'},
      stay: {makkahNights: 3, madinahNights: 0},
      generatorTrace: {outbound: {origin: 'TAS', destination: 'JED', departureAt: '2026-11-10T10:00:00+05:00', arrivalAt: '2026-11-10T15:00:00+03:00'}}
    };
    for (const [code, expected] of [['tr', 'Suudi Arabistan’a varış'],['tr-TR', 'Suudi Arabistan’a varış'],['id', 'Tiba di Arab Saudi'], ['id_ID','Tiba di Arab Saudi'],['uz-Cyrl','Саудия Арабистонига етиб келиш'], ['ru', 'Прилёт в Саудовскую Аравию'],['en', 'Arrival in Saudi Arabia']]) {
      const items = buildBookingItinerary('test-booking', booking, code).items;
      if (items.length < 5 || items[0].title !== expected) throw new Error('Itinerary locale mismatch: '+code+' '+JSON.stringify(items[0]));
    }
    console.log('LOCALE_ITINERARY_PASS');
  `;
  const out = execFileSync(process.execPath, ['--no-warnings', '--experimental-strip-types', '--input-type=module', '-e', program], {encoding: 'utf8'});
  assert.match(out, /LOCALE_ITINERARY_PASS/);
});

test('transactional account emails supply verified translations for all 6 locales', () => {
  for (const key of ['ru', 'en', 'uz', '"uz-cyrl"', 'tr', 'id']) {
    assert.match(email, new RegExp(`\\b${key.replaceAll('"', '')}|${key}: \\{`));
  }
  assert.match(email, /"tr" \|\| primary === "id"/);
  assert.match(email, /iumrah e-posta adresinizi doğrulayın/);
  assert.match(email, /Verifikasi email iumrah Anda/);
  assert.match(email, /Bu kod 10 dakika geçerlidir/);
  assert.match(email, /Kode ini berlaku selama 10 menit/);
  assert.match(email, /function emailCopy\(/);
});

test('app-selected locale is synchronised to widgets, including on language change', () => {
  assert.match(ios('Services/IumrahWidgetSyncService.swift'), /languageCode: languageCode/);
  assert.match(ios('Views/RootView.swift'), /languageCode: settings.language.rawValue/);
  assert.match(ios('Views/RootView.swift'), /\.onChange\(of: settings.language.rawValue\)[\s\S]{0,140}syncWidgets\(\)/);
  assert.match(ios('WidgetShared/IumrahWidgetSnapshot.swift'), /var languageCode: String\? = nil/);
  assert.match(widgets, /IumrahWidgetSharedStore.load\(\).languageCode/);
  assert.match(widgets, /case \.tr: return tr/);
  assert.match(widgets, /case \.id: return id/);
  assert.match(widgets, /Locale\(identifier: "tr_TR"\)/);
  assert.match(widgets, /Locale\(identifier: "id_ID"\)/);
});

test('Russian hardcoded booking labels removed in favor of the 6-language dictionary', () => {
  for (const source of ['AppShell/IumrahAccountView.swift', 'Views/Booking/BookingDetailView.swift', 'Views/Booking/BookingCheckoutView.swift']) {
    assert.doesNotMatch(ios(source), /Text\("Бронь \\\(/);
    assert.match(ios(source), /L10n\.format\("booking_number_short", settings.language/);
  }
});

test('Ziyarats keeps Turkish and Indonesian payload translations and offline fallback text', () => {
  const source = ios('Services/ZiyaratService.swift');
  assert.match(source, /"uz-cyrl", "tr", "id"/);
  assert.match(source, /extraOfflineTranslations/);
  assert.match(source, /"tr", extra\?\.trTitle/);
  assert.match(source, /"id", extra\?\.idTitle/);
});

test('VoiceOver helper has native text branches for all six app languages', () => {
  const helper = ios('Core/IumrahAccessibilityCopy.swift');
  for (const key of ['russian', 'english', 'uzbek', 'uzbekCyrillic', 'turkish', 'indonesian']) {
    assert.match(helper, new RegExp(`case \\.${key}: return`));
  }
  assert.match(ios('Views/Flights/IumrahInteractiveGlobe.swift'), /IumrahAccessibilityCopy.text/);
  assert.match(ios('Views/Components/ConnectivityStatusPill.swift'), /localizedConnectivityStatus/);
});
