var ASSET_ORDER = ["BTC", "ETH", "SOL", "HYPE", "ZEC"]
var ASSET_IDS = { bitcoin: "BTC", ethereum: "ETH", solana: "SOL", hyperliquid: "HYPE", zcash: "ZEC" }
var ASSET_LOGOS = { BTC: "assets/coins/btc.svg", ETH: "assets/coins/eth.svg", SOL: "assets/coins/sol.svg", HYPE: "assets/coins/hype.svg", ZEC: "assets/coins/zec.svg" }
var CURVE_FLAT_THRESHOLD_BPS = 5

function finiteNumber(value) {
  if (value === null || value === undefined || value === "" || typeof value === "boolean") return null
  var number = Number(value)
  return isFinite(number) ? number : null
}

function parseJson(raw) {
  if (raw && typeof raw === "object") return raw
  try {
    var parsed = JSON.parse(String(raw || ""))
    return parsed && typeof parsed === "object" ? parsed : null
  } catch (error) { return null }
}

function changePercent(current, previous) {
  var now = finiteNumber(current)
  var before = finiteNumber(previous)
  if (now === null || before === null || before === 0) return null
  return (now - before) / Math.abs(before) * 100
}

function emptyAsset(symbol) {
  var id = ""
  for (var key in ASSET_IDS) if (ASSET_IDS[key] === symbol) id = key
  return { id: id, symbol: symbol, price: null, marketCap: null, change24h: null, change7d: null, updatedAt: "" }
}

function assetLogo(symbol) {
  return ASSET_LOGOS[String(symbol || "").toUpperCase()] || ""
}

function parseMarkets(raw) {
  var data = parseJson(raw)
  if (!data || typeof data.length !== "number") return null
  var bySymbol = {}
  var recognized = 0
  for (var i = 0; i < data.length; i++) {
    var row = data[i]
    var symbol = row && ASSET_IDS[row.id]
    if (!symbol) continue
    var asset = emptyAsset(symbol)
    asset.price = finiteNumber(row.current_price)
    asset.marketCap = finiteNumber(row.market_cap)
    asset.change24h = finiteNumber(row.price_change_percentage_24h_in_currency)
    if (asset.change24h === null) asset.change24h = finiteNumber(row.price_change_percentage_24h)
    asset.change7d = finiteNumber(row.price_change_percentage_7d_in_currency)
    asset.updatedAt = typeof row.last_updated === "string" ? row.last_updated : ""
    bySymbol[symbol] = asset
    recognized++
  }
  if (recognized === 0) return null
  return { coins: ASSET_ORDER.map(function(symbol) { return bySymbol[symbol] || emptyAsset(symbol) }) }
}

function parseGlobal(raw) {
  var parsed = parseJson(raw)
  var data = parsed && parsed.data
  if (!data || typeof data !== "object") return null
  var cap = finiteNumber(data.total_market_cap && data.total_market_cap.usd)
  var volume = finiteNumber(data.total_volume && data.total_volume.usd)
  var btc = finiteNumber(data.market_cap_percentage && data.market_cap_percentage.btc)
  var eth = finiteNumber(data.market_cap_percentage && data.market_cap_percentage.eth)
  var marketChange = finiteNumber(data.market_cap_change_percentage_24h_usd)
  var volumeChange = finiteNumber(data.volume_change_percentage_24h_usd)
  if (cap === null && volume === null && btc === null && eth === null && marketChange === null && volumeChange === null) return null
  return { marketCap: cap, change24h: marketChange, volume24h: volume, volumeChange24h: volumeChange, btcDominance: btc, ethDominance: eth }
}

function parseFearGreed(raw) {
  var parsed = parseJson(raw)
  var rows = parsed && parsed.data
  if (!rows || typeof rows.length !== "number" || rows.length === 0) return null
  var current = finiteNumber(rows[0] && rows[0].value)
  var previous = finiteNumber(rows[1] && rows[1].value)
  if (current === null) return null
  return {
    value: Math.max(0, Math.min(100, Math.round(current))),
    classification: rows[0] && typeof rows[0].value_classification === "string" ? rows[0].value_classification : "Unclassified",
    change: previous === null ? null : current - previous
  }
}

function timestampSeconds(row) {
  var timestamp = finiteNumber(row && row.date)
  return timestamp === null ? null : timestamp * 1000
}

function observationsAtIntervals(rows, valueReader) {
  if (!rows || typeof rows.length !== "number") return null
  var observations = []
  for (var i = 0; i < rows.length; i++) {
    var time = timestampSeconds(rows[i])
    var value = finiteNumber(valueReader(rows[i]))
    if (time !== null && value !== null) observations.push({ time: time, value: value })
  }
  observations.sort(function(a, b) { return a.time - b.time })
  if (observations.length === 0) return null
  var latest = observations[observations.length - 1]
  function preceding(days) {
    var cutoff = latest.time - days * 24 * 60 * 60 * 1000
    for (var index = observations.length - 2; index >= 0; index--)
      if (observations[index].time <= cutoff) return observations[index]
    return null
  }
  return { latest: latest, day: preceding(1), week: preceding(7) }
}

