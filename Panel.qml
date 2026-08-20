import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "io.github.guettoblasterr.crypto-market-pulse"
  ipcTarget: moduleName
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root
  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color secondaryForeground: Qt.rgba(contentForeground.r, contentForeground.g, contentForeground.b, 0.68)
  readonly property color footerForeground: Qt.rgba(contentForeground.r, contentForeground.g, contentForeground.b, 0.76)
  readonly property color headingForeground: Qt.rgba(contentForeground.r, contentForeground.g, contentForeground.b, 0.86)
  readonly property color sectionFill: Qt.rgba(contentForeground.r, contentForeground.g, contentForeground.b, 0.045)
  readonly property color sectionBorder: Qt.rgba(contentForeground.r, contentForeground.g, contentForeground.b, 0.18)

  readonly property var sourceDefinitions: ({
    markets: { url: "https://api.coingecko.com/api/v3/coins/markets?vs_currency=usd&ids=bitcoin%2Cethereum%2Csolana%2Chyperliquid%2Czcash&sparkline=false&price_change_percentage=24h%2C7d", interval: 120000, method: "GET" },
    global: { url: "https://api.coingecko.com/api/v3/global", interval: 600000, method: "GET" },
    fearGreed: { url: "https://api.alternative.me/fng/?limit=2", interval: 3600000, method: "GET" },
    tvl: { url: "https://api.llama.fi/v2/historicalChainTvl", interval: 3600000, method: "GET" },
    stablecoins: { url: "https://stablecoins.llama.fi/stablecoincharts/all", interval: 3600000, method: "GET" },
    dex: { url: "https://api.llama.fi/overview/dexs?excludeTotalDataChart=true&excludeTotalDataChartBreakdown=true&dataType=dailyVolume", interval: 3600000, method: "GET" },
    perps: { url: "https://api.hyperliquid.xyz/info", interval: 3600000, method: "POST", body: "{\"type\":\"metaAndAssetCtxs\"}" },
    leverage: { url: "https://api.llama.fi/overview/open-interest?excludeTotalDataChart=true&excludeTotalDataChartBreakdown=true&dataType=openInterestAtEnd", interval: 3600000, method: "GET" },
    // PublicNode was the planned candidate but failed DNS preflight on 2026-08-20.
    // dRPC documents this as its free public Ethereum endpoint; eth_gasPrice was
    // verified with both curl and this QML XMLHttpRequest implementation.
    gas: { url: "https://eth.drpc.org", interval: 30000, method: "POST", body: "{\"jsonrpc\":\"2.0\",\"method\":\"eth_gasPrice\",\"params\":[],\"id\":1}" },
    treasury: { url: "https://home.treasury.gov/sites/default/files/interest-rates/yield.xml", interval: 21600000, method: "GET" }
  })
  readonly property var sourceKeys: ["markets", "global", "fearGreed", "tvl", "stablecoins", "dex", "perps", "leverage", "gas", "treasury"]
  property var states: ({})
  property double clockNow: Date.now()

  readonly property var marketData: dataFor("markets")
  readonly property var btc: coin("BTC")
  readonly property var globalData: dataFor("global")
  readonly property var fearGreedData: dataFor("fearGreed")
  readonly property var tvlData: dataFor("tvl")
  readonly property var stablecoinData: dataFor("stablecoins")
  readonly property var dexData: dataFor("dex")
  readonly property var perpsData: dataFor("perps")
  readonly property var leverageData: dataFor("leverage")
  readonly property var gasData: dataFor("gas")
  readonly property var treasuryData: dataFor("treasury")
  readonly property string overallState: calculateOverallState()

  function openFromHotkey() {
    root.controller.show()
    Qt.callLater(function() {
      if (root.opened && root.bar && "centerHoverRevealSuppressed" in root.bar) root.bar.centerHoverRevealSuppressed = true
    })
  }

  function open() {
    root.controller.show()
    refreshDueSources()
    Qt.callLater(function() { if (root.opened) panelScroll.contentY = 0 })
  }

  function close() {
    if (root.bar && "centerHoverRevealSuppressed" in root.bar) root.bar.centerHoverRevealSuppressed = false
    root.controller.hide()
  }

  function toggle() { root.opened ? root.close() : root.open() }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function") return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function initialize() {
    var now = Date.now()
    var initial = {}
    for (var i = 0; i < sourceKeys.length; i++) {
      var key = sourceKeys[i]
      initial[key] = { data: null, loading: false, error: "", lastSuccess: null, retryCount: 0, nextDue: now + 250 + Math.floor(Math.random() * 2250), request: null }
    }
    states = initial
  }

  function stateFor(key) { return states[key] || null }
  function dataFor(key) { var state = stateFor(key); return state ? state.data : null }

  function updateState(key, changes) {
    var nextStates = {}
    for (var stateKey in states) nextStates[stateKey] = states[stateKey]
    var previous = nextStates[key] || {}
    var next = {}
    for (var field in previous) next[field] = previous[field]
    for (var changed in changes) next[changed] = changes[changed]
    nextStates[key] = next
    states = nextStates
  }

  function coin(symbol) {
    var coins = marketData && marketData.coins ? marketData.coins : []
    for (var i = 0; i < coins.length; i++) if (coins[i].symbol === symbol) return coins[i]
    return null
  }

  function parseSource(key, raw) {
    if (key === "markets") return Model.parseMarkets(raw)
    if (key === "global") return Model.parseGlobal(raw)
    if (key === "fearGreed") return Model.parseFearGreed(raw)
    if (key === "tvl") return Model.parseTvl(raw)
    if (key === "stablecoins") return Model.parseStablecoins(raw)
    if (key === "dex" || key === "leverage") return Model.parseOverview(raw)
    if (key === "perps") return Model.parseHyperliquidPerps(raw)
    if (key === "gas") return Model.parseGas(raw)
    if (key === "treasury") return Model.parseTreasury(raw)
    return null
  }

  function retryDelay(retryCount, retryAfter) {
    if (retryAfter > 0) return Math.min(120000, retryAfter)
    return Math.min(120000, 2000 * Math.pow(2, Math.min(6, retryCount))) + Math.floor(Math.random() * 1000)
  }

  function retryAfterMs(request) {
    var value = ""
    try { value = request.getResponseHeader("Retry-After") || "" } catch (error) { return 0 }
    var seconds = Number(value)
    if (isFinite(seconds) && seconds >= 0) return seconds * 1000
    var date = Date.parse(value)
    return isFinite(date) ? Math.max(0, date - Date.now()) : 0
  }

  function requestSource(key) {
    var definition = sourceDefinitions[key]
    var state = stateFor(key)
    if (!definition || !state || state.loading) return
    var request = new XMLHttpRequest()
    updateState(key, { loading: true, error: "", request: request })
    request.onreadystatechange = function() {
      if (request.readyState !== XMLHttpRequest.DONE) return
      var status = Number(request.status) || 0
      if (status >= 200 && status < 300) {
        var normalized = parseSource(key, request.responseText)
        if (normalized) {
          updateState(key, { data: normalized, loading: false, error: "", lastSuccess: Date.now(), retryCount: 0, nextDue: Date.now() + definition.interval, request: null })
          request = null
          return
        }
      }
      var current = stateFor(key)
      var retry = Math.min(7, (current ? current.retryCount : 0) + 1)
      var message = status === 429 ? "Rate limited" : (status > 0 ? "HTTP " + status : "Network error")
      if (status >= 200 && status < 300) message = "Malformed response"
      updateState(key, { loading: false, error: message, retryCount: retry, nextDue: Date.now() + retryDelay(retry - 1, status === 429 ? retryAfterMs(request) : 0), request: null })
      request = null
    }
    request.open(definition.method, definition.url, true)
    if (definition.method === "POST") request.setRequestHeader("Content-Type", "application/json")
    request.send(definition.body || null)
  }

  function refreshDueSources() {
    var now = Date.now()
    for (var i = 0; i < sourceKeys.length; i++) {
      var key = sourceKeys[i]
      var state = stateFor(key)
      if (state && !state.loading && state.nextDue <= now) requestSource(key)
    }
  }

  function requestDiagnosticRefresh() {
    var now = Date.now()
    for (var i = 0; i < sourceKeys.length; i++) {
      var key = sourceKeys[i]
      var state = stateFor(key)
      if (state && !state.loading) updateState(key, { nextDue: now })
    }
    refreshDueSources()
  }

  function sourceFreshness(key) {
    var state = stateFor(key)
    return Model.freshness(state ? state.lastSuccess : null, sourceDefinitions[key].interval, clockNow)
  }

  function sourceStatus(key) {
    var state = stateFor(key)
    if (!state) return "Waiting"
    if (state.loading && !state.data) return "Loading"
    if (state.error && !state.data) return "Unavailable"
    if (sourceFreshness(key).stale) return "Stale"
    if (state.error) return "Retrying"
    if (state.loading) return "Updating"
    return state.data ? "Fresh" : "Waiting"
  }

  function sourceProblem(key) {
    var status = sourceStatus(key)
    return status === "Unavailable" || status === "Retrying" || status === "Stale" ? status : ""
  }

  function issueFor(keys) {
    var issues = []
    for (var i = 0; i < keys.length; i++) {
      var problem = sourceProblem(keys[i])
      if (problem) issues.push(keys[i] === "fearGreed" ? problem : keys[i].toUpperCase() + " " + problem.toLowerCase())
    }
    return issues.join(" · ")
  }

  function calculateOverallState() {
    var valid = 0
    var loading = 0
    var errors = 0
    var stale = 0
    for (var i = 0; i < sourceKeys.length; i++) {
      var state = stateFor(sourceKeys[i])
      if (!state) continue
      if (state.data) valid++
      if (state.loading) loading++
      if (state.error) errors++
      if (sourceFreshness(sourceKeys[i]).stale) stale++
    }
    if (valid === 0 && errors > 0) return "Offline"
    if (valid === 0 && loading > 0) return "Loading"
    if (valid < sourceKeys.length || errors > 0) return "Partial"
    if (stale > 0) return "Stale"
    return "Fresh"
  }

  function sourceSummary() {
    var summary = {}
    for (var i = 0; i < sourceKeys.length; i++) summary[sourceKeys[i]] = sourceStatus(sourceKeys[i])
    return summary
  }

  function panelDimensions() {
    return { width: panel.contentWidth, height: panel.contentHeight, contentHeight: contentColumn.implicitHeight }
  }

  function semanticText(value) {
    var movement = Model.direction(value)
    return movement.arrow + " " + Model.formatPercent(value, 1)
  }

  function semanticColor(value) {
    var movement = Model.direction(value)
    return movement.sign < 0 ? Color.urgent : (movement.sign > 0 ? Color.accent : contentForeground)
  }

  function basisPointText(value, directional) {
    var number = Model.finiteNumber(value)
    if (number === null) return "—"
    return (directional ? Model.direction(number).arrow + " " : "") + Math.abs(number).toFixed(1) + " bp"
  }

  component PulseText: Text {
    color: root.contentForeground
    font.family: root.contentFontFamily
    font.pixelSize: Style.font.bodySmall
    renderType: Text.NativeRendering
  }

  component SmallText: PulseText {
    font.pixelSize: Style.font.caption
  }

  component SectionHeading: Row {
    id: sectionHeading
    property string title: ""
    property var sources: []
    width: parent ? parent.width : 0
    height: Style.space(15)
    spacing: Style.space(5)

    SmallText { id: headingTitle; text: sectionHeading.title; font.bold: true; font.letterSpacing: 0.8; color: root.headingForeground }
    Rectangle {
      width: Math.max(0, sectionHeading.width - headingTitle.implicitWidth - headingProblem.implicitWidth - sectionHeading.spacing * 2)
      height: 1
      anchors.verticalCenter: parent.verticalCenter
      color: root.sectionBorder
    }
    SmallText {
      id: headingProblem
      text: root.issueFor(sectionHeading.sources)
      visible: text !== ""
      color: text.indexOf("unavailable") >= 0 ? Color.urgent : root.secondaryForeground
    }
  }

  component Metric: Column {
    id: metric
    property string label: ""
    property string value: "—"
    property string detail: ""
    property color detailColor: root.secondaryForeground
    spacing: 0
    SmallText { text: metric.label; color: root.secondaryForeground }
    PulseText { text: metric.value; font.bold: true }
    SmallText { text: metric.detail; color: metric.detailColor; visible: text !== "" }
  }

  component KpiCard: Rectangle {
    id: kpiCard
    property string label: ""
    property string value: "—"
    property string detail: ""
    property color detailColor: root.secondaryForeground
    height: Style.space(40)
    clip: true
    radius: Style.space(4)
    color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.035)
    border.color: root.sectionBorder
    border.width: 1

    Column {
      anchors.left: parent.left
      anchors.leftMargin: Style.space(5)
      anchors.right: parent.right
      anchors.rightMargin: Style.space(5)
      anchors.verticalCenter: parent.verticalCenter
      spacing: 0
      SmallText { width: parent.width; text: kpiCard.label; color: root.secondaryForeground; elide: Text.ElideRight }
      Row {
        width: parent.width
        PulseText { text: kpiCard.value; font.bold: true }
        Item { width: Math.max(0, parent.width - parent.children[0].implicitWidth - parent.children[2].implicitWidth); height: 1 }
        SmallText { text: kpiCard.detail; color: kpiCard.detailColor; visible: text !== "" }
      }
    }
  }

  Timer {
    interval: 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      root.clockNow = Date.now()
      root.refreshDueSources()
    }
  }

  Component.onCompleted: initialize()

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: true
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(460))
    contentHeight: panel.fittedContentHeight(contentColumn.implicitHeight, Style.space(640))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Flickable {
        id: panelScroll
        anchors.fill: parent
        contentWidth: width
        contentHeight: contentColumn.implicitHeight
        clip: true
        interactive: false
        boundsBehavior: Flickable.StopAtBounds

        Column {
          id: contentColumn
          width: parent.width
          spacing: Style.space(4)

          Row {
            width: parent.width
            height: Style.space(22)
            PulseText { text: "Crypto Market Pulse"; font.pixelSize: Style.font.heading; font.bold: true }
            Item { width: Math.max(0, parent.width - parent.children[0].implicitWidth - parent.children[2].implicitWidth); height: 1 }
            SmallText {
              visible: root.overallState === "Partial" || root.overallState === "Stale" || root.overallState === "Offline"
              text: root.overallState
              color: root.overallState === "Offline" ? Color.urgent : root.secondaryForeground
              anchors.verticalCenter: parent.verticalCenter
            }
          }

          Rectangle {
            width: parent.width
            height: Style.space(84)
            radius: Style.space(6)
            color: root.sectionFill
            border.color: root.sectionBorder
            border.width: 1

            FearGreedGauge {
              width: Style.space(190)
              height: Style.space(80)
              anchors.left: parent.left
              anchors.leftMargin: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
              anchors.verticalCenterOffset: -Style.space(1)
              value: root.fearGreedData ? root.fearGreedData.value : null
              classification: root.fearGreedData ? root.fearGreedData.classification : "Unavailable"
              change: root.fearGreedData ? root.fearGreedData.change : null
              foreground: root.contentForeground
              muted: root.secondaryForeground
              fontFamily: root.contentFontFamily
            }

            Column {
              anchors.left: parent.left
              anchors.leftMargin: Style.space(218)
              anchors.right: parent.right
              anchors.rightMargin: Style.space(10)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(3)
              PulseText { text: "Fear & Greed"; font.bold: true }
              SmallText { text: "Alternative.me"; color: root.secondaryForeground }
              SmallText {
                text: root.sourceProblem("fearGreed")
                visible: text !== ""
                color: text === "Unavailable" ? Color.urgent : root.secondaryForeground
              }
            }
          }

          Rectangle {
            width: parent.width
            height: assetsColumn.implicitHeight + Style.space(8)
            radius: Style.space(6)
            color: root.sectionFill
            border.color: root.sectionBorder
            border.width: 1

            Column {
              id: assetsColumn
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.margins: Style.space(5)
              anchors.verticalCenter: parent.verticalCenter
              spacing: 0

              SectionHeading { title: "ASSETS"; sources: ["markets"] }
              Row {
                width: parent.width
                height: Style.space(13)
                SmallText { width: parent.width * 0.18; text: "COIN"; color: root.secondaryForeground }
                SmallText { width: parent.width * 0.25; text: "PRICE"; horizontalAlignment: Text.AlignRight; color: root.secondaryForeground }
                SmallText { width: parent.width * 0.20; text: "CAP"; horizontalAlignment: Text.AlignRight; color: root.secondaryForeground }
                SmallText { width: parent.width * 0.185; text: "24H"; horizontalAlignment: Text.AlignRight; color: root.secondaryForeground }
                SmallText { width: parent.width * 0.185; text: "7D"; horizontalAlignment: Text.AlignRight; color: root.secondaryForeground }
              }
              Repeater {
                model: root.marketData && root.marketData.coins ? root.marketData.coins : Model.ASSET_ORDER
                delegate: Row {
                  id: assetRow
                  required property var modelData
                  readonly property bool loaded: typeof modelData === "object"
                  readonly property string symbol: loaded ? modelData.symbol : String(modelData)
                  width: assetsColumn.width
                  height: Style.space(19)

                  Item {
                    width: parent.width * 0.18
                    height: parent.height
                    Image {
                      id: assetLogo
                      width: Style.space(16)
                      height: Style.space(16)
                      anchors.left: parent.left
                      anchors.verticalCenter: parent.verticalCenter
                      source: assetRow.loaded ? assetRow.modelData.image : ""
                      asynchronous: true
                      fillMode: Image.PreserveAspectFit
                    }
                    SmallText {
                      anchors.centerIn: assetLogo
                      visible: assetLogo.status !== Image.Ready
                      text: assetRow.symbol.charAt(0)
                      font.bold: true
                    }
                    PulseText { anchors.left: assetLogo.right; anchors.leftMargin: Style.space(5); anchors.verticalCenter: parent.verticalCenter; text: assetRow.symbol; font.bold: true }
                  }
                  PulseText { width: assetRow.width * 0.25; anchors.verticalCenter: parent.verticalCenter; text: assetRow.loaded ? Model.formatPrice(assetRow.modelData.price) : "—"; horizontalAlignment: Text.AlignRight; elide: Text.ElideRight }
                  SmallText { width: assetRow.width * 0.20; anchors.verticalCenter: parent.verticalCenter; text: assetRow.loaded ? Model.formatCompact(assetRow.modelData.marketCap, true) : "—"; horizontalAlignment: Text.AlignRight; elide: Text.ElideRight }
                  SmallText { width: assetRow.width * 0.185; anchors.verticalCenter: parent.verticalCenter; text: assetRow.loaded ? root.semanticText(assetRow.modelData.change24h) : "—"; horizontalAlignment: Text.AlignRight; elide: Text.ElideRight; color: assetRow.loaded ? root.semanticColor(assetRow.modelData.change24h) : root.secondaryForeground }
                  SmallText { width: assetRow.width * 0.185; anchors.verticalCenter: parent.verticalCenter; text: assetRow.loaded ? root.semanticText(assetRow.modelData.change7d) : "—"; horizontalAlignment: Text.AlignRight; elide: Text.ElideRight; color: assetRow.loaded ? root.semanticColor(assetRow.modelData.change7d) : root.secondaryForeground }
                }
              }
            }
          }

          Rectangle {
            width: parent.width
            height: marketColumn.implicitHeight + Style.space(8)
            radius: Style.space(6)
            color: root.sectionFill
            border.color: root.sectionBorder
            border.width: 1
            Column {
              id: marketColumn
              anchors.left: parent.left; anchors.right: parent.right; anchors.margins: Style.space(6); anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(3)
              SectionHeading { title: "MARKET"; sources: ["global"] }
              Row {
                width: parent.width
                Metric { width: parent.width * 0.29; label: "Market cap"; value: root.globalData ? Model.formatCompact(root.globalData.marketCap, true) : "—"; detail: root.globalData ? root.semanticText(root.globalData.change24h) : ""; detailColor: root.semanticColor(root.globalData ? root.globalData.change24h : null) }
                Metric { width: parent.width * 0.29; label: "24h volume"; value: root.globalData ? Model.formatCompact(root.globalData.volume24h, true) : "—"; detail: root.globalData && root.globalData.volumeChange24h !== null ? root.semanticText(root.globalData.volumeChange24h) : ""; detailColor: root.semanticColor(root.globalData ? root.globalData.volumeChange24h : null) }
                Metric { width: parent.width * 0.21; label: "BTC dom."; value: root.globalData ? Model.formatPercent(root.globalData.btcDominance, 1) : "—" }
                Metric { width: parent.width * 0.21; label: "ETH dom."; value: root.globalData ? Model.formatPercent(root.globalData.ethDominance, 1) : "—" }
              }
            }
          }

          Rectangle {
            width: parent.width
            height: defiColumn.implicitHeight + Style.space(8)
            radius: Style.space(6)
            color: root.sectionFill
            border.color: root.sectionBorder
            border.width: 1
            Column {
              id: defiColumn
              anchors.left: parent.left; anchors.right: parent.right; anchors.margins: Style.space(6); anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(4)
              SectionHeading { title: "DEFI & NETWORK"; sources: ["tvl", "stablecoins", "dex", "perps", "leverage", "gas"] }
              Row {
                width: parent.width
                spacing: Style.space(3)
                KpiCard { width: (parent.width - parent.spacing) / 2; label: "DeFi TVL"; value: root.tvlData ? Model.formatCompact(root.tvlData.total, true) : "—"; detail: root.tvlData ? "1d " + root.semanticText(root.tvlData.change1d) + " · 7d " + root.semanticText(root.tvlData.change7d) : ""; detailColor: root.secondaryForeground }
                KpiCard { width: (parent.width - parent.spacing) / 2; label: "Stablecoin Market Cap"; value: root.stablecoinData ? Model.formatCompact(root.stablecoinData.total, true) : "—"; detail: root.stablecoinData ? "7d net " + Model.formatSignedCompact(root.stablecoinData.netChange7d) : ""; detailColor: root.semanticColor(root.stablecoinData ? root.stablecoinData.netChange7d : null) }
              }
              Row {
                width: parent.width
                spacing: Style.space(3)
                KpiCard { width: (parent.width - parent.spacing) / 2; label: "DEX Volume (24h)"; value: root.dexData ? Model.formatCompact(root.dexData.total, true) : "—"; detail: root.dexData ? "24h " + root.semanticText(root.dexData.change) : ""; detailColor: root.semanticColor(root.dexData ? root.dexData.change : null) }
                KpiCard {
                  width: (parent.width - parent.spacing) / 2
                  label: "Hyperliquid Volume (24h)"
                  value: root.perpsData ? Model.formatCompact(root.perpsData.total, true) : "—"
                  detail: root.sourceProblem("perps") || (root.perpsData ? Model.formatCompact(root.perpsData.markets, false) + " markets" : "")
                  detailColor: root.sourceProblem("perps") === "Unavailable" ? Color.urgent : root.secondaryForeground
                }
              }
              Row {
                width: parent.width
                spacing: Style.space(3)
                KpiCard { width: (parent.width - parent.spacing) / 2; label: "Open Interest"; value: root.leverageData ? Model.formatCompact(root.leverageData.total, true) : "—"; detail: root.leverageData ? "24h " + root.semanticText(root.leverageData.change) : ""; detailColor: root.semanticColor(root.leverageData ? root.leverageData.change : null) }
                KpiCard { width: (parent.width - parent.spacing) / 2; label: "⛽ ETH Gas"; value: root.gasData ? Model.formatGas(root.gasData.gwei) : "Unavailable"; detail: root.sourceProblem("gas"); detailColor: root.sourceProblem("gas") === "Unavailable" ? Color.urgent : root.secondaryForeground }
              }
            }
          }

          Rectangle {
            width: parent.width
            height: macroColumn.implicitHeight + Style.space(8)
            radius: Style.space(6)
            color: root.sectionFill
            border.color: root.sectionBorder
            border.width: 1
            Column {
              id: macroColumn
              anchors.left: parent.left; anchors.right: parent.right; anchors.margins: Style.space(6); anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(3)
              SectionHeading { title: "MACRO"; sources: ["treasury"] }
              Row {
                width: parent.width
                height: Style.space(42)

                Column {
                  width: (parent.width - macroDivider.width - Style.space(10)) / 2
                  spacing: Style.space(1)
                  SmallText { text: "RATES"; font.bold: true; font.letterSpacing: 0.6; color: root.headingForeground }
                  Row {
                    width: parent.width
                    Metric { width: parent.width / 2; label: "U.S. 2-year"; value: root.treasuryData ? root.treasuryData.twoYear.toFixed(2) + "%" : "—" }
                    Column {
                      width: parent.width / 2
                      spacing: 0
                      SmallText { text: "U.S. 10-year"; color: root.secondaryForeground }
                      Row {
                        spacing: Style.space(3)
                        PulseText { text: root.treasuryData ? root.treasuryData.tenYear.toFixed(2) + "%" : "—"; font.bold: true }
                        SmallText { anchors.verticalCenter: parent.verticalCenter; text: root.treasuryData ? root.basisPointText(root.treasuryData.tenYearChangeBps, true) : ""; color: root.semanticColor(root.treasuryData ? root.treasuryData.tenYearChangeBps : null) }
                      }
                    }
                  }
                }

                Item { width: Style.space(5); height: 1 }
                Rectangle { id: macroDivider; width: 1; height: parent.height; color: root.sectionBorder }
                Item { width: Style.space(5); height: 1 }

                Column {
                  width: (parent.width - macroDivider.width - Style.space(10)) / 2
                  spacing: Style.space(1)
                  SmallText { text: "CURVE"; font.bold: true; font.letterSpacing: 0.6; color: root.headingForeground }
                  Row {
                    width: parent.width
                    Metric { width: parent.width / 2; label: "10Y–2Y spread"; value: root.treasuryData ? root.basisPointText(root.treasuryData.spreadBps, false) : "—" }
                    Metric { width: parent.width / 2; label: "State"; value: root.treasuryData ? root.treasuryData.curveState : "—" }
                  }
                }
              }
              SmallText { text: root.treasuryData ? "Observation: " + Model.formatDateUS(root.treasuryData.dateTimestamp) + " · Flat = within ±5 bp" : ""; color: root.secondaryForeground }
            }
          }

          Column {
            width: parent.width
            spacing: 0
            SmallText { width: parent.width; text: "Sources: CoinGecko · DefiLlama · Hyperliquid · Alternative.me"; color: root.footerForeground; horizontalAlignment: Text.AlignHCenter }
            SmallText { width: parent.width; text: "dRPC · U.S. Treasury · Not financial advice"; color: root.footerForeground; horizontalAlignment: Text.AlignHCenter }
          }
        }
      }
    }
  }
}
