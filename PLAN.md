# Crypto Market Pulse — execution plan

**Status:** v1.0.0 published on GitHub; marketplace submission awaiting owner approval
**Target:** Omarchy 4 / Quattro `bar-widget` (verified locally on Omarchy 4.0.0-1)
**Repository:** `guettoblasterr/omarchy-crypto-pulse`
**Plugin ID:** `io.github.guettoblasterr.crypto-market-pulse`
**Timebox:** 60-minute target from implementation start; completion and validation of Phase 1 take precedence over a hard cutoff

## Outcome

Ship a public, theme-aware Omarchy bar widget that gives a compact view of crypto prices, sentiment, DeFi liquidity/activity/leverage, and U.S. Treasury context. It must run without API keys, keep working when one source fails, pass Omarchy validation, and be ready for marketplace submission.

## Product contract

### Collapsed bar widget

- Show the CoinGecko Bitcoin logo, compact USD price (for example `$69.5K`), and 24-hour change.
- Use both color and an arrow for positive/negative movement.
- Click toggles the detail panel.
- Middle click requests a manual refresh with a 30-second cooldown.

### Detail panel

- Header: `Market Pulse` plus freshness state.
- Hero: Alternative.me Fear & Greed value, classification, and change from yesterday.
- Market: BTC, ETH, and SOL logo, price, 24-hour change, and 7-day sparkline.
- Global crypto: total market cap, 24-hour volume, and BTC dominance.
- DeFi pulse:
  - `Liquidity`: current stablecoin supply and its change over 7 days.
  - `Activity`: global 24-hour DEX volume and its change from the previous 24 hours.
  - `Leverage`: current global open interest and its change over 24 hours.
- Macro context:
  - U.S. 10-year Treasury yield and daily basis-point change.
  - 10Y–2Y curve spread calculated from the same Treasury response.
- Attribution:
  - `Alternative.me` displayed next to Fear & Greed.
  - CoinGecko, DefiLlama, Alternative.me, and U.S. Treasury listed in the information/footer area.

### Behaviour

- Public UI copy is in English. Monetary values are USD: compact notation in the bar and locale-aware, more precise notation in the panel.
- No API key, backend, installer, service, privilege elevation, package installation, or downloaded code execution.
- All network calls use fixed HTTPS URLs from QML/JavaScript.
- Each data source fails independently; one failure must not empty the whole panel.
- Keep the last valid in-memory value and mark a source stale visibly once its last successful update is older than two of that source's target refresh intervals.
- Parse nullable/malformed fields defensively.
- Do not present the data as financial advice.
- Do not calculate an opaque investment score. The headline uses the published Fear & Greed classification; other signals remain visible and explainable.

## Data contracts

| Source | Fixed endpoint and data | Refresh target |
|---|---|---:|
| CoinGecko markets | `https://api.coingecko.com/api/v3/coins/markets?vs_currency=usd&ids=bitcoin%2Cethereum%2Csolana&sparkline=true&price_change_percentage=24h` — logos, prices, 24h changes, 168-point 7d sparklines, timestamps | 2 min |
| CoinGecko global | `https://api.coingecko.com/api/v3/global` — total market cap, volume, BTC dominance, global 24h change | 10 min |
| Alternative.me | `https://api.alternative.me/fng/?limit=2` — current and previous Fear & Greed values | 60 min |
| DefiLlama stablecoins | `https://stablecoins.llama.fi/stablecoincharts/all` — latest and nearest observation at least seven days earlier from `totalCirculatingUSD.peggedUSD` | 60 min |
| DefiLlama DEX overview | `https://api.llama.fi/overview/dexs?excludeTotalDataChart=true&excludeTotalDataChartBreakdown=true&dataType=dailyVolume` — `total24h` and `change_1d` | 60 min |
| DefiLlama open-interest overview | `https://api.llama.fi/overview/open-interest?excludeTotalDataChart=true&excludeTotalDataChartBreakdown=true&dataType=openInterestAtEnd` — `total24h` and `change_1d` | 60 min |
| U.S. Treasury yield curve | `https://home.treasury.gov/sites/default/files/interest-rates/yield.xml` — latest and previous valid `BC_2YEAR`/`BC_10YEAR` observations | 6 h |