function parseStablecoins(raw) {
  var rows = parseJson(raw)
  var selected = observationsAtIntervals(rows, function(row) { return row && row.totalCirculatingUSD && row.totalCirculatingUSD.peggedUSD })
  if (!selected) return null
  return {
    total: selected.latest.value,
    netChange7d: selected.week ? selected.latest.value - selected.week.value : null,
    change7d: selected.week ? changePercent(selected.latest.value, selected.week.value) : null,
    latestTimestamp: selected.latest.time,
    comparisonTimestamp: selected.week ? selected.week.time : null
  }
}

function parseTvl(raw) {
  var rows = parseJson(raw)
  var selected = observationsAtIntervals(rows, function(row) { return row && row.tvl })
  if (!selected) return null
  return {
    total: selected.latest.value,
    change1d: selected.day ? changePercent(selected.latest.value, selected.day.value) : null,
    change7d: selected.week ? changePercent(selected.latest.value, selected.week.value) : null,
    latestTimestamp: selected.latest.time,
    dayTimestamp: selected.day ? selected.day.time : null,
    weekTimestamp: selected.week ? selected.week.time : null
  }
}

function parseOverview(raw) {
  var data = parseJson(raw)
  if (!data || typeof data !== "object") return null
  var total = finiteNumber(data.total24h)
  if (total === null) return null
  return { total: total, change: finiteNumber(data.change_1d) }
}

function parseHyperliquidPerps(raw) {
  var response = parseJson(raw)
  var rows = response && typeof response.length === "number" ? response[1] : null
  if (!rows || typeof rows.length !== "number") return null
  var total = 0
  var count = 0
  for (var i = 0; i < rows.length; i++) {
    var volume = finiteNumber(rows[i] && rows[i].dayNtlVlm)
    if (volume === null || volume < 0) continue
    total += volume
    count++
  }
  return count > 0 && isFinite(total) ? { total: total, markets: count } : null
}

function hexadecimalQuantity(value) {
  var text = typeof value === "string" ? value : ""
  if (!/^0x(?:0|[1-9a-fA-F][0-9a-fA-F]*)$/.test(text)) return null
  var result = 0
  for (var i = 2; i < text.length; i++) {
    result = result * 16 + parseInt(text.charAt(i), 16)
    if (!isFinite(result) || result > Number.MAX_SAFE_INTEGER) return null
  }
  return result
}

function parseGas(raw) {
  var data = parseJson(raw)
  if (!data || data.error || data.jsonrpc !== "2.0") return null
  var wei = hexadecimalQuantity(data.result)
  if (wei === null) return null
  return { wei: wei, gwei: wei / 1000000000 }
}

function xmlTag(entry, name) {
  var expression = new RegExp("<(?:[A-Za-z0-9_]+:)?" + name + "(?:\\s[^>]*)?>([^<]+)<\\/(?:[A-Za-z0-9_]+:)?" + name + ">", "i")
  var match = expression.exec(entry)
  return match ? match[1] : ""
}

function treasuryDateTimestamp(value) {
  var text = String(value || "").replace(/^\s+|\s+$/g, "")
  var american = /^(\d{2})-(\d{2})-(\d{4})$/.exec(text)
  if (american) return Date.UTC(Number(american[3]), Number(american[1]) - 1, Number(american[2]))
  var parsed = Date.parse(text)
  return isFinite(parsed) ? parsed : NaN
}

function curveState(spreadBps) {
  var spread = finiteNumber(spreadBps)
  if (spread === null) return "Unavailable"
  if (Math.abs(spread) <= CURVE_FLAT_THRESHOLD_BPS) return "Flat"
  return spread < 0 ? "Inverted" : "Normal"
}

function parseTreasury(raw) {
  var text = String(raw || "")
  if (text.indexOf("<") < 0) return null
  var entries = text.match(/<entry(?:\s[^>]*)?>[\s\S]*?<\/entry>/gi) || []
  if (entries.length === 0) entries = text.match(/<G_NEW_DATE(?:\s[^>]*)?>[\s\S]*?<\/G_NEW_DATE>/gi) || []
  var observations = []
  for (var i = 0; i < entries.length; i++) {
    var two = finiteNumber(xmlTag(entries[i], "BC_2YEAR"))
    var ten = finiteNumber(xmlTag(entries[i], "BC_10YEAR"))
    var dateText = xmlTag(entries[i], "NEW_DATE") || xmlTag(entries[i], "Date") || xmlTag(entries[i], "updated")
    var time = treasuryDateTimestamp(dateText)
    if (two !== null && ten !== null && isFinite(time)) observations.push({ time: time, twoYear: two, tenYear: ten })
  }
  observations.sort(function(a, b) { return a.time - b.time })
  if (observations.length === 0) return null
  var latest = observations[observations.length - 1]
  var previous = observations.length > 1 ? observations[observations.length - 2] : null
  var spread = (latest.tenYear - latest.twoYear) * 100
  return {
    dateTimestamp: latest.time,
    twoYear: latest.twoYear,
    tenYear: latest.tenYear,
    tenYearChangeBps: previous ? (latest.tenYear - previous.tenYear) * 100 : null,
    spreadBps: spread,
    curveState: curveState(spread)
  }
}

