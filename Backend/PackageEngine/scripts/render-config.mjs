import fs from 'node:fs';

const [hotelDatabaseID, zoneID] = process.argv.slice(2);
const accountID = process.env.CLOUDFLARE_ACCOUNT_ID;
const apiToken = process.env.CLOUDFLARE_API_TOKEN;

if (!hotelDatabaseID || !zoneID || !accountID || !apiToken) {
  console.error('Usage: node scripts/render-config.mjs <HOTEL_D1_DATABASE_ID> <ZONE_ID> with CLOUDFLARE_ACCOUNT_ID and CLOUDFLARE_API_TOKEN');
  process.exit(1);
}

const headers = {
  Authorization: `Bearer ${apiToken}`,
  'Content-Type': 'application/json',
};

async function findBookingDatabase() {
  const listResponse = await fetch(
    `https://api.cloudflare.com/client/v4/accounts/${accountID}/d1/database?per_page=100`,
    { headers },
  );
  if (!listResponse.ok) throw new Error(`Unable to list D1 databases (${listResponse.status})`);
  const listPayload = await listResponse.json();
  const databases = Array.isArray(listPayload.result) ? listPayload.result : [];
  const candidates = [];

  for (const database of databases) {
    const id = database.uuid ?? database.id;
    if (!id) continue;
    try {
      const queryResponse = await fetch(
        `https://api.cloudflare.com/client/v4/accounts/${accountID}/d1/database/${id}/query`,
        {
          method: 'POST',
          headers,
          body: JSON.stringify({
            sql: `
              SELECT
                (SELECT COUNT(*) FROM bookings) AS booking_count,
                (SELECT MAX(COALESCE(updated_at, created_at, '')) FROM bookings) AS newest_booking,
                (SELECT COUNT(*) FROM pragma_table_info('bookings') WHERE name IN ('id','access_token_hash','payload_json')) AS required_columns
            `,
          }),
        },
      );
      if (!queryResponse.ok) continue;
      const payload = await queryResponse.json();
      const rows = payload?.result?.[0]?.results ?? [];
      const row = rows[0];
      if (!row || Number(row.required_columns ?? 0) !== 3) continue;
      candidates.push({
        id: String(id),
        name: String(database.name ?? 'iumrah-bookings'),
        bookingCount: Number(row.booking_count ?? 0),
        newestBooking: String(row.newest_booking ?? ''),
      });
    } catch {
      // Not the production booking database. Keep scanning.
    }
  }

  if (!candidates.length) {
    throw new Error('No existing D1 database with the production bookings schema (id/access_token_hash/payload_json) was found.');
  }

  // The active database is the one receiving the newest bookings. Count is a
  // deterministic tie-breaker for cloned/legacy databases.
  candidates.sort((a, b) => {
    const byNewest = b.newestBooking.localeCompare(a.newestBooking);
    if (byNewest !== 0) return byNewest;
    return b.bookingCount - a.bookingCount;
  });
  const selected = candidates[0];
  console.log('Bookings D1 candidates:', candidates.map(item => `${item.name}:${item.bookingCount}:${item.newestBooking}`).join(', '));
  return { id: selected.id, name: selected.name };
}

const bookingDatabase = await findBookingDatabase();
console.log(`Using existing bookings D1: ${bookingDatabase.name} (${bookingDatabase.id})`);

const input = fs.readFileSync('wrangler.template.jsonc', 'utf8');
const output = input
  .replaceAll('__D1_DATABASE_ID__', hotelDatabaseID)
  .replaceAll('__BOOKING_D1_DATABASE_ID__', bookingDatabase.id)
  .replaceAll('__BOOKING_D1_DATABASE_NAME__', bookingDatabase.name.replaceAll('"', '\\"'))
  .replaceAll('__ZONE_ID__', zoneID)
  .replaceAll('__APPLE_WEB_CLIENT_ID__', JSON.stringify(String(process.env.APPLE_WEB_CLIENT_ID ?? '')).slice(1, -1));

JSON.parse(output);
fs.writeFileSync('wrangler.generated.jsonc', output);
console.log('Generated wrangler.generated.jsonc with HOTELS_DB + BOOKINGS_DB bindings');