These no-key endpoints and response fields were sampled successfully on 2026-08-20. They remain external contracts: implementation must tolerate HTTP errors, schema changes, missing observations, weekends, holidays, and rate limiting. Alternative.me attribution must remain adjacent to the displayed index, as required by its API terms.

Refreshes should start with small jitter, apply bounded exponential backoff after failures or HTTP 429, and never overlap an already-running request to the same source.

## Expected final repository structure

This is the repository shape after Phase 2. Phase 1 does not create the README, license, or preview that are explicitly assigned to Phase 2.

```text
.
├── manifest.json
├── BarWidget.qml
├── Panel.qml
├── Model.js
├── Sparkline.qml
├── tests/
│   └── model.test.js
├── README.md
├── LICENSE
└── preview.png
```

Public contracts:

- `manifest.json` declares `schemaVersion: 1`, the permanent ID, name, version, author `guettoblasterr`, MIT license, description, only `kinds: ["bar-widget"]`, `entryPoints.barWidget: "BarWidget.qml"`, and `barWidget` metadata (`displayName`, description, category, `allowMultiple: false`, and `defaultSection: "right"`).
- `BarWidget.qml` is the sole Omarchy entry point and exposes the expected open/close/opened panel contract.
- `Panel.qml` owns request scheduling and renders partial/loading/stale/error states.
- `Model.js` contains pure parsing, normalization, formatting, freshness, curve, and change calculations. It remains Node-testable without third-party dependencies.
- `Sparkline.qml` renders a bounded numeric series and contains no data-fetching logic.

## Phase 1 — Working vertical slice

Goal: install and use the complete widget locally with real data.

- [ ] Initialize the local Git repository on a feature branch without creating the remote yet.
- [x] Add the root `manifest.json` using ID `io.github.guettoblasterr.crypto-market-pulse`, author `guettoblasterr`, and default bar section `right`.
- [x] Inspect and clone `omarchy.clock` as the primary first-party reference for the `bar-widget` and nested-panel lifecycle contract; use `omarchy.weather` only as the secondary reference for remote-data refresh and failure behaviour.
- [x] Remove development-only `omarchy.clonedFrom` metadata and use the permanent namespaced ID consistently in the publishable repository copy.
- [x] Implement fixed-URL asynchronous requests for all approved sources.
- [x] Normalize every response into one small view model; discard raw payloads after parsing.
- [x] Render BTC/ETH/SOL logos, values, semantic arrows, and 7-day sparklines.
- [x] Render Fear & Greed, global crypto, DeFi pulse, and Treasury context.
- [x] Implement independent loading, partial, stale, retry, and last-valid-value behaviour.
- [x] Add focused unit tests for parsing, null handling, formatting, stablecoin aggregation, basis-point changes, curve spread, and sparkline normalization.
- [x] Validate the manifest, JavaScript tests, QML syntax, enable/disable behaviour, shell summon/hide, click toggle, manual refresh, and shell reload.

Phase 1 acceptance gate:

- The bar and panel work on the installed Omarchy 4.0.0-1 system.
- Every approved signal renders from live data.
- Disconnecting or breaking one source leaves the remaining sections usable.
- No secrets, external packages, helper scripts, or privileged operations exist.
- The user reviews the running widget before Phase 2.

## Iteration V2 — Compact information redesign

Goal: revise the working Phase 1 slice into a substantially smaller, denser, and more useful dashboard before publication work begins. This iteration supersedes the Phase 1 product contract wherever the two conflict. It is product iteration work, not authorization to start Phase 2 publishing tasks.

### Approved V2 product decisions