function trimFixed(value, digits) {
  return value.toFixed(digits).replace(/\.0+$|(?:(\.\d*[1-9]))0+$/, "$1")
}

function groupInteger(text) {
  var sign = text.charAt(0) === "-" ? "-" : ""
  var digits = sign ? text.slice(1) : text
  return sign + digits.replace(/\B(?=(\d{3})+(?!\d))/g, ",")
}

function formatCompact(value, currency) {
  var number = finiteNumber(value)
  if (number === null) return "—"
  var absolute = Math.abs(number)
  var suffix = ""
  var divisor = 1
  if (absolute >= 1e12) { suffix = "T"; divisor = 1e12 }
  else if (absolute >= 1e9) { suffix = "B"; divisor = 1e9 }
  else if (absolute >= 1e6) { suffix = "M"; divisor = 1e6 }
  else if (absolute >= 1e3) { suffix = "K"; divisor = 1e3 }
  var scaled = number / divisor
  var digits = Math.abs(scaled) >= 100 ? 0 : (Math.abs(scaled) >= 10 ? 1 : 2)
  return (currency ? "$" : "") + trimFixed(scaled, digits) + suffix
}

function formatPrecise(value, options) {
  var number = finiteNumber(value)
  if (number === null) return "—"
  var config = options || {}
  var minimum = config.minimumFractionDigits === undefined ? 0 : config.minimumFractionDigits
  var maximum = config.maximumFractionDigits === undefined ? 2 : config.maximumFractionDigits
  var fixed = number.toFixed(maximum).split(".")
  var decimals = fixed.length > 1 ? fixed[1] : ""
  while (decimals.length > minimum && decimals.charAt(decimals.length - 1) === "0") decimals = decimals.slice(0, -1)
  return (config.currency ? "$" : "") + groupInteger(fixed[0]) + (decimals ? "." + decimals : "")
}

function formatPrice(value) {
  var number = finiteNumber(value)
  if (number === null) return "—"
  var absolute = Math.abs(number)
  var digits = absolute < 0.01 ? 6 : (absolute < 1 ? 4 : (absolute < 10 ? 3 : 2))
  return formatPrecise(number, { currency: true, minimumFractionDigits: digits, maximumFractionDigits: digits })
}

function formatPercent(value, digits) {
  var number = finiteNumber(value)
  if (number === null) return "—"
  return Math.abs(number).toFixed(digits === undefined ? 1 : digits) + "%"
}

function formatSignedCompact(value) {
  var number = finiteNumber(value)
  if (number === null) return "—"
  return (number > 0 ? "+" : (number < 0 ? "−" : "")) + formatCompact(Math.abs(number), true)
}

function formatGas(value) {
  var number = finiteNumber(value)
  if (number === null) return "—"
  return trimFixed(number, number < 1 ? 3 : 1) + " gwei"
}

function formatDateUS(timestamp) {
  var value = finiteNumber(timestamp)
  if (value === null) return "—"
  var date = new Date(value)
  if (!isFinite(date.getTime())) return "—"
  var months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
  return months[date.getUTCMonth()] + " " + date.getUTCDate() + ", " + date.getUTCFullYear()
}

function direction(value) {
  var number = finiteNumber(value)
  if (number === null || number === 0) return { arrow: "→", sign: 0 }
  return number > 0 ? { arrow: "▲", sign: 1 } : { arrow: "▼", sign: -1 }
}

function freshness(lastSuccess, intervalMs, now) {
  var success = finiteNumber(lastSuccess)
  var interval = finiteNumber(intervalMs)
  var current = finiteNumber(now)
  if (current === null) current = Date.now()
  if (success === null || interval === null || interval <= 0) return { ageMs: null, stale: false, label: "Waiting" }
  var age = Math.max(0, current - success)
  return { ageMs: age, stale: age > interval * 2, label: age > interval * 2 ? "Stale" : "Fresh" }
}

if (typeof module !== "undefined") module.exports = {
  ASSET_ORDER: ASSET_ORDER,
  ASSET_LOGOS: ASSET_LOGOS,
  CURVE_FLAT_THRESHOLD_BPS: CURVE_FLAT_THRESHOLD_BPS,
  finiteNumber: finiteNumber,
  parseJson: parseJson,
  assetLogo: assetLogo,
  changePercent: changePercent,
  parseMarkets: parseMarkets,
  parseGlobal: parseGlobal,
  parseFearGreed: parseFearGreed,
  parseStablecoins: parseStablecoins,
  parseTvl: parseTvl,
  parseOverview: parseOverview,
  parseHyperliquidPerps: parseHyperliquidPerps,
  hexadecimalQuantity: hexadecimalQuantity,
  parseGas: parseGas,
  curveState: curveState,
  parseTreasury: parseTreasury,
  formatCompact: formatCompact,
  formatPrecise: formatPrecise,
  formatPrice: formatPrice,
  formatPercent: formatPercent,
  formatSignedCompact: formatSignedCompact,
  formatGas: formatGas,
  formatDateUS: formatDateUS,
  direction: direction,
  freshness: freshness
}
