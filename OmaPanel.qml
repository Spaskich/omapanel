import QtQuick
import QtQuick.Controls as QQC
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "OmaPanelModel.js" as Model

Item {
  id: root

  property var shell: null
  property var manifest: null
  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  readonly property string pluginId: manifest && manifest.id ? String(manifest.id) : "spaskich.omapanel"
  readonly property string sourceDir: manifest && manifest.__sourceDir ? String(manifest.__sourceDir) : ""
  readonly property string backendPath: sourceDir + "/scripts/omapanel-backend"
  readonly property var appLibrary: shell ? shell.appLibrary : null

  property bool opened: false
  property int pageIndex: 0
  property bool detailOpen: false
  property bool cursorActive: true

  property var programsRaw: []
  property var healthRaw: []
  property var appMetadata: ({})
  property string programQuery: ""
  property string programFilter: "all"
  property bool showAdvanced: false
  property int selectedProgramIndex: 0
  property int selectedHealthIndex: 0
  property int programRevision: 0
  property int healthRevision: 0

  property bool programsLoading: false
  property bool healthLoading: false
  property string programsError: ""
  property string healthError: ""
  property string programOutput: ""
  property string healthOutput: ""

  property bool confirmOpen: false
  property var pendingPreview: ({})
  property string pendingAdapter: ""
  property string pendingTarget: ""
  property string previewOutput: ""
  property string actionOutput: ""
  property string actionError: ""
  property string toastMessage: ""

  readonly property color background: Color.menu.background
  readonly property color foreground: Color.menu.text
  readonly property color border: Color.menu.border
  readonly property color scrim: Color.menu.scrim
  readonly property color selectedBackground: Color.menu.selectedBackground
  readonly property color selectedText: Color.menu.selectedText
  readonly property color mutedText: Color.muted
  readonly property var borderSpec: Border.surfaceSpec("menu", "border", border, Math.max(1, Style.space(2)))
  readonly property int cardWidth: Math.min(Style.space(1080), panel.width - Style.gapsOut * 4)
  readonly property int cardHeight: Math.min(Style.space(720), panel.height - Style.gapsOut * 4)
  readonly property bool narrow: cardWidth < Style.space(780)

  readonly property var counts: {
    programRevision
    return Model.programCounts(programsRaw)
  }
  readonly property var overall: {
    healthRevision
    return Model.overallHealth(healthRaw)
  }
  readonly property var selectedProgramRow: {
    programRevision
    return programModel.count > 0 ? programModel.get(Model.clampIndex(selectedProgramIndex, programModel.count)) : null
  }
  readonly property var selectedHealthRow: {
    healthRevision
    return healthModel.count > 0 ? healthModel.get(Model.clampIndex(selectedHealthIndex, healthModel.count)) : null
  }

  function open(payloadJson) {
    opened = true
    detailOpen = false
    cursorActive = true
    programQuery = ""
    refreshAll()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() {
    confirmOpen = false
    opened = false
  }

  function requestClose() {
    if (shell && typeof shell.hide === "function") shell.hide(pluginId)
    else close()
  }

  function setPage(index) {
    pageIndex = Math.max(0, Math.min(2, index))
    detailOpen = false
    cursorActive = true
    if (pageIndex === 1 && programsRaw.length === 0 && !programsLoading) refreshPrograms()
    if (pageIndex === 2 && healthRaw.length === 0 && !healthLoading) refreshHealth()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function refreshAll() {
    refreshPrograms()
    refreshHealth()
  }

  function refreshPrograms() {
    if (programsProc.running || backendPath === "") return
    rebuildAppMetadata()
    programsLoading = true
    programsError = ""
    programOutput = ""
    programsProc.running = true
  }

  function rebuildAppMetadata() {
    var next = ({})
    if (appLibrary) {
      try {
        var entries = appLibrary.sortedEntries("")
        for (var i = 0; i < entries.length; i++) {
          var entry = entries[i].entry
          if (entry && entry.id) next[String(entry.id)] = entry
        }
      } catch (e) { }
    }
    appMetadata = next
  }

  function refreshHealth() {
    if (healthProc.running || backendPath === "") return
    healthLoading = true
    healthError = ""
    healthOutput = ""
    healthProc.running = true
  }

  function enrichPrograms(programs) {
    var out = []
    for (var j = 0; j < programs.length; j++) {
      var source = programs[j]
      var row = ({})
      for (var key in source) row[key] = source[key]
      if (String(row.id).indexOf("desktop:") === 0) {
        var appId = String(row.id).slice(8)
        var app = appMetadata[appId]
        if (app) {
          try { row.name = appLibrary.entryName(app) || row.name } catch (e1) { }
          try { row.description = appLibrary.entrySubtext(app) || row.description } catch (e2) { }
          if (app.icon) row.icon = String(app.icon)
        }
      }
      row.searchText = [row.name, row.description, row.kind, row.source, row.sourceId].join(" ").toLowerCase()
      out.push(row)
    }
    return out
  }

  function applyPrograms(raw) {
    try {
      var parsed = JSON.parse(String(raw || ""))
      if (parsed.schemaVersion !== 1 || !Array.isArray(parsed.programs)) throw new Error("Unsupported programs response")
      programsRaw = enrichPrograms(parsed.programs)
      programsError = ""
      rebuildPrograms()
    } catch (e) {
      programsError = "Programs could not be read: " + e
    }
  }

  function appendProgramLine(line) {
    try {
      var parsed = JSON.parse(String(line || ""))
      var enriched = enrichPrograms([parsed])
      if (enriched.length > 0) {
        programsRaw = programsRaw.concat(enriched)
        programRebuildDelay.restart()
      }
    } catch (e) {
      programsError = "A program record could not be read: " + e
    }
  }

  function applyHealth(raw) {
    try {
      var parsed = JSON.parse(String(raw || ""))
      if (parsed.schemaVersion !== 1 || !Array.isArray(parsed.health)) throw new Error("Unsupported health response")
      healthRaw = parsed.health
      healthError = ""
      rebuildHealth()
    } catch (e) {
      healthError = "Health checks could not be read: " + e
    }
  }

  function rebuildPrograms() {
    var rows = Model.filterPrograms(programsRaw, programQuery, programFilter, showAdvanced)
    programModel.clear()
    for (var i = 0; i < rows.length; i++) programModel.append(rows[i])
    selectedProgramIndex = Model.clampIndex(selectedProgramIndex, programModel.count)
    programRevision++
    Qt.callLater(function() {
      if (programModel.count > 0) programList.positionViewAtIndex(selectedProgramIndex, ListView.Contain)
    })
  }

  function rebuildHealth() {
    healthModel.clear()
    for (var i = 0; i < healthRaw.length; i++) healthModel.append(healthRaw[i])
    selectedHealthIndex = Model.clampIndex(selectedHealthIndex, healthModel.count)
    healthRevision++
    Qt.callLater(function() {
      if (healthModel.count > 0) healthList.positionViewAtIndex(selectedHealthIndex, ListView.Contain)
    })
  }

  function selectRelative(delta) {
    cursorActive = true
    if (pageIndex === 1 && programModel.count > 0) {
      selectedProgramIndex = Model.wrapIndex(selectedProgramIndex, delta, programModel.count)
      programRevision++
      programList.positionViewAtIndex(selectedProgramIndex, ListView.Contain)
    } else if (pageIndex === 2 && healthModel.count > 0) {
      selectedHealthIndex = Model.wrapIndex(selectedHealthIndex, delta, healthModel.count)
      healthRevision++
      healthList.positionViewAtIndex(selectedHealthIndex, ListView.Contain)
    }
  }

  function activateSelected() {
    if (pageIndex === 1 && selectedProgramRow) detailOpen = true
    else if (pageIndex === 2 && selectedHealthRow) detailOpen = true
  }

  function requestSelectedAction() {
    if (pageIndex === 1 && selectedProgramRow && selectedProgramRow.actionAdapter)
      requestAction(selectedProgramRow.actionAdapter, selectedProgramRow.actionTarget)
    else if (pageIndex === 2 && selectedHealthRow && selectedHealthRow.actionAdapter)
      requestAction(selectedHealthRow.actionAdapter, selectedHealthRow.actionTarget)
  }

  function requestAction(adapter, target) {
    if (!adapter || previewProc.running || actionProc.running) return
    pendingAdapter = String(adapter)
    pendingTarget = String(target || "_")
    pendingPreview = ({})
    previewOutput = ""
    actionError = ""
    previewProc.running = true
  }

  function applyPreview(raw) {
    try {
      var parsed = JSON.parse(String(raw || ""))
      if (!parsed.ok) throw new Error("The backend rejected this action")
      pendingPreview = parsed
      confirmOpen = true
    } catch (e) {
      showToast("Could not preview action: " + e)
    }
  }

  function runPendingAction() {
    confirmOpen = false
    if (!pendingAdapter || actionProc.running) return
    actionOutput = ""
    actionError = ""
    actionProc.running = true
  }

  function showToast(message) {
    toastMessage = String(message || "")
    toastTimer.restart()
  }

  function goBackOrClose() {
    var action = Model.escapeAction(confirmOpen, programQuery, detailOpen)
    if (action === "dialog") {
      confirmOpen = false
    } else if (action === "search") {
      programQuery = ""
      rebuildPrograms()
      keyCatcher.forceActiveFocus()
    } else if (action === "detail") {
      detailOpen = false
    } else {
      requestClose()
    }
  }

  function statusColor(status) {
    if (status === "error") return Color.urgent
    if (status === "warning") return Color.urgent
    if (status === "ok") return Color.accent
    return Color.muted
  }

  ListModel { id: programModel; dynamicRoles: true }
  ListModel { id: healthModel; dynamicRoles: true }

  Connections {
    target: root.appLibrary
    function onAppsChanged() {
      if (root.programsRaw.length > 0) {
        root.rebuildAppMetadata()
        root.programsRaw = root.enrichPrograms(root.programsRaw)
        root.rebuildPrograms()
      }
    }
  }

  Process {
    id: programsProc
    command: [root.backendPath, "collect", "programs", "--jsonl"]
    stdout: SplitParser {
      onRead: function(line) { root.appendProgramLine(line) }
    }
    stderr: StdioCollector { id: programsStderr; waitForEnd: true }
    onStarted: {
      root.programsRaw = []
      programModel.clear()
      root.programRevision++
    }
    onExited: function(exitCode) {
      root.programsLoading = false
      programRebuildDelay.stop()
      root.rebuildPrograms()
      if (exitCode !== 0 && root.programsRaw.length === 0)
        root.programsError = String(programsStderr.text || "The programs collector failed.").trim()
    }
  }

  Process {
    id: healthProc
    command: [root.backendPath, "collect", "health"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.healthOutput = text
        if (text) root.applyHealth(text)
      }
    }
    stderr: StdioCollector { id: healthStderr; waitForEnd: true }
    onExited: function(exitCode) {
      root.healthLoading = false
      if (exitCode !== 0 && root.healthOutput === "")
        root.healthError = String(healthStderr.text || "The health collector failed.").trim()
    }
  }

  Process {
    id: previewProc
    command: [root.backendPath, "action", "--dry-run", root.pendingAdapter, root.pendingTarget]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.previewOutput = text
        if (text) root.applyPreview(text)
      }
    }
    stderr: StdioCollector { id: previewStderr; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0 && root.previewOutput === "")
        root.showToast(String(previewStderr.text || "The action is no longer available.").trim())
    }
  }

  Process {
    id: actionProc
    command: [root.backendPath, "action", root.pendingAdapter, root.pendingTarget]
    stdout: StdioCollector { id: actionStdout; waitForEnd: true }
    stderr: StdioCollector { id: actionStderr; waitForEnd: true }
    onExited: function(exitCode) {
      var terminal = root.pendingPreview && root.pendingPreview.terminal === true
      if (exitCode === 0) {
        if (terminal) root.requestClose()
        else {
          var message = "Action completed."
          try {
            var result = JSON.parse(String(actionStdout.text || ""))
            if (result.message) message = result.message
          } catch (e) { }
          root.showToast(message)
          if (root.pageIndex === 1) refreshDelay.restart()
          else if (root.pageIndex === 2) root.refreshHealth()
        }
      } else {
        root.showToast(String(actionStderr.text || "The workflow could not be started.").trim())
      }
    }
  }

  Timer { id: refreshDelay; interval: 700; onTriggered: root.refreshPrograms() }
  Timer { id: programRebuildDelay; interval: 80; onTriggered: root.rebuildPrograms() }
  Timer { id: toastTimer; interval: 4000; onTriggered: root.toastMessage = "" }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "omapanel"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Rectangle { anchors.fill: parent; color: root.scrim }
    MouseArea { anchors.fill: parent; onClicked: root.requestClose() }

    BorderSurface {
      id: card
      anchors.centerIn: parent
      width: root.cardWidth
      height: root.cardHeight
      color: root.background
      borderSpec: root.borderSpec
      radius: Style.cornerRadius
      padding: Style.spacing.panelPadding

      MouseArea { anchors.fill: parent; onClicked: {} }

      Item {
        id: keyCatcher
        anchors.fill: parent
        anchors.topMargin: card.contentTopInset
        anchors.rightMargin: card.contentRightInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset
        focus: true

        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) {
          if (root.confirmOpen) {
            if (confirmDialog.handleKey(event)) event.accepted = true
            return
          }

          if (searchField.activeFocus) {
            if (event.key === Qt.Key_Escape) {
              root.goBackOrClose(); event.accepted = true
            } else if (event.key === Qt.Key_Down) {
              keyCatcher.forceActiveFocus(); root.selectRelative(1); event.accepted = true
            }
            return
          }

          var ctrl = (event.modifiers & Qt.ControlModifier) !== 0
          var alt = (event.modifiers & Qt.AltModifier) !== 0
          if (event.key === Qt.Key_Escape) {
            root.goBackOrClose(); event.accepted = true
          } else if (ctrl && event.key === Qt.Key_K || event.text === "/") {
            if (root.pageIndex !== 1) root.setPage(1)
            searchField.forceActiveFocus(); searchField.selectAll(); event.accepted = true
          } else if (ctrl && event.key === Qt.Key_R) {
            if (root.pageIndex === 1) root.refreshPrograms()
            else if (root.pageIndex === 2) root.refreshHealth()
            else root.refreshAll()
            event.accepted = true
          } else if (alt && event.key >= Qt.Key_1 && event.key <= Qt.Key_3) {
            root.setPage(event.key - Qt.Key_1); event.accepted = true
          } else if (event.key === Qt.Key_Down || event.text === "j" || (ctrl && event.key === Qt.Key_N)) {
            root.selectRelative(1); event.accepted = true
          } else if (event.key === Qt.Key_Up || event.text === "k" || (ctrl && event.key === Qt.Key_P)) {
            root.selectRelative(-1); event.accepted = true
          } else if (event.key === Qt.Key_PageDown) {
            root.selectRelative(6); event.accepted = true
          } else if (event.key === Qt.Key_PageUp) {
            root.selectRelative(-6); event.accepted = true
          } else if (event.key === Qt.Key_Right || event.text === "l") {
            root.setPage(root.pageIndex + 1); event.accepted = true
          } else if (event.key === Qt.Key_Left || event.text === "h") {
            root.setPage(root.pageIndex - 1); event.accepted = true
          } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            root.activateSelected(); event.accepted = true
          } else if (event.key === Qt.Key_Delete || event.text === "x" || event.text === "X") {
            root.requestSelectedAction(); event.accepted = true
          } else if (event.key === Qt.Key_Backspace && root.detailOpen) {
            root.detailOpen = false; event.accepted = true
          }
        }

        ColumnLayout {
          anchors.fill: parent
          spacing: Style.spacing.md

          RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(Style.space(40), Style.font.heading + Style.spacing.sm * 2)
            spacing: Style.spacing.md

            ColumnLayout {
              Layout.fillWidth: true
              spacing: 0
              Text {
                text: "OmaPanel"
                color: root.foreground
                font.family: Style.font.family
                font.pixelSize: Style.font.heading
                font.bold: true
              }
              Text {
                text: "The Omarchy Control Center"
                color: root.mutedText
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
              }
            }

            Text {
              visible: root.programsLoading || root.healthLoading
              text: "󰑐"
              color: root.selectedText
              font.family: Style.font.family
              font.pixelSize: Style.font.icon
              RotationAnimation on rotation {
                from: 0; to: 360; duration: 900; loops: Animation.Infinite
                running: parent.visible
              }
            }

            PanelActionButton {
              iconText: "󰅖"
              tooltipText: "Close (Esc)"
              foreground: root.foreground
              focusable: true
              onClicked: root.requestClose()
            }
          }

          PanelSeparator { Layout.fillWidth: true; foreground: root.foreground }

          RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Style.spacing.lg

            ColumnLayout {
              visible: !root.narrow
              Layout.preferredWidth: Style.space(185)
              Layout.fillHeight: true
              spacing: Style.spacing.sm

              Repeater {
                model: [
                  { label: "Overview", icon: "󰋜", hint: "Alt+1" },
                  { label: "Programs", icon: "󰀻", hint: "Alt+2" },
                  { label: "Health & Recovery", icon: "󰒘", hint: "Alt+3" }
                ]
                delegate: Button {
                  required property int index
                  required property var modelData
                  Layout.fillWidth: true
                  text: modelData.label
                  iconText: modelData.icon
                  tooltipText: modelData.hint
                  leftAlign: true
                  selected: root.pageIndex === index
                  focusable: true
                  onClicked: root.setPage(index)
                }
              }

              Item { Layout.fillHeight: true }
              Text {
                Layout.fillWidth: true
                text: "Keyboard\n↑↓ / j k  Navigate\n↵  Open    x  Action\n/  Search  Esc  Back"
                color: root.mutedText
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                lineHeight: 1.25
              }
            }

            Rectangle {
              visible: !root.narrow
              Layout.fillHeight: true
              Layout.preferredWidth: 1
              color: root.border
              opacity: 0.35
            }

            ColumnLayout {
              Layout.fillWidth: true
              Layout.fillHeight: true
              spacing: Style.spacing.sm

              RowLayout {
                visible: root.narrow
                Layout.fillWidth: true
                spacing: Style.spacing.sm
                Repeater {
                  model: ["Overview", "Programs", "Health"]
                  delegate: Button {
                    required property int index
                    required property string modelData
                    Layout.fillWidth: true
                    text: modelData
                    selected: root.pageIndex === index
                    onClicked: root.setPage(index)
                  }
                }
              }

              StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: root.pageIndex

                // ------------------------------------------------ Overview
                QQC.ScrollView {
                  id: overviewScroll
                  clip: true
                  QQC.ScrollBar.horizontal.policy: QQC.ScrollBar.AlwaysOff

                  Column {
                    width: overviewScroll.availableWidth
                    spacing: Style.spacing.lg

                    Column {
                      width: parent.width
                      spacing: Style.spacing.xs
                      Text {
                        text: "Your Omarchy at a glance"
                        color: root.foreground
                        font.family: Style.font.family
                        font.pixelSize: Style.font.display
                        font.bold: true
                      }
                      Text {
                        width: parent.width
                        text: "A clear map of installed software, system health, and the existing tools that manage them."
                        color: root.mutedText
                        font.family: Style.font.family
                        font.pixelSize: Style.font.body
                        wrapMode: Text.WordWrap
                      }
                    }

                    GridLayout {
                      width: parent.width
                      columns: root.narrow ? 1 : 2
                      rowSpacing: Style.spacing.md
                      columnSpacing: Style.spacing.md

                      BorderSurface {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Style.space(138)
                        color: Style.normalFillFor(root.foreground, Color.accent)
                        borderSpec: Border.controlSpec("normal", root.foreground, Color.accent)
                        padding: Style.spacing.panelPadding
                        Column {
                          anchors.fill: parent
                          anchors.margins: parent.contentLeftInset
                          spacing: Style.spacing.sm
                          Text { text: "󰀻  PROGRAMS"; color: root.selectedText; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                          Text { text: root.counts.total + " visible items"; color: root.foreground; font.family: Style.font.family; font.pixelSize: Style.font.title; font.bold: true }
                          Text { width: parent.width; text: root.counts.webapp + " web apps · " + root.counts.plugin + " plugins · " + root.counts.tui + " TUIs"; color: root.mutedText; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; wrapMode: Text.WordWrap }
                          Button { text: "Browse programs"; iconText: "󰁔"; onClicked: root.setPage(1) }
                        }
                      }

                      BorderSurface {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Style.space(138)
                        color: Style.normalFillFor(root.foreground, Color.accent)
                        borderSpec: Border.controlSpec("normal", root.foreground, Color.accent)
                        padding: Style.spacing.panelPadding
                        Column {
                          anchors.fill: parent
                          anchors.margins: parent.contentLeftInset
                          spacing: Style.spacing.sm
                          Text { text: Model.statusIcon(root.overall.status) + "  SYSTEM HEALTH"; color: root.statusColor(root.overall.status); font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                          Text { text: root.overall.label; color: root.foreground; font.family: Style.font.family; font.pixelSize: Style.font.title; font.bold: true }
                          Text { width: parent.width; text: root.overall.count > 0 ? root.overall.count + " check(s) need attention" : "Diagnostics are read-only until you choose an action."; color: root.mutedText; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; wrapMode: Text.WordWrap }
                          Button { text: "Open health"; iconText: "󰁔"; onClicked: root.setPage(2) }
                        }
                      }
                    }

                    BorderSurface {
                      width: parent.width
                      implicitHeight: quickColumn.implicitHeight + Style.spacing.panelPadding * 2
                      color: "transparent"
                      borderSpec: Border.controlSpec("normal", root.foreground, Color.accent)
                      padding: Style.spacing.panelPadding
                      Column {
                        id: quickColumn
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: parent.contentLeftInset
                        spacing: Style.spacing.md
                        Text { text: "Quick handoffs"; color: root.foreground; font.family: Style.font.family; font.pixelSize: Style.font.subtitle; font.bold: true }
                        Text { width: parent.width; text: "OmaPanel does not replace system tools. It shows what will happen, then opens the workflow Omarchy already trusts."; color: root.mutedText; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; wrapMode: Text.WordWrap }
                        Row {
                          spacing: Style.spacing.sm
                          Button { text: "Run update"; iconText: "󰑐"; onClicked: root.requestAction("update", "_") }
                          Button { text: "Restart shell"; iconText: "󰑓"; onClicked: root.requestAction("restart-shell", "_") }
                          Button { text: "Copy report"; iconText: "󰆏"; onClicked: root.requestAction("copy-report", "_") }
                        }
                      }
                    }
                  }
                }

                // ------------------------------------------------ Programs
                ColumnLayout {
                  spacing: Style.spacing.sm

                  RowLayout {
                    Layout.fillWidth: true
                    spacing: Style.spacing.sm
                    TextField {
                      id: searchField
                      Layout.fillWidth: true
                      placeholderText: "Search programs…  /"
                      text: root.programQuery
                      onTextChanged: {
                        if (root.programQuery !== text) {
                          root.programQuery = text
                          root.selectedProgramIndex = 0
                          root.rebuildPrograms()
                        }
                      }
                    }
                    Button {
                      iconText: "󰑐"
                      tooltipText: "Refresh (Ctrl+R)"
                      onClicked: root.refreshPrograms()
                    }
                  }

                  QQC.ScrollView {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Style.space(42)
                    QQC.ScrollBar.vertical.policy: QQC.ScrollBar.AlwaysOff
                    Row {
                      spacing: Style.spacing.xs
                      Repeater {
                        model: [
                          { label: "All", value: "all" }, { label: "Apps", value: "app" },
                          { label: "Web", value: "webapp" }, { label: "TUIs", value: "tui" },
                          { label: "Plugins", value: "plugin" }, { label: "Flatpak", value: "flatpak" },
                          { label: "Launchers", value: "launcher" }, { label: "Packages", value: "package" }
                        ]
                        delegate: Button {
                          required property var modelData
                          text: modelData.label
                          selected: root.programFilter === modelData.value
                          visible: modelData.value !== "package" || root.showAdvanced
                          onClicked: {
                            root.programFilter = modelData.value
                            root.selectedProgramIndex = 0
                            root.rebuildPrograms()
                          }
                        }
                      }
                    }
                  }

                  RowLayout {
                    Layout.fillWidth: true
                    Text {
                      Layout.fillWidth: true
                      text: programModel.count + " result" + (programModel.count === 1 ? "" : "s")
                      color: root.mutedText
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption
                    }
                    Button {
                      text: root.showAdvanced ? "Hide packages" : "Advanced packages"
                      iconText: "󰒓"
                      selected: root.showAdvanced
                      onClicked: {
                        root.showAdvanced = !root.showAdvanced
                        if (!root.showAdvanced && root.programFilter === "package") root.programFilter = "all"
                        root.rebuildPrograms()
                      }
                    }
                  }

                  RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: Style.spacing.md

                    Item {
                      visible: !root.narrow || !root.detailOpen
                      Layout.fillWidth: true
                      Layout.fillHeight: true
                      Layout.preferredWidth: Style.space(470)

                      ListView {
                        id: programList
                        anchors.fill: parent
                        clip: true
                        spacing: Style.spacing.xs
                        model: programModel
                        QQC.ScrollBar.vertical: QQC.ScrollBar { id: programScrollbar; policy: QQC.ScrollBar.AsNeeded }
                        delegate: CursorSurface {
                          required property int index
                          property var row: programModel.get(index)
                          width: programList.width - (programScrollbar.visible ? Style.space(12) : 0)
                          height: Style.space(58)
                          hasCursor: root.cursorActive && root.selectedProgramIndex === index
                          current: root.detailOpen && root.selectedProgramIndex === index
                          foreground: root.foreground
                          accent: root.selectedText

                          RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Style.spacing.md
                            anchors.rightMargin: Style.spacing.md
                            spacing: Style.spacing.md
                            Text { text: Model.kindIcon(parent.parent.row.kind, ""); color: root.selectedText; font.family: Style.font.family; font.pixelSize: Style.font.iconLarge }
                            ColumnLayout {
                              Layout.fillWidth: true
                              spacing: 0
                              Text { Layout.fillWidth: true; text: parent.parent.parent.row.name; color: root.foreground; font.family: Style.font.family; font.pixelSize: Style.font.body; font.bold: true; elide: Text.ElideRight }
                              Text { Layout.fillWidth: true; text: parent.parent.parent.row.source + (parent.parent.parent.row.version ? " · " + parent.parent.parent.row.version : ""); color: root.mutedText; font.family: Style.font.family; font.pixelSize: Style.font.caption; elide: Text.ElideRight }
                            }
                            Text { visible: parent.parent.row.protected === true; text: "󰌾"; color: root.mutedText; font.family: Style.font.family; font.pixelSize: Style.font.iconSmall }
                            Text { text: "󰁔"; color: root.mutedText; font.family: Style.font.family; font.pixelSize: Style.font.iconSmall }
                          }

                          MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: { root.cursorActive = true; root.selectedProgramIndex = index; root.programRevision++ }
                            onClicked: { root.selectedProgramIndex = index; root.programRevision++; root.detailOpen = true }
                          }
                        }
                      }

                      Column {
                        anchors.centerIn: parent
                        visible: !root.programsLoading && programModel.count === 0
                        spacing: Style.spacing.sm
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.programsError ? "󰅚" : "󰍉"; color: root.programsError ? Color.urgent : root.mutedText; font.family: Style.font.family; font.pixelSize: Style.font.displayLarge }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.programsError || "No programs match this view."; color: root.foreground; font.family: Style.font.family; font.pixelSize: Style.font.body }
                      }
                    }

                    BorderSurface {
                      visible: (!root.narrow || root.detailOpen) && root.selectedProgramRow !== null
                      Layout.fillHeight: true
                      Layout.preferredWidth: root.narrow ? -1 : Style.space(300)
                      Layout.fillWidth: root.narrow
                      color: Style.normalFillFor(root.foreground, Color.accent)
                      borderSpec: Border.controlSpec("normal", root.foreground, Color.accent)
                      padding: Style.spacing.panelPadding

                      ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: parent.contentLeftInset
                        spacing: Style.spacing.md
                        Button { visible: root.narrow; text: "Back to programs"; iconText: "󰁍"; onClicked: root.detailOpen = false }
                        Text { text: Model.kindIcon(root.selectedProgramRow ? root.selectedProgramRow.kind : "", ""); color: root.selectedText; font.family: Style.font.family; font.pixelSize: Style.font.displayLarge }
                        Text { Layout.fillWidth: true; text: root.selectedProgramRow ? root.selectedProgramRow.name : ""; color: root.foreground; font.family: Style.font.family; font.pixelSize: Style.font.title; font.bold: true; wrapMode: Text.WordWrap }
                        Text { Layout.fillWidth: true; text: root.selectedProgramRow ? Model.kindLabel(root.selectedProgramRow.kind) + " · " + root.selectedProgramRow.source : ""; color: root.mutedText; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
                        PanelSeparator { Layout.fillWidth: true; foreground: root.foreground }
                        Text { Layout.fillWidth: true; text: root.selectedProgramRow && root.selectedProgramRow.description ? root.selectedProgramRow.description : "No description is available."; color: root.foreground; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; wrapMode: Text.WordWrap }
                        Text { Layout.fillWidth: true; text: root.selectedProgramRow ? "Managed by: " + root.selectedProgramRow.source + "\nID: " + root.selectedProgramRow.sourceId + (root.selectedProgramRow.version ? "\nVersion: " + root.selectedProgramRow.version : "") : ""; color: root.mutedText; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WrapAnywhere }
                        Item { Layout.fillHeight: true }
                        Text { visible: root.selectedProgramRow && root.selectedProgramRow.warning; Layout.fillWidth: true; text: "󰀦  " + (root.selectedProgramRow ? root.selectedProgramRow.warning : ""); color: root.selectedProgramRow && root.selectedProgramRow.protected ? root.mutedText : Color.urgent; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
                        Button {
                          Layout.fillWidth: true
                          visible: root.selectedProgramRow && root.selectedProgramRow.removable === true
                          text: root.selectedProgramRow ? root.selectedProgramRow.actionLabel : ""
                          iconText: "󰭌"
                          bordered: true
                          onClicked: root.requestSelectedAction()
                        }
                        Text { visible: root.selectedProgramRow && root.selectedProgramRow.protected === true; Layout.fillWidth: true; text: "Protected system component"; color: root.mutedText; font.family: Style.font.family; font.pixelSize: Style.font.caption; horizontalAlignment: Text.AlignHCenter }
                      }
                    }
                  }
                }

                // ------------------------------------------ Health & Recovery
                ColumnLayout {
                  spacing: Style.spacing.sm

                  RowLayout {
                    Layout.fillWidth: true
                    ColumnLayout {
                      Layout.fillWidth: true
                      spacing: 0
                      Text { text: "Health & Recovery"; color: root.foreground; font.family: Style.font.family; font.pixelSize: Style.font.title; font.bold: true }
                      Text { text: "Read-only checks first; repairs stay in Omarchy's existing workflows."; color: root.mutedText; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                    }
                    Button { text: "Copy report"; iconText: "󰆏"; onClicked: root.requestAction("copy-report", "_") }
                    Button { iconText: "󰑐"; tooltipText: "Refresh (Ctrl+R)"; onClicked: root.refreshHealth() }
                  }

                  RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: Style.spacing.md

                    Item {
                      visible: !root.narrow || !root.detailOpen
                      Layout.fillWidth: true
                      Layout.fillHeight: true
                      Layout.preferredWidth: Style.space(470)
                      ListView {
                        id: healthList
                        anchors.fill: parent
                        clip: true
                        spacing: Style.spacing.xs
                        model: healthModel
                        QQC.ScrollBar.vertical: QQC.ScrollBar { id: healthScrollbar; policy: QQC.ScrollBar.AsNeeded }
                        delegate: CursorSurface {
                          required property int index
                          property var row: healthModel.get(index)
                          width: healthList.width - (healthScrollbar.visible ? Style.space(12) : 0)
                          height: Style.space(62)
                          hasCursor: root.cursorActive && root.selectedHealthIndex === index
                          current: root.detailOpen && root.selectedHealthIndex === index
                          foreground: root.foreground
                          accent: root.selectedText
                          RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Style.spacing.md
                            anchors.rightMargin: Style.spacing.md
                            spacing: Style.spacing.md
                            Text { text: Model.statusIcon(parent.parent.row.status); color: root.statusColor(parent.parent.row.status); font.family: Style.font.family; font.pixelSize: Style.font.iconLarge }
                            ColumnLayout {
                              Layout.fillWidth: true
                              spacing: 0
                              Text { Layout.fillWidth: true; text: parent.parent.parent.row.title; color: root.foreground; font.family: Style.font.family; font.pixelSize: Style.font.body; font.bold: true; elide: Text.ElideRight }
                              Text { Layout.fillWidth: true; text: parent.parent.parent.row.summary; color: root.mutedText; font.family: Style.font.family; font.pixelSize: Style.font.caption; elide: Text.ElideRight }
                            }
                            Text { text: "󰁔"; color: root.mutedText; font.family: Style.font.family; font.pixelSize: Style.font.iconSmall }
                          }
                          MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: { root.cursorActive = true; root.selectedHealthIndex = index; root.healthRevision++ }
                            onClicked: { root.selectedHealthIndex = index; root.healthRevision++; root.detailOpen = true }
                          }
                        }
                      }
                      Column {
                        anchors.centerIn: parent
                        visible: !root.healthLoading && healthModel.count === 0
                        spacing: Style.spacing.sm
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.healthError ? "󰅚" : "󰒘"; color: root.healthError ? Color.urgent : root.mutedText; font.family: Style.font.family; font.pixelSize: Style.font.displayLarge }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.healthError || "No health results are available."; color: root.foreground; font.family: Style.font.family; font.pixelSize: Style.font.body }
                      }
                    }

                    BorderSurface {
                      visible: (!root.narrow || root.detailOpen) && root.selectedHealthRow !== null
                      Layout.fillHeight: true
                      Layout.preferredWidth: root.narrow ? -1 : Style.space(310)
                      Layout.fillWidth: root.narrow
                      color: Style.normalFillFor(root.foreground, Color.accent)
                      borderSpec: Border.controlSpec("normal", root.foreground, Color.accent)
                      padding: Style.spacing.panelPadding
                      ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: parent.contentLeftInset
                        spacing: Style.spacing.md
                        Button { visible: root.narrow; text: "Back to checks"; iconText: "󰁍"; onClicked: root.detailOpen = false }
                        Text { text: Model.statusIcon(root.selectedHealthRow ? root.selectedHealthRow.status : "unknown"); color: root.statusColor(root.selectedHealthRow ? root.selectedHealthRow.status : "unknown"); font.family: Style.font.family; font.pixelSize: Style.font.displayLarge }
                        Text { Layout.fillWidth: true; text: root.selectedHealthRow ? root.selectedHealthRow.title : ""; color: root.foreground; font.family: Style.font.family; font.pixelSize: Style.font.title; font.bold: true; wrapMode: Text.WordWrap }
                        Text { Layout.fillWidth: true; text: root.selectedHealthRow ? root.selectedHealthRow.summary : ""; color: root.statusColor(root.selectedHealthRow ? root.selectedHealthRow.status : "unknown"); font.family: Style.font.family; font.pixelSize: Style.font.body; wrapMode: Text.WordWrap }
                        PanelSeparator { Layout.fillWidth: true; foreground: root.foreground }
                        QQC.ScrollView {
                          Layout.fillWidth: true
                          Layout.fillHeight: true
                          Text { width: parent.width; text: root.selectedHealthRow ? root.selectedHealthRow.detail : ""; color: root.foreground; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; wrapMode: Text.WrapAnywhere }
                        }
                        Button {
                          Layout.fillWidth: true
                          visible: root.selectedHealthRow && root.selectedHealthRow.actionAdapter
                          text: root.selectedHealthRow ? root.selectedHealthRow.actionLabel : ""
                          iconText: "󰁔"
                          bordered: true
                          onClicked: root.requestSelectedAction()
                        }
                        Button {
                          Layout.fillWidth: true
                          visible: root.selectedHealthRow && root.selectedHealthRow.id === "snapshots"
                          text: "Open snapshot restore"
                          iconText: "󰦛"
                          bordered: true
                          onClicked: root.requestAction("snapshot-restore", "_")
                        }
                        Text { Layout.fillWidth: true; text: "OmaPanel never requests privilege while checking this state."; color: root.mutedText; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter }
                      }
                    }
                  }
                }
              }
            }
          }
        }

        ConfirmDialog {
          id: confirmDialog
          anchors.fill: parent
          z: 20
          opened: root.confirmOpen
          message: {
            var p = root.pendingPreview || {}
            var command = p.argv && p.argv.length ? p.argv.join(" ") : ""
            return String(p.label || "Continue") + "?\n\n" + String(p.workflow || "")
              + (command ? "\n\nWorkflow:\n" + command : "")
          }
          confirmText: root.pendingPreview && root.pendingPreview.destructive ? "Continue" : "Open"
          background: root.background
          foreground: root.foreground
          scrim: root.scrim
          selectedBackground: root.selectedBackground
          selectedText: root.selectedText
          fontFamily: Style.font.family
          cornerRadius: Style.cornerRadius
          onCanceled: { root.confirmOpen = false; keyCatcher.forceActiveFocus() }
          onConfirmed: root.runPendingAction()
        }

        BorderSurface {
          visible: root.toastMessage !== ""
          z: 30
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.bottom: parent.bottom
          anchors.bottomMargin: Style.spacing.md
          implicitWidth: Math.min(toastText.implicitWidth + Style.space(36), parent.width - Style.space(30))
          implicitHeight: toastText.implicitHeight + Style.spacing.md * 2
          color: Color.popups.background
          borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, 1)
          padding: Style.spacing.md
          Text {
            id: toastText
            anchors.centerIn: parent
            width: Math.min(implicitWidth, keyCatcher.width - Style.space(60))
            text: root.toastMessage
            color: Color.popups.text
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
          }
        }
      }
    }
  }
}