- The public name and panel header are always `Crypto Market Pulse`; do not shorten the header to `Market Pulse`.
- All public copy, labels, classifications, dates, number formatting, and separators are English/US. Use decimal points and comma grouping, for example `$69,474.34`, `7.4%`, `4.65%`, and `1.8 gwei`. Do not use Spanish numeric notation anywhere in the project.
- Target a panel around `460 × 500 px`, adjusting only as needed for real content and the available screen. It must be materially smaller than the Phase 1 panel.
- Use clearly bounded visual sections with restrained rectangles, borders, background fills, or separators derived from Omarchy theme primitives.
- Keep the CoinGecko asset logos and textual fallbacks.
- Remove all price sparklines and their reserved layout space. Remove `Sparkline.qml` once no code references it.
- The fixed V2 asset list is BTC, ETH, SOL, HYPE, and ZEC. This iteration does not add a configurable watchlist.
- Each asset row shows logo, symbol, USD price, compact USD market cap, 24-hour change, and 7-day change.
- The collapsed bar remains compact and continues to show the BTC logo, compact USD price, and 24-hour direction/change.
- No visible refresh button, middle-click refresh, manual-refresh cooldown, or other public refresh control. Normal operation is fully automatic. A non-visual IPC refresh method may remain only if it materially helps diagnostics and testing.
- Loading/error/stale indicators remain available but should be quiet: show the global state only when it is `Partial`, `Stale`, or `Offline`, and show per-source problems only beside the affected section.
- Do not add opaque scores or questionable cross-provider ratios merely to increase KPI count.

### V2 layout and information hierarchy

1. **Header**
   - `Crypto Market Pulse`.
   - A small exceptional-state label only when data is partial, stale, or offline.

2. **Fear & Greed gauge**
   - Create an original compact QML `Canvas` semicircular gauge inspired by the reviewed reference, without copying or bundling third-party artwork.
   - Draw a red → orange → yellow → green arc representing 0–100, a value-positioned needle, the current numeric value, published classification, and change from yesterday.
   - Keep `Alternative.me` attribution adjacent to the gauge.
   - Use both color and text so the signal remains understandable without relying on color alone.

3. **Assets**
   - Five dense rows in this fixed order: BTC, ETH, SOL, HYPE, ZEC.
   - Columns: logo/symbol, price, abbreviated market cap, 24h, and 7d.
   - Use `hyperliquid` and `zcash` as the CoinGecko IDs for HYPE and ZEC; these IDs were sampled successfully on 2026-08-20.
   - Preserve arrows and semantic colors for positive, negative, and zero movements.

4. **Market**
   - Total crypto market cap and global 24h market-cap change.
   - Global 24h volume and its 24h change when the field is valid.
   - BTC dominance and ETH dominance from CoinGecko `market_cap_percentage.btc` and `.eth`.

5. **DeFi & Network**
   - Global DeFi TVL with 24h and 7d changes.
   - Stablecoin supply plus absolute 7d net issuance/redemption in USD; percentage change may remain secondary.
   - DEX 24h volume and daily change.
   - Hyperliquid perpetual-market 24h notional volume, aggregated only from valid `dayNtlVlm` fields returned by its official Info API.
   - Global open interest and daily change.
   - Ethereum gas price displayed as `⛽ ETH Gas` and a value in gwei.

6. **Macro**
   - U.S. 2-year Treasury yield.
   - U.S. 10-year Treasury yield and daily basis-point change.
   - 10Y–2Y spread in basis points.
   - A plain-English curve state derived directly from the spread: `Inverted` below zero, `Flat` close to zero, or `Normal` above zero. Define and test the small flat threshold explicitly; do not imply a trading recommendation.
   - Latest Treasury observation date in subdued text.

7. **Footer**
   - Compact source attribution and `Not financial advice` copy.

### V2 data-contract changes

| Source | Fixed endpoint and V2 data | Refresh target |
|---|---|---:|
| CoinGecko markets | `https://api.coingecko.com/api/v3/coins/markets?vs_currency=usd&ids=bitcoin%2Cethereum%2Csolana%2Chyperliquid%2Czcash&sparkline=false&price_change_percentage=24h%2C7d` — five logos, prices, market caps, 24h/7d changes, timestamps | 2 min |
| CoinGecko global | Existing `/api/v3/global` endpoint — total market cap, market-cap change, volume, volume change when present, BTC dominance, and ETH dominance | 10 min |
| DefiLlama TVL | `https://api.llama.fi/v2/historicalChainTvl` — latest global TVL and nearest valid observations at least 24 hours and seven days earlier | 60 min |
| Ethereum gas | Candidate fixed no-key JSON-RPC endpoint `https://ethereum-rpc.publicnode.com`, POST body `{"jsonrpc":"2.0","method":"eth_gasPrice","params":[],"id":1}` — parse the hexadecimal Wei quantity and convert it to gwei | 30 sec |
| Hyperliquid perpetuals | `https://api.hyperliquid.xyz/info`, POST `{"type":"metaAndAssetCtxs"}` — sum valid `dayNtlVlm` values from the perpetual asset contexts and retain the market count | 60 min |
| Existing sources | Alternative.me, stablecoins, DEX, open interest, and Treasury remain as defined above | unchanged |

