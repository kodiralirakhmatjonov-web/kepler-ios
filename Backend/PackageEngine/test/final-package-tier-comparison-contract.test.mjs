import assert from "node:assert/strict";
import fs from "node:fs";
import test from "node:test";

const root = new URL("../../../", import.meta.url);
const journey = fs.readFileSync(new URL("Sources/State/JourneyStore.swift", root), "utf8");
const finalPackage = fs.readFileSync(new URL("Sources/Views/Package/FinalPackageView.swift", root), "utf8");
const pricing = fs.readFileSync(new URL("Backend/PackageEngine/src/pricing.ts", root), "utf8");

const comparisonBuilder = journey.slice(
  journey.indexOf("func buildPackageTierComparisons"),
  journey.indexOf("private func returnOffer")
);

const comparisonPricing = journey.slice(
  journey.indexOf("private func makePackageTierComparisonOption"),
  journey.indexOf("private func comparisonMakkahCatalog")
);

test("final package comparison keeps the exact selected flight itinerary and fare source", () => {
  assert.match(comparisonBuilder, /guard let outbound = selectedOutbound, outbound\.isVerifiedForBooking/);
  assert.match(comparisonBuilder, /guard let value = selectedInbound/);
  assert.match(comparisonBuilder, /returnPairMatches\(value, outbound: outbound\)/);
  assert.match(journey, /private func returnPairMatches[\s\S]*?packageFlightPath == \.aviasalesSelected[\s\S]*?return returnOffer\(inbound, matches: outbound\)/);
  assert.match(comparisonBuilder, /pricingOffer = value/);
  assert.match(comparisonBuilder, /pricingOffer = outbound/);
  assert.doesNotMatch(comparisonBuilder, /LocalFXRateService\.shared\.usd/);
  assert.match(comparisonPricing, /packageEngine\.packageQuote\(/);
  assert.match(comparisonPricing, /pricingOffer: flight\.pricingOffer/);
  assert.match(comparisonPricing, /outboundOffer: flight\.outboundOffer/);
  assert.match(comparisonPricing, /inboundOffer: flight\.inboundOffer/);
});

test("comparison hotel policy uses the agreed named hotels and Business Primary Hotel economy fallback", () => {
  assert.match(comparisonBuilder, /"Nawazi Hotel", "Nawazi Watheer Hotel"/);
  assert.match(comparisonBuilder, /"Mihrab Tayyiba", "Mihrab Tayba", "Mihrab Taiba"/);
  assert.match(comparisonBuilder, /"Shohada Hotel", "Al Shohada Hotel", "Shuhada Hotel", "Al Shuhada Hotel"/);
  assert.match(comparisonBuilder, /"Address Jabal Omar Makkah", "Address Jabal Omar", "Jabal Omar Address"/);
  assert.match(comparisonBuilder, /"Pullman Zamzam Madina", "Pullman Zamzam Madinah", "Pullman Zamzam"/);
  assert.match(comparisonBuilder, /if let policy = comparisonHotelPolicy\(for: tier, city: city\) \{[\s\S]*?return fixedComparisonHotel\(/);
  assert.match(comparisonBuilder, /let requestedStars = \[2, 1\]/);
  assert.match(comparisonBuilder, /packageEngine\.primaryHotel\(tier: tier, stars: stars, city: city\)/);
});

test("comparison recomputes hotel room nights but does not silently add Luxury Yukon or paid Comfort-Luxury meals", () => {
  assert.match(comparisonPricing, /trip: comparisonTrip/);
  assert.match(comparisonPricing, /makkahHotelID: makkahHotel\.id/);
  assert.match(comparisonPricing, /madinahHotelID: madinahHotel\?\.id/);
  assert.match(comparisonPricing, /makkahLunch: false/);
  assert.match(comparisonPricing, /makkahDinner: false/);
  assert.match(comparisonPricing, /madinahDinner: false/);
  assert.match(comparisonPricing, /transferVehicle: selectedTransferVehicle/);
  assert.doesNotMatch(comparisonPricing, /transferVehicle:\s*\.yukon/);
  assert.doesNotMatch(comparisonPricing, /selectedTransferVehicle\s*=\s*\.yukon/);
  assert.match(pricing, /const LUXURY_MARKUP = 0\.35/);
  assert.match(pricing, /input\.tier === "luxury" \? LUXURY_MARKUP : STANDARD_MARKUP/);
});

test("carousel comparison is explicit, reversible UX and opens on the configured package", () => {
  assert.match(finalPackage, /ScrollView\(\.horizontal, showsIndicators: false\)/);
  assert.match(finalPackage, /PackageTier\.allCases/);
  assert.match(finalPackage, /\.scrollTargetBehavior\(\.viewAligned\)/);
  assert.match(finalPackage, /\.scrollPosition\(id: \$focusedComparisonTier, anchor: \.center\)/);
  assert.match(finalPackage, /option\.tier != journey\.trip\.packageTier/);
  assert.match(finalPackage, /Task \{ await applyPackageTierComparison\(option\) \}/);
  assert.match(finalPackage, /packageRecommendationCard/);
  assert.match(finalPackage, /packageDifferenceCard/);
  assert.match(finalPackage, /includedServicesCard/);
  assert.match(finalPackage, /fixedFlightComparisonNote/);
  assert.match(finalPackage, /let selectedTier = journey\.trip\.packageTier/);
  assert.match(finalPackage, /comparisonOptions = options[\s\S]*?focusedComparisonTier = selectedTier/);
  assert.match(finalPackage, /Text\(continueBookingTitle\)/);
  assert.doesNotMatch(finalPackage, /safeAreaInset\(edge: \.bottom/);
});
