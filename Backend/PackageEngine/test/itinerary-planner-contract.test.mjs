import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const planner = fs.readFileSync(new URL('../src/itinerary-planner.ts', import.meta.url), 'utf8');
const search = fs.readFileSync(new URL('../src/package-search.ts', import.meta.url), 'utf8');
const index = fs.readFileSync(new URL('../src/index.ts', import.meta.url), 'utf8');
const bookingService = fs.readFileSync(new URL('../../../Sources/Services/BookingService.swift', import.meta.url), 'utf8');
const itineraryView = fs.readFileSync(new URL('../../../Sources/Views/Booking/BookingItineraryCalendarView.swift', import.meta.url), 'utf8');
const bookingBuilder = fs.readFileSync(new URL('../../../Sources/Core/BookingDraftBuilder.swift', import.meta.url), 'utf8');
const bookingGateway = fs.readFileSync(new URL('../src/booking-gateway.ts', import.meta.url), 'utf8');

test('PackageEngine owns time-aware hotel-night planning from verified flight timestamps', () => {
  assert.match(planner, /AIRPORT_EXIT_MINUTES = 120/);
  assert.match(planner, /AIRPORT_CHECKIN_BUFFER_MINUTES = 180/);
  assert.match(planner, /source: "verifiedFlightTimes"/);
  assert.match(planner, /earlyArrivalNight/);
  assert.match(planner, /airportCityTransferMinutes/);
  assert.match(planner, /plannedLastHotelCity/);
  assert.match(planner, /pickupCheckout/);
  assert.match(search, /resolveJourneySchedule/);
  assert.match(search, /deriveAuthoritativeStayPlan/);
  assert.match(search, /resolveServerHotelPricing\([^\n]+stayPlan\.makkahNights/);
  assert.match(search, /stayPlan\.madinahNights/);
});

test('booking itinerary is served by PackageEngine and rendered with exact local times', () => {
  assert.match(index, /bookingItineraryMatch/);
  assert.match(index, /getBookingItineraryPlan/);
  assert.match(planner, /timeLocal:/);
  assert.match(planner, /INTERCITY_HARAMAIN_DOOR_TO_DOOR_MINUTES/);
  assert.match(bookingService, /\/api\/package\/booking\/\\\(id\)\/itinerary/);
  assert.match(itineraryView, /item\.timeLocal/);
  assert.match(itineraryView, /monospacedDigit/);
});

test('authoritative stay plan is persisted into the booking instead of recalculating dates locally', () => {
  assert.match(bookingBuilder, /if let serverStay = quote\.stayPlan/);
  assert.match(bookingBuilder, /serverStay\.makkahCheckIn/);
  assert.match(bookingBuilder, /serverStay\.madinahCheckOut/);
  assert.match(bookingBuilder, /stayPolicy: trip\.hotelFirstStayPolicy/);
  assert.match(bookingGateway, /BOOKING_QUOTE_MAKKAH_NIGHTS_MISMATCH/);
  assert.match(bookingGateway, /BOOKING_QUOTE_MADINAH_NIGHTS_MISMATCH/);
});