CoinGecko's documented global response includes both BTC and ETH dominance. Its documented Demo/Onchain endpoint catalog does **not** expose a general Ethereum gas oracle. Therefore V2 must not claim that ETH gas comes from CoinGecko unless its official documentation and a real no-key response demonstrate otherwise at implementation time. The PublicNode RPC is a candidate, not yet accepted: the implementing agent must verify a real response directly from QML. If it fails, select and document another reputable fixed no-key Ethereum RPC endpoint; do not introduce an API key, proxy, backend, helper process, or downloaded dependency. Do not ship a fabricated or permanently unavailable gas value.

The DefiLlama TVL endpoint returned a valid public response on 2026-08-20. All new external contracts still require the same defensive parsing, jitter, bounded retry, HTTP/rate-limit handling where applicable, no request overlap, independent failure, last-valid-value retention, and stale-after-two-intervals behaviour as Phase 1.

Implementation verification on 2026-08-20 found that the PublicNode candidate did not resolve from the installed system. The fixed no-key fallback `https://eth.drpc.org` returned a real `eth_gasPrice` hexadecimal Wei quantity both in preflight and from QML, so V2 uses dRPC and preserves an independent unavailable/error state on failure.

### V2 implementation sequence

- [x] Record a clean baseline of current tests, validators, live widget state, and the user-owned plugin copy before editing.
- [x] Update `Model.js` for five fixed assets, market caps, explicit 24h/7d changes, ETH dominance, global volume change, TVL parsing/change calculations, Ethereum hexadecimal Wei-to-gwei conversion, curve-state classification, and forced `en-US` formatting.
- [x] Expand focused Node tests for BTC/ETH/SOL/HYPE/ZEC ordering and nulls, compact market caps, exact English/US separators, 24h/7d changes, BTC/ETH dominance, TVL 1d/7d change, stablecoin absolute 7d change, gas conversion, and macro curve states.
- [x] Add `FearGreedGauge.qml` as a compact theme-aware `Canvas` component with no network logic or bundled image assets.
- [x] Remove all sparkline rendering and delete `Sparkline.qml` after confirming it has no remaining references.
- [x] Rebuild `Panel.qml` around the approved compact header, gauge, asset table, and clearly bounded Market, DeFi & Network, Macro, and footer sections.
- [x] Remove the public manual-refresh interaction, middle-click action, cooldown state, and refresh tooltip while preserving automatic scheduling and safe diagnostic IPC only if useful.
- [x] Add the TVL and Ethereum-gas schedulers as independent sources with fixed URLs, initial jitter, no overlap, bounded exponential backoff, last-valid-value retention, and stale handling.
- [x] Verify all public strings and all number/date formatting are English/US, including narrow, large, negative, zero, and sub-dollar values.
- [x] Run live preflight for all sources, especially HYPE/ZEC, TVL, ETH dominance, and the candidate gas RPC, without keys and without storing raw payloads.
- [x] Run unit, manifest, and QML validation; correct real failures before local integration.
- [x] Sync a physical user-owned copy under `~/.config/omarchy/plugins/io.github.guettoblasterr.crypto-market-pulse/`; never use a symlink or edit `/usr/share/omarchy/`.
- [x] Rescan/restart safely, preserve the official clock, keep Crypto Market Pulse enabled in `right`, and verify summon/hide, click/Escape/outside dismissal, automatic updates, partial failure, offline/error, stale values, logo fallback, gauge states, and active-theme contrast.
- [x] Capture and inspect the real compact panel dimensions and information density; do not proceed if it remains close to the Phase 1 footprint.
- [x] Update these V2 checkboxes only after each item is implemented and genuinely verified.

### V2 validation commands

