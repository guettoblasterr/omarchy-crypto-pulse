import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

BarWidget {
  id: root
  moduleName: "io.github.guettoblasterr.crypto-market-pulse"

  readonly property var btc: panelLoader.item ? panelLoader.item.btc : null
  readonly property var btcDirection: Model.direction(btc ? btc.change24h : null)
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false
  readonly property real openPanelIndicatorWidth: button.width
  readonly property real openPanelIndicatorHeight: Math.max(Style.space(10), Math.round(Style.bar.iconSlot * 0.55))

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  function open() { if (panelLoader.item) panelLoader.item.openFromHotkey() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function togglePanel() { if (panelLoader.item) panelLoader.item.toggle() }
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }
  function refresh() { if (panelLoader.item) panelLoader.item.requestDiagnosticRefresh() }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  IpcHandler {
    target: root.moduleName
    function refresh(): void { root.refresh() }
    function state(): string {
      return JSON.stringify({
        opened: root.opened,
        overall: panelLoader.item ? panelLoader.item.overallState : "Unavailable",
        sources: panelLoader.item ? panelLoader.item.sourceSummary() : {},
        dimensions: panelLoader.item ? panelLoader.item.panelDimensions() : {},
        gas: panelLoader.item && panelLoader.item.gasData ? panelLoader.item.gasData.gwei : null
      })
    }
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.togglePanel() }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""
    labelVisible: false
    hasVisualContent: true
    fixedWidth: pulseRow.implicitWidth + Style.space(17)
    tooltipText: "Crypto Market Pulse"

    onPressed: function(mouseButton) {
      if (mouseButton === Qt.LeftButton) root.togglePanel()
    }

    Row {
      id: pulseRow
      anchors.centerIn: parent
      spacing: Style.space(5)

      Item {
        width: Style.space(17)
        height: Style.space(17)

        Image {
          id: btcLogo
          anchors.fill: parent
          source: Qt.resolvedUrl(Model.assetLogo("BTC"))
          sourceSize: Qt.size(width, height)
          fillMode: Image.PreserveAspectFit
        }

        Text {
          anchors.centerIn: parent
          visible: btcLogo.status !== Image.Ready
          text: "₿"
          color: button.foreground
          font.family: button.fontFamily
          font.pixelSize: Style.font.icon
        }
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: root.btc ? Model.formatCompact(root.btc.price, true) : "Loading…"
        color: button.foreground
        font.family: button.fontFamily
        font.pixelSize: Style.font.body
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        visible: !!root.btc
        text: root.btcDirection.arrow + " " + Model.formatPercent(root.btc ? root.btc.change24h : null, 1)
        color: root.btcDirection.sign < 0 ? Color.urgent : (root.btcDirection.sign > 0 ? Color.accent : button.foreground)
        font.family: button.fontFamily
        font.pixelSize: Style.font.bodySmall
      }
    }
  }
}
