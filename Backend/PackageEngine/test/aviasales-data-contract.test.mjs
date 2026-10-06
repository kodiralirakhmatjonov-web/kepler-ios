import assert from 'node:assert/strict';
import fs from 'node:fs';

const backend = fs.readFileSync(new URL('../src/aviasales-data.ts', import.meta.url), 'utf8');
const env = fs.readFileSync(new URL('../src/env.ts', import.meta.url), 'utf8');
const index = fs.readFileSync(new URL('../src/index.ts', import.meta.url), 'utf8');
const iosService = fs.readFileSync(new URL('../../../Sources/Services/AviasalesFlightDiscoveryService.swift', import.meta.url), 'utf8');
const flightsView = fs.readFileSync(new URL('../../../Sources/Views/Flights/IumrahFlightDiscoveryView.swift', import.meta.url), 'utf8');
const packageSearch = fs.readFileSync(new URL('../src/package-search.ts', import.meta.url), 'utf8');
const journeyStore = fs.readFileSync(new URL('../../../Sources/State/JourneyStore.swift', import.meta.url), 'utf8');
const hotelsHome = fs.readFileSync(new URL('../../../Sources/Views/Tabs/HotelsHomeView.swift', import.meta.url), 'utf8');
const primaryHotel = fs.readFileSync(new URL('../../../Sources/Views/Hotels/PrimaryHotelView.swift', import.meta.url), 'utf8');

assert.match(env, /TRAVELPAYOUTS_API_TOKEN\?: string/);
assert.match(index, /GET.*\/api\/package\/flights\/data|request\.method === "GET"[\s\S]*\/api\/package\/flights\/data/);
assert.match(backend, /\/aviasales\/v3\/prices_for_dates/);
assert.match(backend, /\/aviasales\/v3\/grouped_prices/);
assert.match(backend, /"X-Access-Token": token/);
assert.match(backend, /AVIASALES_ORIGIN = "https:\/\/www\.aviasales\.com"/);
assert.match(backend, /path\.startsWith\("\/search\/"\)/);
assert.ok(!iosService.includes('TRAVELPAYOUTS_API_TOKEN'), 'iOS client must never contain the Travelpayouts token');
assert.match(iosService, /\/api\/package\/flights\/data/);
assert.match(flightsView, /IumrahFlightDiscoveryStore/);
assert.match(flightsView, /Глобальный поиск/);
assert.match(flightsView, /Рекомендует iumrah/);
assert.match(flightsView, /Text\("Aviasales"\)/);
assert.match(flightsView, /FlightDiscoveryTicketCard/);
assert.match(flightsView, /График цен/);
assert.match(flightsView, /searchProgress/);
assert.match(flightsView, /navigationDestination\(item: \$selectedOffer\)/);
assert.match(flightsView, /CuratedFlightRecommendationService\.shared\.load/);


assert.match(backend, /hydrateReturnIdentities/);
assert.match(backend, /return_airline_code/);
assert.match(backend, /return_flight_number/);
assert.ok(!flightsView.includes('Искать билеты'), 'Global Flights must auto-search without the old search button');
assert.match(flightsView, /flightSearchConfigurationCard/);
assert.match(flightsView, /Маршрут Umrah/);
assert.match(flightsView, /Рейсы туда/);
assert.match(flightsView, /Обратные рейсы/);
assert.match(flightsView, /hasSearched && rankedOffers\.isEmpty[\s\S]*partnerGatewayCard/);
assert.match(flightsView, /Обновить цену/);
assert.match(flightsView, /Цена обновлена только что/);
assert.match(packageSearch, /providerID\.startsWith\("aviasales:"\)/);
assert.match(packageSearch, /pickAviasalesReturnRow/);
assert.match(journeyStore, /prepareAviasalesSelectedQuote/);
assert.match(journeyStore, /prepareFlightFirstHotelStage/);
assert.match(hotelsHome, /startFlightFirstTrip/);
assert.match(hotelsHome, /Билет туда‑обратно выбран/);
assert.match(primaryHotel, /PrimaryHotelEntryMode/);
assert.match(primaryHotel, /flightFirstTierSelector/);

console.log('Aviasales Data API server proxy + iOS discovery surface contract OK');