```bash
node --test tests/model.test.js
omarchy plugin validate .
/usr/lib/qt6/bin/qmllint -I /usr/share/omarchy/shell \
  BarWidget.qml Panel.qml FearGreedGauge.qml
git diff --check
git status --short
```

### V2 acceptance gate

- The real panel is materially smaller and denser than Phase 1, with clearly bounded sections and no sparklines.
- The gauge is compact, colored, theme-aware, readable, and accurately maps the published 0–100 Fear & Greed value.
- BTC, ETH, SOL, HYPE, and ZEC each show a logo/fallback, price, compact market cap, 24h change, and 7d change.
- Market shows global cap/change, volume/change, BTC dominance, and ETH dominance.
- DeFi & Network shows TVL, stablecoin net change, DEX activity, open interest, and a real `⛽ ETH Gas` value or an honest independent unavailable/error state.
- Macro shows 2Y, 10Y, daily 10Y basis-point change, 10Y–2Y spread, curve state, and observation date.
- All visible language and number/date formatting are English/US.
- Updates are automatic; no visible/manual refresh control remains.
- One failed source never breaks or empties unrelated sections, and no new key, dependency, backend, proxy, service, helper executable, or privilege requirement exists.
- The user reviews the running V2 widget before Phase 2 begins.

## Iteration V3 — Final visual and data polish

Goal: give the compact V2 dashboard slightly clearer hierarchy and spacing, make Macro easier to scan, and resolve the apparent Perps discrepancy before publication without adding scrolling, credentials, or fragile data sources.

### Approved V3 decisions

- Increase section-heading contrast modestly and add a restrained divider rule derived from the active theme.
- Add only a few pixels of internal section padding and inter-section spacing. The complete widget must remain a single-glance panel with no scrolling.
- Give the Fear & Greed comparison line a minimal extra gap above the next section boundary.
- Keep the compact, unboxed KPI style in Macro, but group the Treasury metrics visually into `Rates` and `Curve`.
- Replace CoinGecko's broad exchange-ticker aggregate with `Hyperliquid Volume (24h)` from Hyperliquid's official, public, no-key Info API. Display the number of aggregated Hyperliquid markets beside the value. This is one explicitly named DEX and must not be presented as DefiLlama's global on-chain derivatives total.
- Do not add an ETF KPI to v1.0 unless a documented, stable, fixed HTTPS source works without an API key. DefiLlama's `/etfs/snapshot` and `/etfs/flows` endpoints and its derivatives-volume endpoint are Pro-only. SoSoValue and SkynetX require credentials. Farside publishes useful public tables but has no documented API contract and returned HTTP 403 to direct local requests; scraping or proxying it would violate the reliability and privacy bar for this plugin.
- Allow enough fitted panel height for the complete two-line source footer; clipping the attribution is not an acceptable way to preserve compactness.
- Label the first asset-table column `COIN` to avoid the adjacent `ASSETS` / `ASSET` repetition, and give the attribution footer slightly more contrast than ordinary secondary copy.
- Keep positive movements on the active Omarchy blue accent, negative movements on the urgent color, and arrows as the primary non-color semantic cue.

### V3 implementation and validation

- [x] Raise section-heading foreground opacity while retaining theme-derived colors.
- [x] Add subtle heading rules and minimally increase section padding and spacing.
- [x] Add a minimal lower gap to the Fear & Greed comparison line.
- [x] Group Macro into `Rates` and `Curve` with a restrained vertical separator.
- [x] Verify the original CoinGecko aggregate, reject the invalid comparison with DefiLlama, and replace it with the official Hyperliquid metric and explicit coverage.
- [x] Verify DefiLlama derivatives and ETF endpoint availability and preserve the no-key product contract.
- [x] Run Node tests, plugin validation, QML linting, and whitespace checks.
- [x] Sync the user-owned installed copy and visually verify dimensions, no-scroll behavior, contrast, long values, and the live Macro/Perps layout.
- [x] Verify the complete source attribution and disclaimer are visible after the final height adjustment.
- [x] Verify Tokyo Night, White, Catppuccin Latte, Vantablack, Flexoki Light, and Osaka Jade; restore Tokyo Night and confirm theme-accent/urgent semantics remain legible with arrows as the stable cue.
- [x] Verify controlled `Partial` / per-source `Unavailable` rendering, restore the real endpoint, and return every source to `Fresh`.
- [x] Verify narrow, large, negative, positive, zero, null, stale, and missing-logo cases through focused tests and bounded/elided table cells.

