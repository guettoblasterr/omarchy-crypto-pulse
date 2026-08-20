const test = require('node:test');
const assert = require('node:assert/strict');
const Model = require('../Model.js');

test('normalizes the fixed five-asset order, fields, and nulls', () => {
  const parsed = Model.parseMarkets([
    { id: 'zcash', current_price: 55.25, market_cap: 900_000_000, price_change_percentage_24h: -2, price_change_percentage_7d_in_currency: 4 },
    { id: 'bitcoin', current_price: 69_474.34, market_cap: 1_390_000_000_000, price_change_percentage_24h: 7.4, price_change_percentage_7d_in_currency: 9.5 },
    { id: 'hyperliquid', current_price: null, market_cap: 15_000_000_000, price_change_percentage_24h: null, price_change_percentage_7d_in_currency: -3 },
    { id: 'solana', current_price: 84, market_cap: 49_000_000_000, price_change_percentage_24h: 0, price_change_percentage_7d_in_currency: null },
    { id: 'ethereum', current_price: 2257, market_cap: 272_000_000_000, price_change_percentage_24h_in_currency: 18.2, price_change_percentage_7d_in_currency: 20.5 }
  ]);
  assert.deepEqual(parsed.coins.map((coin) => coin.symbol), ['BTC', 'ETH', 'SOL', 'HYPE', 'ZEC']);
  assert.equal(parsed.coins[0].marketCap, 1_390_000_000_000);
  assert.equal(parsed.coins[1].change24h, 18.2);
  assert.equal(parsed.coins[3].price, null);
  assert.equal(parsed.coins[3].change24h, null);
  assert.equal('image' in parsed.coins[4], false);
  assert.equal(Model.assetLogo('BTC'), 'assets/coins/btc.svg');
  assert.equal(Model.assetLogo('hype'), 'assets/coins/hype.svg');
  assert.equal(Model.assetLogo('../unknown'), '');
  assert.equal(Model.parseMarkets('{broken'), null);
  assert.equal(Model.parseMarkets([{ id: 'unknown', current_price: 1 }]), null);
});

test('fills an omitted fixed asset without reordering available data', () => {
  const parsed = Model.parseMarkets([{ id: 'bitcoin', current_price: 1 }]);
  assert.deepEqual(parsed.coins.map((coin) => coin.symbol), Model.ASSET_ORDER);
  assert.equal(parsed.coins[1].price, null);
});

test('treats null, empty, booleans, and non-finite fields as missing', () => {
  assert.equal(Model.finiteNumber(null), null);
  assert.equal(Model.finiteNumber(''), null);
  assert.equal(Model.finiteNumber(true), null);
  assert.equal(Model.finiteNumber('not-a-number'), null);
  assert.equal(Model.finiteNumber('12.5'), 12.5);
  assert.equal(Model.parseGlobal({ data: { total_market_cap: { usd: null } } }), null);
});

test('forces exact English/US separators and handles narrow price ranges', () => {
  assert.equal(Model.formatPrecise(69474.34, { currency: true, minimumFractionDigits: 2, maximumFractionDigits: 2 }), '$69,474.34');
  assert.equal(Model.formatPrecise(-1234567.8, { minimumFractionDigits: 2, maximumFractionDigits: 2 }), '-1,234,567.80');
  assert.equal(Model.formatPrice(0.004321), '$0.004321');
  assert.equal(Model.formatPrice(1.2), '$1.200');
  assert.equal(Model.formatPrice(12), '$12.00');
  assert.equal(Model.formatCompact(69_474, true), '$69.5K');
  assert.equal(Model.formatCompact(1_390_000_000_000, true), '$1.39T');
  assert.equal(Model.formatCompact(999_999_999_999, true), '$1000B');
  assert.equal(Model.formatCompact(null, true), '—');
  assert.equal(Model.formatPercent(7.4, 1), '7.4%');
  assert.equal(Model.formatPercent(0, 1), '0.0%');
  assert.equal(Model.formatPercent(-999.9, 1), '999.9%');
  assert.equal(Model.formatSignedCompact(-1_250_000), '−$1.25M');
  assert.equal(Model.formatDateUS(Date.UTC(2026, 7, 20)), 'Aug 20, 2026');
});

test('parses global cap and volume changes plus BTC and ETH dominance', () => {
  assert.deepEqual(Model.parseGlobal({ data: {
    total_market_cap: { usd: 2_500_000_000_000 },
    total_volume: { usd: 100_000_000_000 },
    market_cap_change_percentage_24h_usd: 4.65,
    volume_change_percentage_24h_usd: -3.25,
    market_cap_percentage: { btc: 56.2, eth: 11.1 }
  } }), {
    marketCap: 2_500_000_000_000,
    change24h: 4.65,
    volume24h: 100_000_000_000,
    volumeChange24h: -3.25,
    btcDominance: 56.2,
    ethDominance: 11.1
  });
});

test('calculates stablecoin absolute and percentage seven-day changes', () => {
  const day = 24 * 60 * 60;
  const latest = 2_000_000_000;
  const parsed = Model.parseStablecoins([
    { date: latest - 7 * day, totalCirculatingUSD: { peggedUSD: 100 } },
    { date: latest - 6 * day, totalCirculatingUSD: { peggedUSD: 105 } },
    { date: latest, totalCirculatingUSD: { peggedUSD: 110 } }
  ]);
  assert.equal(parsed.total, 110);
  assert.equal(parsed.netChange7d, 10);
  assert.equal(parsed.change7d, 10);
  assert.equal(parsed.comparisonTimestamp, (latest - 7 * day) * 1000);
});

