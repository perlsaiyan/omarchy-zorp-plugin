import QtQuick
import qs.Commons
import qs.Ui

// The bar slot: an envelope and an unread count. Drawn rather than shipped as
// an asset so it takes the bar's foreground colour and follows the theme.
//
// Left click opens zorp (the thing you nearly always want from a mail icon),
// hover shows the newest mail, right click pins that list open, and middle
// click re-reads the cache.
BarWidget {
  id: root
  moduleName: "zorp.mail"

  readonly property bool hoverToOpen: {
    var v = root.settings ? root.settings.hoverToOpen : undefined
    return v === undefined ? true : v === true
  }
  readonly property int hoverDelayMs: {
    var v = root.settings ? root.settings.hoverDelayMs : undefined
    return v === undefined ? 220 : Number(v)
  }

  // The record lives in the panel, which polls even while closed, so the
  // badge is already right when you glance at it.
  readonly property int unread: panelLoader.item ? panelLoader.item.unread : 0
  readonly property bool faulted: panelLoader.item ? panelLoader.item.errorText !== "" : false

  // Same hover contract as the ESPN widget: hover opens it, the pointer being
  // over icon *or* card keeps it open, and pinning holds it until unpinned.
  property bool pinned: false
  readonly property bool panelHovered: panelLoader.item ? panelLoader.item.contentHovered === true : false
  readonly property bool anyHovered: button.tooltipHovered || countHover.hovered || panelHovered

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  function refresh() {
    if (panelLoader.item && panelLoader.item.refresh) panelLoader.item.refresh()
  }

  function openZorp() {
    if (panelLoader.item) panelLoader.item.openZorp()
  }

  function togglePanel() {
    if (!panelLoader.item) return
    if (root.opened && root.pinned) {
      root.pinned = false
      panelLoader.item.close()
    } else {
      root.pinned = true
      panelLoader.item.openFromHotkey()
    }
  }

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function open() {
    if (panelLoader.item && panelLoader.item.openFromHotkey) panelLoader.item.openFromHotkey()
  }

  function close() {
    root.pinned = false
    if (panelLoader.item && panelLoader.item.close) panelLoader.item.close()
  }

  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false
  function closeForPopoutSwitch() {
    root.pinned = false
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  function press(b) {
    if (!root.bar) return
    if (b === Qt.RightButton) root.togglePanel()
    else if (b === Qt.MiddleButton) root.refresh()
    else { root.close(); root.openZorp() }
  }

  // The count sits beside the envelope rather than on it: a badge big enough
  // to read at bar size covers the whole icon. A vertical bar has no room
  // beside anything, so there the count is left to the card.
  readonly property bool showCount: root.unread > 0 && !root.faulted && !button.vertical

  implicitWidth: button.implicitWidth + (root.showCount ? countLabel.implicitWidth + Style.space(4) : 0)
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  onAnyHoveredChanged: {
    if (!root.hoverToOpen) return
    if (root.anyHovered) {
      closeTimer.stop()
      if (!root.opened) openTimer.restart()
    } else {
      openTimer.stop()
      if (root.opened && !root.pinned) closeTimer.restart()
    }
  }

  Timer {
    id: openTimer
    interval: root.hoverDelayMs
    onTriggered: {
      if (root.anyHovered && panelLoader.item) panelLoader.item.open()
    }
  }

  // Long enough to cross the gap between the icon and the card.
  Timer {
    id: closeTimer
    interval: 400
    onTriggered: {
      if (!root.anyHovered && !root.pinned && panelLoader.item) panelLoader.item.close()
    }
  }

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

  BarIconButton {
    id: button
    anchors.left: parent.left
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    bar: root.bar
    text: ""
    slotSize: Style.bar.statusSlot
    tooltipText: ""

    iconComponent: Component {
      Canvas {
        id: envelope
        implicitWidth: Style.bar.iconCanvas
        implicitHeight: Style.bar.iconCanvas
        // A broken feed reads as urgent rather than as a calm empty inbox.
        readonly property color ink: root.faulted
          ? (root.bar ? root.bar.urgent : Color.urgent)
          : (root.bar ? root.bar.foreground : Color.foreground)
        onInkChanged: requestPaint()
        onPaint: {
          var ctx = getContext("2d")
          ctx.reset()
          var w = width, h = height
          var bw = w * 0.86, bh = h * 0.62
          var x = (w - bw) / 2, y = (h - bh) / 2
          var r = Math.max(1, w * 0.08)

          // Solid body, like the football: outlined, an envelope at bar size
          // is a box with a scribble in it.
          ctx.beginPath()
          ctx.moveTo(x + r, y)
          ctx.lineTo(x + bw - r, y)
          ctx.quadraticCurveTo(x + bw, y, x + bw, y + r)
          ctx.lineTo(x + bw, y + bh - r)
          ctx.quadraticCurveTo(x + bw, y + bh, x + bw - r, y + bh)
          ctx.lineTo(x + r, y + bh)
          ctx.quadraticCurveTo(x, y + bh, x, y + bh - r)
          ctx.lineTo(x, y + r)
          ctx.quadraticCurveTo(x, y, x + r, y)
          ctx.closePath()
          ctx.fillStyle = envelope.ink
          ctx.fill()

          // The flap is erased rather than painted, so it reads as a gap on
          // any theme background without knowing what colour that is.
          ctx.globalCompositeOperation = "destination-out"
          ctx.lineWidth = Math.max(1, Math.round(w * 0.08))
          ctx.lineJoin = "round"
          ctx.beginPath()
          ctx.moveTo(x + bw * 0.12, y + bh * 0.2)
          ctx.lineTo(x + bw / 2, y + bh * 0.58)
          ctx.lineTo(x + bw * 0.88, y + bh * 0.2)
          ctx.stroke()
          ctx.globalCompositeOperation = "source-over"
        }
      }
    }

    onPressed: function(b) { root.press(b) }
  }

  // Hidden at zero: an inbox you have read needs no number beside it.
  Text {
    id: countLabel
    visible: root.showCount
    anchors.left: button.right
    anchors.leftMargin: -Style.space(2)
    anchors.verticalCenter: button.verticalCenter
    text: root.unread > 999 ? "999+" : String(root.unread)
    color: Color.accent
    font.family: root.bar ? root.bar.fontFamily : Style.font.family
    font.pixelSize: Style.space(12)
    font.weight: Font.DemiBold

    HoverHandler { id: countHover }
    TapHandler {
      acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
      onTapped: function(eventPoint, button) { root.press(button) }
    }
  }
}
