import assert from "node:assert/strict";
import fs from "node:fs";
import test from "node:test";

const root = new URL("../../../", import.meta.url);
const journey = fs.readFileSync(new URL("Sources/State/JourneyStore.swift", root), "utf8");
const store = fs.readFileSync(new URL("Sources/State/HotelStorefrontStore.swift", root), "utf8");
const models = fs.readFileSync(new URL("Sources/Models/HotelStorefrontModels.swift", root), "utf8");
const home = fs.readFileSync(new URL("Sources/Views/Tabs/HotelsHomeView.swift", root), "utf8");
const primary = fs.readFileSync(new URL("Sources/Views/Hotels/PrimaryHotelView.swift", root), "utf8");
const imageCache = fs.readFileSync(new URL("Sources/Services/HotelImageCache.swift", root), "utf8");
const hotelCard = fs.readFileSync(new URL("Sources/Views/Components/HotelCard.swift", root), "utf8");
const finalPackage = fs.readFileSync(new URL("Sources/Views/Package/FinalPackageView.swift", root), "utf8");
const bookingDetail = fs.readFileSync(new URL("Sources/Views/Booking/BookingDetailView.swift", root), "utf8");
const flightDiscovery = fs.readFileSync(new URL("Sources/Views/Flights/IumrahFlightDiscoveryView.swift", root), "utf8");

test("Primary Hotel selection resolves the Business editorial slot before factual-star fallback", () => {
  assert.match(journey, /resolvedPrimaryHotel\(from: all, city: "Makkah"\)/);
  assert.match(journey, /resolvedPrimaryHotel\(from: all, cityAliases: aliases\)/);
  const makkahBlock = journey.slice(journey.indexOf("func loadMakkahHotels"), journey.indexOf("func loadMadinahHotels"));
  const madinahBlock = journey.slice(journey.indexOf("func loadMadinahHotels"), journey.indexOf("private func resolvedPrimaryHotel"));
  assert.doesNotMatch(makkahBlock, /primaryCandidates/);
  assert.doesNotMatch(madinahBlock, /primaryCandidates/);
  assert.match(madinahBlock, /"Madinah", "Medina", "Madina", "Medinah"/);
});

test("Flights Scanner composes short Comfort and 4-15 day Standard packages from regional Uzbekistan departures", () => {
  assert.match(models, /enum StorefrontUmrahPackageKind/);
  assert.match(models, /case makkahComfortShort/);
  assert.match(models, /case makkahMadinahStandard/);
  assert.match(store, /preferredNames: \["Nawazi Hotel", "Nawazi Watheer Hotel"\]/);
  assert.match(store, /preferredNames: \["Mihrab Tayyiba", "Mihrab Tayba", "Mihrab Taiba"\]/);
  assert.match(store, /preferredNames: \["Shohada Hotel", "Al Shohada Hotel", "Shuhada Hotel", "Al Shuhada Hotel"\]/);
  assert.match(store, /\(2\.\.\.3\)\.contains\(gapDays\)/);
  assert.match(store, /\(4\.\.\.15\)\.contains\(gapDays\)/);
  assert.match(store, /returnDestination: preferredDestination/);
  assert.match(store, /returnDestination: "TAS"/);
  assert.match(store, /output\[pair\.returnOptionID\] == nil/);
  assert.match(store, /trip\.packageTier = \.comfort/);
  assert.match(store, /trip\.packageTier = \.standard/);
  assert.match(store, /trip\.adults = 1/);
  assert.match(store, /packageEngine\.packageQuote\(/);
  assert.doesNotMatch(store, /LocalPackagePricingEngine\.calculate\(/);
  assert.match(store, /TripStayPlanner\.breakdown/);
});

test("Flights storefront uses the dedicated Aviasales discovery experience and keeps ready Flight First packages below it", () => {
  assert.match(home, /IumrahFlightDiscoveryView\(\)/);
  assert.match(home, /readyPackagesTitle/);
  assert.match(home, /StorefrontFlightOptionCard/);
  assert.match(home, /let preview = storefront\.packagePreview\(for: option\)/);
  assert.match(home, /selectedFlightPackage = preview/);

  assert.match(flightDiscovery, /FlightDiscoveryPriceGraphSheet/);
  assert.match(flightDiscovery, /calendarPresented/);
  assert.match(flightDiscovery, /passengersPresented/);
  assert.match(flightDiscovery, /FlightDiscoverySearchMode/);
  assert.match(flightDiscovery, /iumrahRecommended/);
  assert.match(flightDiscovery, /CuratedFlightRecommendationService/);
  assert.match(flightDiscovery, /searchProgress/);
  assert.doesNotMatch(flightDiscovery, /FlightDiscoveryDirectFlightsSheet/);
  assert.match(flightDiscovery, /directOnly/);
  assert.match(flightDiscovery, /recently found Aviasales fares/);
  assert.match(flightDiscovery, /journey\.trip\.flightTripType = \.roundTrip/);

  const card = home.slice(home.indexOf("private struct StorefrontFlightOptionCard"), home.indexOf("private struct StorefrontUmrahPackageDetailView"));
  assert.match(card, /HotelCachedImage\(rawURL: imageURL\)/);
  assert.match(card, /AirlineLogoView/);
  assert.match(card, /packagePreview\.pricePerPerson/);
  assert.doesNotMatch(card, /option\.perTravelerFare/);

  const flightsBoard = home.slice(home.indexOf("private var flightsBoard"), home.indexOf("MARK: - Sunday Club"));
  assert.match(flightsBoard, /IumrahFlightDiscoveryView\(\)/);
  assert.match(flightsBoard, /readyPackagesTitle/);
  assert.doesNotMatch(flightsBoard, /StorefrontBaselineFlightCard/);
});

test("panoramic hotel photos are constrained by the card viewport and the meal UI remains intact", () => {
  assert.match(imageCache, /GeometryReader \{ proxy in/);
  assert.match(imageCache, /frame\(width: proxy\.size\.width, height: proxy\.size\.height\)/);
  assert.match(primary, /let contentWidth = max\(0, viewport\.size\.width - \(IumrahDesign\.pagePadding \* 2\)\)/);
  assert.match(primary, /frame\(width: contentWidth, alignment: \.leading\)/);
  assert.match(primary, /HotelCachedImage\(rawURL: hotel\.coverImageURL\)/);
  assert.match(primary, /mealPlanCard\(role: role\)/);
  assert.match(primary, /frame\(maxWidth: \.infinity, alignment: \.leading\)/);
  assert.match(hotelCard, /HotelCachedImage\(rawURL: hotel\.coverImageURL\)/);
  assert.match(finalPackage, /HotelCachedImage\(rawURL: hotel\.coverImageURL/);
  assert.match(bookingDetail, /HotelCachedImage\(/);
  assert.doesNotMatch(finalPackage.slice(finalPackage.indexOf("private func hotelExpandedContent"), finalPackage.indexOf("private var transferExpandedContent")), /AsyncImage/);
});