test('calculates TVL changes from nearest observations at least 1d and 7d earlier', () => {
  const day = 24 * 60 * 60;
  const latest = 2_000_000_000;
  const parsed = Model.parseTvl([
    { date: latest - 8 * day, tvl: 80 },
    { date: latest - 7 * day, tvl: 100 },
    { date: latest - 1 * day, tvl: 110 },
    { date: latest, tvl: 121 }
  ]);
  assert.equal(parsed.total, 121);
  assert.equal(parsed.change1d, 10);
  assert.equal(parsed.change7d, 21);
  assert.equal(Model.parseTvl([{ date: latest, tvl: null }]), null);
});

test('converts strict hexadecimal Wei quantities to gwei', () => {
  assert.equal(Model.hexadecimalQuantity('0x3b9aca00'), 1_000_000_000);
  assert.deepEqual(Model.parseGas({ jsonrpc: '2.0', id: 1, result: '0x6b49d200' }), { wei: 1_800_000_000, gwei: 1.8 });
  assert.equal(Model.formatGas(1.8), '1.8 gwei');
  assert.equal(Model.formatGas(0.085675637), '0.086 gwei');
  assert.equal(Model.parseGas({ jsonrpc: '2.0', result: '0x01' }), null);
  assert.equal(Model.parseGas({ jsonrpc: '2.0', error: { code: -1 } }), null);
});

test('parses Fear and Greed and clamps malformed out-of-range values', () => {
  assert.deepEqual(Model.parseFearGreed({ data: [
    { value: '42', value_classification: 'Fear' },
    { value: '38', value_classification: 'Fear' }
  ] }), { value: 42, classification: 'Fear', change: 4 });
  assert.equal(Model.parseFearGreed({ data: [{ value: '120' }] }).value, 100);
  assert.equal(Model.parseFearGreed({ data: [{ value: null }] }), null);
});

test('parses overview totals and changes defensively', () => {
  assert.deepEqual(Model.parseOverview({ total24h: 1_200_000, change_1d: -4.25 }), { total: 1_200_000, change: -4.25 });
  assert.equal(Model.parseOverview({ total24h: null, change_1d: 2 }), null);
  assert.equal(Model.changePercent(1, 0), null);
});

test('sums only valid Hyperliquid perpetual-market 24h notional volume', () => {
  assert.deepEqual(Model.parseHyperliquidPerps([
    { universe: [{ name: 'BTC' }, { name: 'ETH' }] },
    [
      { dayNtlVlm: 100 },
      { dayNtlVlm: '250.5' },
      { dayNtlVlm: null },
      { dayNtlVlm: -1 }
    ]
  ]), { total: 350.5, markets: 2 });
  assert.equal(Model.parseHyperliquidPerps([{ universe: [] }, []]), null);
  assert.equal(Model.parseHyperliquidPerps({ dayNtlVlm: 1 }), null);
});

test('calculates Treasury fields, English/US date, and normal curve state', () => {
  const xml = `<feed>
    <entry><d:NEW_DATE>2026-08-19T00:00:00Z</d:NEW_DATE><d:BC_2YEAR>3.70</d:BC_2YEAR><d:BC_10YEAR>4.20</d:BC_10YEAR></entry>
    <entry><d:NEW_DATE>2026-08-20T00:00:00Z</d:NEW_DATE><d:BC_2YEAR>3.75</d:BC_2YEAR><d:BC_10YEAR>4.23</d:BC_10YEAR></entry>
  </feed>`;
  const parsed = Model.parseTreasury(xml);
  assert.ok(Math.abs(parsed.tenYearChangeBps - 3) < 1e-9);
  assert.ok(Math.abs(parsed.spreadBps - 48) < 1e-9);
  assert.equal(parsed.curveState, 'Normal');
  assert.equal(Model.formatDateUS(parsed.dateTimestamp), 'Aug 20, 2026');
});

test('defines a five-basis-point flat threshold and tests every curve state', () => {
  assert.equal(Model.CURVE_FLAT_THRESHOLD_BPS, 5);
  assert.equal(Model.curveState(-5.01), 'Inverted');
  assert.equal(Model.curveState(-5), 'Flat');
  assert.equal(Model.curveState(0), 'Flat');
  assert.equal(Model.curveState(5), 'Flat');
  assert.equal(Model.curveState(5.01), 'Normal');
  assert.equal(Model.curveState(null), 'Unavailable');
});

test('marks stale only after two complete intervals and returns semantic arrows', () => {
  const now = 1_000_000;
  assert.equal(Model.freshness(now - 2_000, 1_000, now).stale, false);
  assert.equal(Model.freshness(now - 2_001, 1_000, now).stale, true);
  assert.deepEqual(Model.direction(1), { arrow: '▲', sign: 1 });
  assert.deepEqual(Model.direction(-1), { arrow: '▼', sign: -1 });
  assert.deepEqual(Model.direction(0), { arrow: '→', sign: 0 });
});
