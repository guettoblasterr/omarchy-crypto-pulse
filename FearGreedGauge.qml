import QtQuick
import qs.Commons

Item {
  id: root

  property var value: null
  property string classification: "Unavailable"
  property var change: null
  property color foreground: Color.foreground
  property color muted: Color.muted
  property color trackColor: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.10)
  property string fontFamily: Style.font.family

  readonly property real boundedValue: {
    var number = Number(value)
    return value === null || !isFinite(number) ? -1 : Math.max(0, Math.min(100, number))
  }
  readonly property real needleAngle: Math.PI + (boundedValue < 0 ? 0.5 : boundedValue / 100) * Math.PI

  function changeLabel() {
    var number = Number(root.change)
    if (root.change === null || !isFinite(number)) return "Yesterday —"
    if (number === 0) return "Yesterday → 0"
    return "Yesterday " + (number > 0 ? "▲ +" : "▼ ") + number.toFixed(0)
  }

  implicitWidth: Style.space(176)
  implicitHeight: Style.space(80)

  onBoundedValueChanged: gauge.requestPaint()
  onTrackColorChanged: gauge.requestPaint()
  onWidthChanged: gauge.requestPaint()
  onHeightChanged: gauge.requestPaint()

  Canvas {
    id: gauge
    anchors.top: parent.top
    anchors.horizontalCenter: parent.horizontalCenter
    width: parent.width
    height: Style.space(52)

    onPaint: {
      var context = getContext("2d")
      context.clearRect(0, 0, width, height)
      var centerX = width / 2
      var centerY = height - Style.space(5)
      var radius = Math.max(10, Math.min(width / 2 - Style.space(8), height - Style.space(12)))
      var line = Math.max(5, Style.spaceReal(7))
      context.lineWidth = line
      context.lineCap = "butt"

      context.beginPath()
      context.strokeStyle = root.trackColor
      context.arc(centerX, centerY, radius, Math.PI, Math.PI * 2, false)
      context.stroke()

      var colors = ["#e05252", "#e8913a", "#d6b83c", "#4fa86a"]
      var gap = 0.018
      for (var i = 0; i < colors.length; i++) {
        context.beginPath()
        context.strokeStyle = colors[i]
        context.arc(centerX, centerY, radius, Math.PI + Math.PI * i / 4 + gap, Math.PI + Math.PI * (i + 1) / 4 - gap, false)
        context.stroke()
      }

      if (root.boundedValue >= 0) {
        var angle = root.needleAngle
        var needleLength = radius - line
        context.beginPath()
        context.moveTo(centerX, centerY)
        context.lineTo(centerX + Math.cos(angle) * needleLength, centerY + Math.sin(angle) * needleLength)
        context.lineWidth = Math.max(1.5, Style.spaceReal(2))
        context.lineCap = "round"
        context.strokeStyle = root.foreground
        context.stroke()
        context.beginPath()
        context.fillStyle = root.foreground
        context.arc(centerX, centerY, Math.max(2.5, Style.spaceReal(3)), 0, Math.PI * 2, false)
        context.fill()
      }
    }
  }

  Text {
    anchors.horizontalCenter: parent.horizontalCenter
    y: Style.space(24)
    text: root.boundedValue < 0 ? "—" : String(Math.round(root.boundedValue))
    color: root.foreground
    font.family: root.fontFamily
    font.pixelSize: Style.font.heading
    font.bold: true
    renderType: Text.NativeRendering
  }

  Column {
    anchors.top: gauge.bottom
    anchors.topMargin: Style.space(1)
    anchors.horizontalCenter: parent.horizontalCenter
    spacing: 0

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: root.classification
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      font.bold: true
      renderType: Text.NativeRendering
    }
    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: root.changeLabel()
      color: root.muted
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      renderType: Text.NativeRendering
    }
  }
}
