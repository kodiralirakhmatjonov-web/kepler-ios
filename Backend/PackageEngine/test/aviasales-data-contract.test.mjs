import assert from 'node:assert/strict';
import fs from 'node:fs';

const backend = fs.readFileSync(new URL('../src/aviasales-data.ts', import.meta.url), 'utf8');
const env = fs.readFileSync(new URL('../src/env.ts', import.meta.url), 'utf8');
const index = fs.readFileSync(new URL('../src/index.ts', import.meta.url), 'utf8');
const iosService = fs.readFileSync(new URL('../../../Sources/Services/AviasalesFlightDiscoveryService.swift', import.meta.url), 'utf8');
const flightsView = fs.readFileSync(new URL('../../../Sources/Views/Flights/IumrahFlightDiscoveryView.swift', import.meta.url), 'utf8');

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
assert.match(flightsView, /Авиабилеты/);
assert.match(flightsView, /Купить самому на Aviasales/);
assert.match(flightsView, /FlightDiscoveryTicketCard/);
assert.match(flightsView, /График цен/);
assert.match(flightsView, /Прямые рейсы/);

console.log('Aviasales Data API server proxy + iOS discovery surface contract OK');