V3 acceptance gate:

- Section boundaries and headings read clearly without becoming visually dominant.
- Content has slightly more breathing room while remaining compact and fully visible without scrolling.
- Macro communicates the relationship between rates and curve metrics at a glance.
- Perps has accurate, visible Hyperliquid source semantics; no comparison with DefiLlama is implied.
- No ETF value is shipped from an undocumented scraper or credentialed endpoint.
- The user reviews the real running widget before publication begins.

## Phase 2 — Publish and ship

Goal: turn the working slice into a marketplace-ready public repository.

- [x] Apply the approved compact visual hierarchy using Omarchy theme/style primitives.
- [x] Check narrow/long values, missing logos, negative/positive/zero states, stale data, and light/dark theme contrast.
- [x] Consciously omit additional open/update transitions: the approved compact, distraction-free interface takes priority for v1.0.0.
- [x] Write the README: purpose, screenshots, installation, usage, refresh behaviour, network sources, attribution, removal, privacy, troubleshooting, and no-financial-advice notice.
- [x] Add an MIT license and confirm no third-party assets are bundled.
- [x] Capture `preview.png` from the real running plugin.
- [x] Run the complete validation suite and inspect the repository for marketplace security-baseline patterns.
- [ ] Re-authenticate GitHub CLI if `gh auth status` still reports the current token as invalid.
- [x] Create the public GitHub repository `guettoblasterr/omarchy-crypto-pulse`, commit with Conventional Commits, push, and verify installation from the public URL.
- [x] Prepare the marketplace issue with category `Widgets` and tags `bar`, `quickshell`.
- [ ] Show the exact issue title, body, ownership declarations, and checklist to the user.
- [ ] Submit to `HANCORE-linux/omarchy-plugin-marketplace` only after explicit final approval.

Phase 2 acceptance gate:

- A clean install from GitHub works with `omarchy plugin add ... --enable`.
- `omarchy plugin validate` and all local checks pass.
- README, license, preview, attribution, installation, and removal are present at repository root.
- The repository contains exactly one plugin, no symlinks, and no security-review capability such as installers, binaries, services, package managers, `sudo`, or `pkexec`.
- GitHub is public and the marketplace submission is ready for owner approval.

## Validation commands

Exact paths may be adjusted after the files exist, but the gates are fixed:

```bash
node --test tests/model.test.js
omarchy plugin validate .
/usr/lib/qt6/bin/qmllint -I /usr/share/omarchy/shell BarWidget.qml Panel.qml FearGreedGauge.qml
git diff --check
git status --short
```

Local preflight notes:

- Omarchy `4.0.0-1`, Node `v24.19.0`, `omarchy plugin clone`, and `omarchy plugin validate` are available.
- `qmllint` is installed at `/usr/lib/qt6/bin/qmllint` but is not currently exposed on `PATH`; use the absolute path above without installing another package.
- Read first-party references under `/usr/share/omarchy/shell/plugins/` only. Develop in the repository and in the user-owned clone under `~/.config/omarchy/plugins/`; never edit packaged Omarchy files.

Manual checks:

- Widget enable, disable, remove, and clean reinstall.
- Left-click open/close and outside/Escape close.
- Shell restart and hot reload.
- Offline startup, partial API failure, malformed JSON/XML, HTTP 429, and stale timestamps.
- BTC/ETH/SOL image failure fallback.
- Theme contrast and long localized numbers.

## Explicitly out of scope for v1.0

- User-selected watchlists or currencies.
- API-key configuration.
- ETF flows until a stable public no-key JSON source is available.
- VIX, DXY, equities, news, alerts, portfolio tracking, or trading actions.
- Protocol rankings, APY/yield discovery, fees/revenue tables, or large historical charts.
- Persistent raw API response caches.
- A hosted proxy or backend.
- A synthetic buy/sell score.

## Execution rule

Implement one phase, run its checks, and stop for user review. Do not begin the next phase, create the public repository, or submit the marketplace issue without the corresponding approval gate.
