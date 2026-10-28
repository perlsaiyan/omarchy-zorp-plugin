import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Pure display. Everything shown here was put on disk by bin/omarchy-zorp-update;
// this file reads that record, watches it for changes, and draws it.
Panel {
  id: root
  moduleName: "zorp.mail"
  ipcTarget: "zorp.mail"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property bool pinned: hostWidget ? hostWidget.pinned === true : false
  readonly property bool contentHovered: card.containsMouse

  readonly property string pluginDir: Qt.resolvedUrl(".").toString().replace("file://", "")
  readonly property int refreshIntervalSec: {
    var v = root.settings ? root.settings.refreshIntervalSec : undefined
    return v === undefined ? 15 : Math.max(5, Number(v))
  }

  property var record: ({})
  readonly property var messages: record && record.messages ? record.messages : []
  readonly property var folders: record && record.folders ? record.folders : []
  readonly property int unread: record && record.unread ? Number(record.unread) : 0
  readonly property string errorText: record && record.error ? String(record.error) : ""
  readonly property string daemonState: record && record.daemon ? String(record.daemon.state || "") : ""
  property double nowMs: Date.now()

  function open() { root.controller.show(); root.refresh() }
  function openFromHotkey() { root.controller.show(); root.refresh() }
  function close() { root.controller.hide() }
  function toggle() { root.opened ? root.close() : root.open() }

  function refresh() { if (!updateProc.running) updateProc.running = true }

  // zorp-focus raises the open zorp window, or starts one floating in Ghostty
  // (the window rules hang off its class). There is no way to point zorp at a
  // particular message from outside yet, so every row lands here.
  function openZorp() {
    Util.execArgv(["zorp-focus"])
    if (root.hostWidget) root.hostWidget.close()
  }

  function folderSummary() {
    if (root.folders.length === 0) return ""
    if (root.folders.length === 1) return root.folders[0].name
    var parts = []
    for (var i = 0; i < root.folders.length; i++)
      parts.push(root.folders[i].name + " " + root.folders[i].unread)
    return parts.join(" · ")
  }

  // A sync that has stopped is worth saying out loud; one that is merely
  // running is not.
  function daemonNote() {
    switch (root.daemonState) {
      case "idle": case "syncing": case "starting": return ""
      case "offline": return "offline, retrying"
      case "stopped": return "daemon not running"
      case "": return ""
      default: return root.daemonState.replace("_", " ")
    }
  }

  // Mail-client time: minutes and hours today, the weekday this week, the
  // date after that.
  function when(unixSec) {
    var t = Number(unixSec) * 1000
    if (!t) return ""
    var s = Math.max(0, Math.round((root.nowMs - t) / 1000))
    if (s < 60) return "now"
    if (s < 3600) return Math.floor(s / 60) + "m"
    var d = new Date(t)
    if (s < 86400 && d.getDate() === new Date(root.nowMs).getDate()) return Math.floor(s / 3600) + "h"
    if (s < 6 * 86400) return Qt.formatDate(d, "ddd")
    return Qt.formatDate(d, "MMM d")
  }

  function ago(iso) {
    if (!iso) return ""
    var t = Date.parse(iso)
    if (isNaN(t)) return ""
    var s = Math.max(0, Math.round((root.nowMs - t) / 1000))
    if (s < 60) return "updated " + s + "s ago"
    return "updated " + Math.floor(s / 60) + "m ago"
  }

  // zorp's own message-list markers, so the two read the same.
  function markers(m) {
    var out = ""
    if (m.important) out += "!"
    if (m.flagged) out += "*"
    if (m.attachments) out += "+"
    return out
  }

  FileView {
    id: stateFile
    path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/omarchy/zorp/mail.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      try { root.record = JSON.parse(text()) }
      catch (e) { root.record = { error: "unreadable state file" } }
    }
    onLoadFailed: root.record = { error: "no data yet — run bin/omarchy-zorp-update" }
  }

  Process {
    id: updateProc
    running: false
    command: [root.pluginDir + "bin/omarchy-zorp-update"]
    // The collector writes the state file; the FileView watch repaints.
  }

  // Poll while the card is closed too: the badge is the point.
  Timer {
    interval: root.refreshIntervalSec * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Timer {
    interval: 1000
    running: root.opened
    repeat: true
    onTriggered: root.nowMs = Date.now()
  }

  PopupCard {
    id: card
    anchorItem: root.anchorItem
    bar: root.bar
    owner: root.barIdentity
    open: root.opened
    triggerMode: root.pinned ? "click" : "hover"
    contentWidth: card.fittedContentWidth(Style.space(460))
    contentHeight: card.fittedContentHeight(body.implicitHeight, Style.space(640))

    Column {
      id: body
      width: parent.width
      spacing: Style.space(8)

      // ============================================================== header
      Item {
        width: parent.width
        implicitHeight: titleCol.implicitHeight

        Column {
          id: titleCol
          anchors.left: parent.left
          spacing: Style.space(2)

          Text {
            text: root.unread > 0 ? (root.unread + " unread") : "No unread mail"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.space(15)
            font.weight: Font.DemiBold
          }
          Text {
            text: {
              var bits = []
              if (root.record && root.record.account) bits.push(root.record.account.upn)
              var f = root.folderSummary()
              if (f) bits.push(f)
              return bits.join(" · ")
            }
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.space(11)
            elide: Text.ElideRight
            width: Math.min(implicitWidth, body.width - Style.space(110))
          }
        }

        Text {
          anchors.right: parent.right
          anchors.top: parent.top
          text: root.daemonNote() || (root.record && root.record.updatedAt ? root.ago(root.record.updatedAt) : "")
          color: root.daemonNote() ? root.urgent : root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.space(11)
        }
      }

      PanelSeparator { width: parent.width }

      // =============================================================== error
      Text {
        visible: root.errorText !== ""
        width: parent.width
        text: root.errorText
        color: root.urgent
        wrapMode: Text.WordWrap
        font.family: root.fontFamily
        font.pixelSize: Style.space(12)
      }

      Text {
        visible: root.errorText === "" && root.messages.length === 0
        width: parent.width
        text: "Nothing in " + (root.folderSummary() || "the watched folders") + "."
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.space(12)
      }

      // ============================================================ messages
      Repeater {
        model: root.messages

        delegate: Rectangle {
          id: row
          required property var modelData
          readonly property bool isUnread: modelData.unread === true

          width: body.width
          implicitHeight: lines.implicitHeight + Style.space(12)
          radius: Style.space(6)
          color: rowHover.hovered ? Style.selectedFillFor(root.foreground, Color.accent) : "transparent"

          HoverHandler { id: rowHover }
          TapHandler { onTapped: root.openZorp() }

          // Unread rows carry an accent bar down the left edge, like a
          // mail list's unread dot but readable at a glance down the column.
          Rectangle {
            visible: row.isUnread
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(3)
            height: parent.height - Style.space(12)
            radius: width / 2
            color: Color.accent
          }

          Column {
            id: lines
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Style.space(12)
            anchors.rightMargin: Style.space(8)
            spacing: Style.space(1)

            Item {
              width: parent.width
              implicitHeight: Style.space(17)

              Text {
                anchors.left: parent.left
                anchors.right: whenLabel.left
                anchors.rightMargin: Style.space(10)
                anchors.verticalCenter: parent.verticalCenter
                text: row.modelData.fromName || row.modelData.fromAddr || "(unknown sender)"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.space(13)
                font.weight: row.isUnread ? Font.DemiBold : Font.Normal
                elide: Text.ElideRight
              }

              Text {
                id: whenLabel
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: {
                  var mk = root.markers(row.modelData)
                  return (mk ? mk + "  " : "") + root.when(row.modelData.receivedAt)
                }
                color: row.isUnread ? Color.accent : root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.space(11)
              }
            }

            Text {
              width: parent.width
              text: row.modelData.subject || "(no subject)"
              color: row.isUnread ? root.foreground : root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.space(12)
              elide: Text.ElideRight
            }

            Text {
              visible: text !== ""
              width: parent.width
              text: String(row.modelData.preview || "").replace(/\s+/g, " ").trim()
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.space(11)
              elide: Text.ElideRight
              maximumLineCount: 1
            }
          }
        }
      }

      PanelSeparator { width: parent.width; visible: root.messages.length > 0 }

      // ============================================================== footer
      Item {
        width: parent.width
        implicitHeight: Style.space(20)

        Text {
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          text: "Open zorp"
          color: openHover.hovered ? Color.accent : root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.space(12)
          font.underline: openHover.hovered

          HoverHandler { id: openHover }
          TapHandler { onTapped: root.openZorp() }
        }

        Text {
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          text: root.pinned ? "right-click the icon to unpin" : "right-click the icon to pin"
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.space(10)
        }
      }
    }
  }
}
