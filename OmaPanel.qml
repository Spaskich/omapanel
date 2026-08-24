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
  readonly property string pluginVersion: manifest && manifest.version ? String(manifest.version) : "0.3.0"
  readonly property string sourceDir: manifest && manifest.__sourceDir ? String(manifest.__sourceDir) : ""
  readonly property string backendPath: sourceDir + "/scripts/omapanel-backend"
  readonly property var appLibrary: shell ? shell.appLibrary : null

  property bool opened: false
  property int pageIndex: 0
  property bool detailOpen: false
  property bool cursorActive: true

  property var programsRaw: []
  property var healthRaw: []
  property var appearance: Model.emptyAppearance()
  property var appMetadata: ({})
  property string programQuery: ""
  property string programFilter: "all"
  property string doctorFilter: "all"
  property bool showAdvanced: false
  property int selectedProgramIndex: 0
  property int selectedHealthIndex: 0
  property int programRevision: 0
  property int healthRevision: 0

  property bool programsLoading: false
  property bool healthLoading: false
  property bool appearanceLoading: false
  property bool appearanceBusy: false
  property string programsError: ""
  property string healthError: ""
  property string programOutput: ""
  property string healthOutput: ""
  property string doctorGeneratedAt: ""
  property string appearanceOutput: ""
  property string appearanceError: ""
  property string pendingAppearanceSetting: ""
  property string pendingAppearanceValue: ""
  property var pendingAppearancePrevious: null
  property bool pendingAppearanceIsUndo: false
  property string appearanceActionOutput: ""
  property string pendingHandoff: ""
  property string handoffOutput: ""
  property bool undoAvailable: false
  property string undoSetting: ""
  property var undoValue: null

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
  // Color.muted can be intentionally very quiet in terminal-oriented themes.
  // Panels carry more explanatory copy, so follow Quattro's own PanelHero
  // convention and derive a readable secondary tone from the surface text.
  readonly property color mutedText: Qt.darker(foreground, 1.45)
  readonly property var borderSpec: Border.surfaceSpec("menu", "border", border, Math.max(1, Style.space(2)))
  readonly property int cardWidth: Math.min(Style.space(1180), panel.width - Style.gapsOut * 4)
  readonly property bool narrow: cardWidth < Style.space(820)
  readonly property int desiredCardHeight: Style.space(760)
  readonly property int cardHeight: Math.min(desiredCardHeight, panel.height - Style.gapsOut * 4)

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
    pageIndex = Math.max(0, Math.min(3, index))
    detailOpen = false
    cursorActive = true
    if (pageIndex === 1 && appearance.generatedAt === "" && !appearanceLoading) refreshAppearance()
    if (pageIndex === 2 && programsRaw.length === 0 && !programsLoading) refreshPrograms()
    if (pageIndex === 3 && healthRaw.length === 0 && !healthLoading) refreshHealth()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function refreshAll() {
    refreshAppearance()
    refreshPrograms()
    refreshHealth()
  }

  function refreshAppearance() {
    if (appearanceProc.running || backendPath === "") return
    appearanceLoading = true
    appearanceError = ""
    appearanceOutput = ""
    appearanceProc.running = true
  }

  function applyAppearance(raw) {
    try {
      var parsed = JSON.parse(String(raw || ""))
      var normalized = Model.normalizeAppearance(parsed)
      if (!normalized) throw new Error("Unsupported appearance response")
      appearance = normalized
      appearanceError = ""
    } catch (e) {
      appearanceError = "Appearance could not be read: " + e
    }
  }

  function requestAppearanceSetting(setting, value) {
    if (appearanceBusy || appearanceLoading) return
    var previous = Model.appearanceValue(appearance, setting)
    var requested = value
    if (String(previous) === String(requested)) return
    pendingAppearanceSetting = String(setting)
    pendingAppearanceValue = String(requested)
    pendingAppearancePrevious = previous
    pendingAppearanceIsUndo = false
    appearanceActionOutput = ""
    appearanceBusy = true
    appearanceSetProc.running = true
  }

  function requestTextSizeDelta(delta) {
    if (appearance.textSize.state !== "ok") return
    var index = Model.textSizeIndex(appearance.textSize.stops, appearance.textSize.currentPx)
    var next = Math.max(0, Math.min(appearance.textSize.stops.length - 1, index + delta))
    requestAppearanceSetting("text-size", appearance.textSize.stops[next])
  }

  function scrollAppearance(delta, absoluteEnd) {
    var flick = appearanceScroll.contentItem
    if (!flick || flick.contentY === undefined) return
    var maximum = Math.max(0, flick.contentHeight - flick.height)
    if (absoluteEnd === true) flick.contentY = maximum
    else if (absoluteEnd === false) flick.contentY = 0
    else flick.contentY = Math.max(0, Math.min(maximum, flick.contentY + delta))
  }

  function runUndo() {
    if (!undoAvailable || appearanceBusy || undoValue === null || undoValue === undefined) return
    pendingAppearanceSetting = undoSetting
    pendingAppearanceValue = String(undoValue)
    pendingAppearancePrevious = null
    pendingAppearanceIsUndo = true
    appearanceActionOutput = ""
    undoAvailable = false
    undoTimer.stop()
    appearanceBusy = true
    appearanceSetProc.running = true
  }

  function showUndoToast(message, setting, previous) {
    toastTimer.stop()
    toastMessage = String(message || "Setting changed.")
    undoSetting = String(setting)
    undoValue = previous
    undoAvailable = true
    undoTimer.restart()
  }

  function clearUndo() {
    undoAvailable = false
    undoSetting = ""
    undoValue = null
    undoTimer.stop()
    toastMessage = ""
  }

  function requestAppearanceHandoff(kind) {
    if (handoffProc.running || appearanceBusy) return
    pendingHandoff = String(kind)
    handoffOutput = ""
    handoffProc.running = true
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
      if (parsed.schemaVersion !== 2 || !Array.isArray(parsed.checks)) throw new Error("Unsupported Doctor response")
      healthRaw = parsed.checks
      doctorGeneratedAt = String(parsed.generatedAt || "")
      healthError = ""
      rebuildHealth()
    } catch (e) {
      healthError = "Doctor results could not be read: " + e
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
    var rows = Model.filterDoctor(healthRaw, doctorFilter)
    healthModel.clear()
    for (var i = 0; i < rows.length; i++) healthModel.append(rows[i])
    selectedHealthIndex = Model.clampIndex(selectedHealthIndex, healthModel.count)
    healthRevision++
    Qt.callLater(function() {
      if (healthModel.count > 0) healthList.positionViewAtIndex(selectedHealthIndex, ListView.Contain)
    })
  }

  function selectRelative(delta) {
    cursorActive = true
    if (pageIndex === 2 && programModel.count > 0) {
      selectedProgramIndex = Model.wrapIndex(selectedProgramIndex, delta, programModel.count)
      programRevision++
      programList.positionViewAtIndex(selectedProgramIndex, ListView.Contain)
    } else if (pageIndex === 3 && healthModel.count > 0) {
      selectedHealthIndex = Model.wrapIndex(selectedHealthIndex, delta, healthModel.count)
      healthRevision++
      healthList.positionViewAtIndex(selectedHealthIndex, ListView.Contain)
    }
  }

  function activateSelected() {
    if (pageIndex === 2 && selectedProgramRow) detailOpen = true
    else if (pageIndex === 3 && selectedHealthRow) detailOpen = true
  }

  function requestSelectedAction() {
    if (pageIndex === 2 && selectedProgramRow && selectedProgramRow.actionAdapter)
      requestAction(selectedProgramRow.actionAdapter, selectedProgramRow.actionTarget)
    else if (pageIndex === 3 && selectedHealthRow && selectedHealthRow.actionAdapter)
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
    undoAvailable = false
    undoTimer.stop()
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
    return mutedText
  }

  function programIconSource(row) {
    if (!row || !row.icon || !appLibrary) return ""
    var kind = String(row.kind || "")
    if (kind !== "app" && kind !== "webapp" && kind !== "tui" && kind !== "launcher" && kind !== "flatpak")
      return ""
    try { return String(appLibrary.iconSource(row.icon) || "") } catch (e) { return "" }
  }

  ListModel { id: programModel; dynamicRoles: true }
  ListModel { id: healthModel; dynamicRoles: true }

  component ProgramIcon: Item {
    id: programIcon
    property var row: null
    property int iconSize: Style.space(32)
    readonly property string imageSource: root.programIconSource(row)

    implicitWidth: iconSize
    implicitHeight: iconSize

    Image {
      id: programIconImage
      anchors.fill: parent
      source: programIcon.imageSource
      sourceSize.width: programIcon.iconSize * 2
      sourceSize.height: programIcon.iconSize * 2
      fillMode: Image.PreserveAspectFit
      asynchronous: true
    }

    Text {
      anchors.centerIn: parent
      visible: programIconImage.status !== Image.Ready
      text: Model.kindIcon(programIcon.row ? programIcon.row.kind : "", "")
      color: root.selectedText
      font.family: Style.font.family
      font.pixelSize: Math.min(programIcon.iconSize, Style.font.iconLarge)
    }
  }

  component PersistentScrollBar: QQC.ScrollBar {
    id: persistentBar
    policy: QQC.ScrollBar.AlwaysOn
    active: true
    interactive: true
    implicitWidth: Style.space(10)

    contentItem: Rectangle {
      implicitWidth: Style.space(6)
      implicitHeight: Style.space(48)
      radius: width / 2
      color: root.foreground
      opacity: persistentBar.hovered || persistentBar.pressed ? 0.9 : 0.62
    }

    background: Rectangle {
      implicitWidth: Style.space(6)
      radius: width / 2
      color: root.foreground
      opacity: 0.12
    }
  }

  component LoadingState: Column {
    property string label: "Loading…"
    spacing: Style.spacing.md

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: "󰑐"
      color: root.selectedText
      font.family: Style.font.family
      font.pixelSize: Style.font.displayLarge
      RotationAnimation on rotation {
        from: 0
        to: 360
        duration: 900
        loops: Animation.Infinite
        running: parent.visible
      }
    }
    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: parent.label
      color: root.mutedText
      font.family: Style.font.family
      font.pixelSize: Style.font.body
    }
  }

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
    command: [root.backendPath, "collect", "doctor"]
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
        root.healthError = String(healthStderr.text || "Doctor could not complete its checks.").trim()
    }
  }

  Process {
    id: appearanceProc
    command: [root.backendPath, "collect", "appearance"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.appearanceOutput = text
        if (text) root.applyAppearance(text)
      }
    }
    stderr: StdioCollector { id: appearanceStderr; waitForEnd: true }
    onExited: function(exitCode) {
      root.appearanceLoading = false
      if (exitCode !== 0 && root.appearanceOutput === "")
        root.appearanceError = String(appearanceStderr.text || "Appearance could not be refreshed.").trim()
    }
  }

  Process {
    id: appearanceSetProc
    command: [root.backendPath, "appearance", "set", root.pendingAppearanceSetting, root.pendingAppearanceValue]
    stdout: StdioCollector {
      id: appearanceSetStdout
      waitForEnd: true
      onStreamFinished: root.appearanceActionOutput = text
    }
    stderr: StdioCollector { id: appearanceSetStderr; waitForEnd: true }
    onExited: function(exitCode) {
      root.appearanceBusy = false
      if (exitCode === 0) {
        var message = root.pendingAppearanceIsUndo ? "Change undone." : "Setting changed."
        try {
          var result = JSON.parse(String(root.appearanceActionOutput || appearanceSetStdout.text || ""))
          if (!root.pendingAppearanceIsUndo && result.message) message = result.message
        } catch (e) { }
        if (root.pendingAppearanceIsUndo) root.showToast(message)
        else root.showUndoToast(message, root.pendingAppearanceSetting, root.pendingAppearancePrevious)
        root.refreshAppearance()
      } else {
        root.showToast(String(appearanceSetStderr.text || "The appearance setting could not be changed.").trim())
        root.refreshAppearance()
      }
    }
  }

  Process {
    id: handoffProc
    command: [root.backendPath, "appearance", "handoff", root.pendingHandoff]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.handoffOutput = text }
    stderr: StdioCollector { id: handoffStderr; waitForEnd: true }
    onExited: function(exitCode) {
      var returnsHere = root.pendingHandoff === "theme" || root.pendingHandoff === "background"
      if (exitCode === 0) {
        if (returnsHere) {
          root.refreshAppearance()
          Qt.callLater(function() { keyCatcher.forceActiveFocus() })
        } else {
          root.requestClose()
        }
      } else {
        root.showToast(String(handoffStderr.text || "The Omarchy workflow could not be opened.").trim())
        if (returnsHere) Qt.callLater(function() { keyCatcher.forceActiveFocus() })
      }
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
          if (root.pageIndex === 2) refreshDelay.restart()
          else if (root.pageIndex === 3) root.refreshHealth()
        }
      } else {
        root.showToast(String(actionStderr.text || "The workflow could not be started.").trim())
      }
    }
  }

  Timer { id: refreshDelay; interval: 700; onTriggered: root.refreshPrograms() }
  Timer { id: programRebuildDelay; interval: 80; onTriggered: root.rebuildPrograms() }
  Timer { id: toastTimer; interval: 4000; onTriggered: root.toastMessage = "" }
  Timer { id: undoTimer; interval: 8000; onTriggered: root.clearUndo() }

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

      Behavior on height {
        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
      }

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
          var ctrl = (event.modifiers & Qt.ControlModifier) !== 0
          var alt = (event.modifiers & Qt.AltModifier) !== 0

          if (root.confirmOpen) {
            if (confirmDialog.handleKey(event)) event.accepted = true
            return
          }

          if (root.pageIndex === 1 && fontDropdown.popupOpen) return

          if (ctrl && event.key === Qt.Key_Z && root.undoAvailable) {
            root.runUndo(); event.accepted = true; return
          }

          if (root.pageIndex === 1 && event.key === Qt.Key_PageDown) {
            root.scrollAppearance(Style.space(360)); event.accepted = true; return
          } else if (root.pageIndex === 1 && event.key === Qt.Key_PageUp) {
            root.scrollAppearance(-Style.space(360)); event.accepted = true; return
          } else if (root.pageIndex === 1 && event.key === Qt.Key_End) {
            root.scrollAppearance(0, true); event.accepted = true; return
          } else if (root.pageIndex === 1 && event.key === Qt.Key_Home) {
            root.scrollAppearance(0, false); event.accepted = true; return
          } else if (root.pageIndex === 1 && keyCatcher.activeFocus
                     && (event.key === Qt.Key_Down || event.text === "j")) {
            root.scrollAppearance(Style.space(64)); event.accepted = true; return
          } else if (root.pageIndex === 1 && keyCatcher.activeFocus
                     && (event.key === Qt.Key_Up || event.text === "k")) {
            root.scrollAppearance(-Style.space(64)); event.accepted = true; return
          }

          if (searchField.activeFocus) {
            if (event.key === Qt.Key_Escape) {
              root.goBackOrClose(); event.accepted = true
            } else if (event.key === Qt.Key_Down) {
              keyCatcher.forceActiveFocus(); root.selectRelative(1); event.accepted = true
            }
            return
          }

          if (event.key === Qt.Key_Escape) {
            root.goBackOrClose(); event.accepted = true
          } else if (ctrl && event.key === Qt.Key_K || event.text === "/") {
            if (root.pageIndex !== 2) root.setPage(2)
            searchField.forceActiveFocus(); searchField.selectAll(); event.accepted = true
          } else if (ctrl && event.key === Qt.Key_R) {
            if (root.pageIndex === 1) root.refreshAppearance()
            else if (root.pageIndex === 2) root.refreshPrograms()
            else if (root.pageIndex === 3) root.refreshHealth()
            else root.refreshAll()
            event.accepted = true
          } else if (alt && event.key >= Qt.Key_1 && event.key <= Qt.Key_4) {
            root.setPage(event.key - Qt.Key_1); event.accepted = true
          } else if (root.pageIndex === 1 && !keyCatcher.activeFocus) {
            return
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
              visible: root.appearanceLoading || root.programsLoading || root.healthLoading
              text: root.appearanceLoading ? "Reading appearance" : root.programsLoading && root.healthLoading ? "Scanning system" : root.programsLoading ? "Scanning programs" : "Running Doctor"
              color: root.mutedText
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
            }

            Text {
              visible: root.appearanceLoading || root.programsLoading || root.healthLoading
              text: "󰑐"
              color: root.selectedText
              font.family: Style.font.family
              font.pixelSize: Style.font.icon
              RotationAnimation on rotation {
                from: 0; to: 360; duration: 900; loops: Animation.Infinite
                running: parent.visible
              }
            }

            BorderSurface {
              implicitWidth: versionText.implicitWidth + Style.space(12)
              implicitHeight: versionText.implicitHeight + Style.space(6)
              color: "transparent"
              borderSpec: Border.controlSpec("normal", root.foreground, Color.accent)
              radius: Style.cornerRadius
              Text {
                id: versionText
                anchors.centerIn: parent
                text: "v" + root.pluginVersion
                color: root.mutedText
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: true
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
              Layout.preferredWidth: Style.space(205)
              Layout.fillHeight: true
              spacing: Style.spacing.sm

              Repeater {
                model: [
                  { label: "Overview", icon: "󰋜", hint: "Alt+1" },
                  { label: "Appearance", icon: "󰏘", hint: "Alt+2" },
                  { label: "Programs", icon: "󰀻", hint: "Alt+3" },
                  { label: "Doctor", icon: "󰒘", hint: "Alt+4" }
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
              PanelSeparator { Layout.fillWidth: true; foreground: root.foreground }
              PanelSectionHeader {
                Layout.fillWidth: true
                text: "KEYBOARD"
                foreground: root.foreground
                fontFamily: Style.font.family
              }
              Text {
                Layout.fillWidth: true
                text: "Alt+1–4    Pages\nTab         Controls\n↑↓ / j k   Navigate\nCtrl+Z      Undo setting\nEsc         Back"
                color: root.mutedText
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                lineHeight: 1.2
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
                  model: ["Overview", "Appearance", "Programs", "Doctor"]
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
                  rightPadding: Style.space(18)
                  QQC.ScrollBar.horizontal.policy: QQC.ScrollBar.AlwaysOff
                  QQC.ScrollBar.vertical: PersistentScrollBar {
                    parent: overviewScroll
                    anchors.top: overviewScroll.top
                    anchors.right: overviewScroll.right
                    anchors.bottom: overviewScroll.bottom
                  }

                  Column {
                    width: overviewScroll.availableWidth
                    spacing: Style.space(14)

                    Row {
                      width: parent.width
                      spacing: Style.space(14)

                      BorderSurface {
                        width: Style.space(52)
                        height: Style.space(52)
                        anchors.verticalCenter: parent.verticalCenter
                        color: Style.selectedFillFor(root.foreground, Color.accent)
                        borderSpec: Border.controlSpec("normal", root.foreground, Color.accent)
                        radius: Style.cornerRadius
                        Text {
                          anchors.centerIn: parent
                          text: "󰒓"
                          color: root.selectedText
                          font.family: Style.font.family
                          font.pixelSize: Style.font.display
                        }
                      }

                      Column {
                        width: parent.width - Style.space(66)
                        anchors.verticalCenter: parent.verticalCenter
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
                          text: "One place to understand this system and reach the Omarchy tool that owns each change."
                          color: root.mutedText
                          font.family: Style.font.family
                          font.pixelSize: Style.font.body
                          wrapMode: Text.WordWrap
                        }
                      }
                    }

                    PanelSectionHeader {
                      width: parent.width
                      text: "STATUS"
                      foreground: root.foreground
                      fontFamily: Style.font.family
                    }

                    GridLayout {
                      width: parent.width
                      columns: root.narrow ? 1 : 2
                      rowSpacing: Style.spacing.md
                      columnSpacing: Style.spacing.md

                      BorderSurface {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Style.space(150)
                        color: Style.normalFillFor(root.foreground, Color.accent)
                        borderSpec: Border.controlSpec("normal", root.foreground, Color.accent)
                        padding: Style.spacing.panelPadding
                        Column {
                          anchors.fill: parent
                          anchors.margins: parent.contentLeftInset
                          spacing: Style.spacing.sm
                          Text { text: "󰏘  APPEARANCE"; color: root.selectedText; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                          Text { text: root.appearanceLoading && root.appearance.generatedAt === "" ? "Reading style…" : root.appearance.theme.current; color: root.foreground; font.family: Style.font.family; font.pixelSize: Style.font.title; font.bold: true }
                          Text { width: parent.width; text: root.appearance.background.current + " · " + root.appearance.font.current; color: root.mutedText; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; wrapMode: Text.WordWrap; elide: Text.ElideRight }
                          Item { width: 1; height: Style.spacing.xs }
                          Button { text: "Open appearance"; iconText: "󰁔"; onClicked: root.setPage(1) }
                        }
                      }

                      BorderSurface {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Style.space(150)
                        color: Style.normalFillFor(root.foreground, Color.accent)
                        borderSpec: Border.controlSpec("normal", root.foreground, Color.accent)
                        padding: Style.spacing.panelPadding
                        Column {
                          anchors.fill: parent
                          anchors.margins: parent.contentLeftInset
                          spacing: Style.spacing.sm
                          Text { text: "󰀻  PROGRAMS"; color: root.selectedText; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                          Text { text: root.programsLoading && root.counts.total === 0 ? "Scanning…" : root.counts.total + " visible items"; color: root.foreground; font.family: Style.font.family; font.pixelSize: Style.font.title; font.bold: true }
                          Text { width: parent.width; text: root.counts.app + " apps · " + root.counts.webapp + " web · " + root.counts.plugin + " plugins · " + root.counts.tui + " TUIs"; color: root.mutedText; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; wrapMode: Text.WordWrap }
                          Item { width: 1; height: Style.spacing.xs }
                          Button { text: "Browse programs"; iconText: "󰁔"; onClicked: root.setPage(2) }
                        }
                      }

                      BorderSurface {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Style.space(150)
                        color: Style.normalFillFor(root.foreground, Color.accent)
                        borderSpec: Border.controlSpec("normal", root.foreground, Color.accent)
                        padding: Style.spacing.panelPadding
                        Column {
                          anchors.fill: parent
                          anchors.margins: parent.contentLeftInset
                          spacing: Style.spacing.sm
                          Text { text: Model.statusIcon(root.overall.status) + "  OMAPANEL DOCTOR"; color: root.statusColor(root.overall.status); font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                          Text { text: root.healthLoading && root.healthRaw.length === 0 ? "Checking…" : root.overall.label; color: root.foreground; font.family: Style.font.family; font.pixelSize: Style.font.title; font.bold: true }
                          Text { width: parent.width; text: root.overall.count > 0 ? root.overall.count + " of " + root.healthRaw.length + " checks need attention" : root.healthRaw.length + " diagnostic checks completed"; color: root.mutedText; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; wrapMode: Text.WordWrap }
                          Item { width: 1; height: Style.spacing.xs }
                          Button { text: "View Doctor"; iconText: "󰁔"; onClicked: root.setPage(3) }
                        }
                      }
                    }

                    PanelSectionHeader {
                      width: parent.width
                      text: "QUICK HANDOFFS"
                      foreground: root.foreground
                      fontFamily: Style.font.family
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
                        Text { text: "Use the tools already trusted by Omarchy"; color: root.foreground; font.family: Style.font.family; font.pixelSize: Style.font.subtitle; font.bold: true }
                        Text { width: parent.width; text: "Every handoff is previewed first. OmaPanel never becomes a second package manager."; color: root.mutedText; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; wrapMode: Text.WordWrap }
                        Row {
                          spacing: Style.spacing.sm
                          Button { text: "Run update"; iconText: "󰑐"; bordered: true; onClicked: root.requestAction("update", "_") }
                          Button { text: "Restart shell"; iconText: "󰑓"; bordered: true; onClicked: root.requestAction("restart-shell", "_") }
                          Button { text: "Copy report"; iconText: "󰆏"; bordered: true; onClicked: root.requestAction("copy-report", "_") }
                        }
                      }
                    }

                    Row {
                      width: parent.width
                      spacing: Style.spacing.md
                      Text { text: "󰌾"; color: root.selectedText; font.family: Style.font.family; font.pixelSize: Style.font.icon }
                      Text { width: parent.width - Style.space(28); text: "Safe by default · collection is privilege-free, protected components stay protected, and changes require confirmation."; color: root.mutedText; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
                    }
                  }
                }

                // ---------------------------------------------- Appearance
                QQC.ScrollView {
                  id: appearanceScroll
                  clip: true
                  rightPadding: Style.space(18)
                  QQC.ScrollBar.horizontal.policy: QQC.ScrollBar.AlwaysOff
                  QQC.ScrollBar.vertical: PersistentScrollBar {
                    parent: appearanceScroll
                    anchors.top: appearanceScroll.top
                    anchors.right: appearanceScroll.right
                    anchors.bottom: appearanceScroll.bottom
                  }

                  Column {
                    width: appearanceScroll.availableWidth
                    spacing: Style.space(14)

                    Row {
                      width: parent.width
                      spacing: Style.spacing.md
                      Column {
                        width: parent.width - appearanceRefresh.width - parent.spacing
                        spacing: Style.spacing.xs
                        Text { text: "Appearance"; color: root.foreground; font.family: Style.font.family; font.pixelSize: Style.font.title; font.bold: true }
                        Text { width: parent.width; text: "See what is active, change stable settings here, and hand richer choices back to Omarchy."; color: root.mutedText; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
                      }
                      Button {
                        id: appearanceRefresh
                        iconText: "󰑐"
                        iconSpinning: root.appearanceLoading
                        tooltipText: "Refresh (Ctrl+R)"
                        focusable: true
                        onClicked: root.refreshAppearance()
                      }
                    }

                    Text {
                      visible: root.appearanceError !== "" || root.appearance.errors.length > 0
                      width: parent.width
                      text: root.appearanceError !== "" ? root.appearanceError
                        : root.appearance.errors.length + " appearance provider" + (root.appearance.errors.length === 1 ? " is" : "s are") + " unavailable. Other controls still work."
                      color: Color.urgent
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption
                      wrapMode: Text.WordWrap
                    }

                    PanelSectionHeader { width: parent.width; text: "STYLE"; foreground: root.foreground; fontFamily: Style.font.family }

                    BorderSurface {
                      width: parent.width
                      implicitHeight: Math.max(backgroundPreview.implicitHeight, styleDetails.implicitHeight) + Style.spacing.panelPadding * 2
                      color: Style.normalFillFor(root.foreground, Color.accent)
                      borderSpec: Border.controlSpec("normal", root.foreground, Color.accent)
                      padding: Style.spacing.panelPadding

                      Row {
                        anchors.fill: parent
                        anchors.margins: parent.contentLeftInset
                        spacing: Style.spacing.lg

                        BorderSurface {
                          id: backgroundPreview
                          width: root.narrow ? Style.space(130) : Style.space(180)
                          height: Style.space(112)
                          color: Style.selectedFillFor(root.foreground, Color.accent)
                          borderSpec: Border.controlSpec("normal", root.foreground, Color.accent)
                          radius: Style.cornerRadius
                          clip: true

                          Image {
                            anchors.fill: parent
                            source: root.appearance.background.path === "" ? "" : "file://" + root.appearance.background.path
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: false
                          }
                          Text {
                            anchors.centerIn: parent
                            visible: root.appearance.background.path === ""
                            text: "󰋩"
                            color: root.selectedText
                            font.family: Style.font.family
                            font.pixelSize: Style.font.displayLarge
                          }
                        }

                        Column {
                          id: styleDetails
                          width: parent.width - backgroundPreview.width - parent.spacing
                          spacing: Style.spacing.sm
                          Text { text: root.appearance.theme.state === "ok" ? root.appearance.theme.current : "Theme unavailable"; color: root.foreground; font.family: Style.font.family; font.pixelSize: Style.font.title; font.bold: true; elide: Text.ElideRight; width: parent.width }
                          Text { text: root.appearance.background.state === "ok" ? root.appearance.background.current : "Background unavailable"; color: root.mutedText; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; elide: Text.ElideRight; width: parent.width }
                          Text { text: "Selection stays in Omarchy’s native pickers, then returns here."; color: root.mutedText; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap; width: parent.width }
                          Row {
                            spacing: Style.spacing.sm
                            Button { text: "Change theme"; iconText: "󰏘"; bordered: true; focusable: true; enabled: root.appearance.theme.state === "ok"; onClicked: root.requestAppearanceHandoff("theme") }
                            Button { text: "Change background"; iconText: "󰋩"; bordered: true; focusable: true; enabled: root.appearance.background.state === "ok"; onClicked: root.requestAppearanceHandoff("background") }
                          }
                        }
                      }
                    }

                    PanelSectionHeader { width: parent.width; text: "TYPOGRAPHY"; foreground: root.foreground; fontFamily: Style.font.family }

                    BorderSurface {
                      width: parent.width
                      implicitHeight: typographyColumn.implicitHeight + Style.spacing.panelPadding * 2
                      color: "transparent"
                      borderSpec: Border.controlSpec("normal", root.foreground, Color.accent)
                      padding: Style.spacing.panelPadding

                      Column {
                        id: typographyColumn
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: parent.contentLeftInset
                        spacing: Style.spacing.md

                        Row {
                          width: parent.width
                          spacing: Style.spacing.md
                          SearchableDropdown {
                            id: fontDropdown
                            width: parent.width - addFontButton.width - parent.spacing
                            label: "INSTALLED FONT"
                            value: root.appearance.font.current
                            options: root.appearance.font.installed
                            foreground: root.foreground
                            background: Color.popups.background
                            popupBorder: Color.popups.border
                            fontFamily: Style.font.family
                            enabled: root.appearance.font.state === "ok" && !root.appearanceBusy
                            opacity: enabled ? 1 : 0.45
                            onChanged: function(value) { root.requestAppearanceSetting("font", value) }
                            Connections {
                              target: root
                              function onAppearanceChanged() { fontDropdown.value = root.appearance.font.current }
                            }
                          }
                          Button {
                            id: addFontButton
                            anchors.bottom: parent.bottom
                            text: "Add fonts"
                            iconText: "󰛖"
                            bordered: true
                            focusable: true
                            enabled: !root.appearanceBusy
                            onClicked: root.requestAppearanceHandoff("font-install")
                          }
                        }

                        BorderSurface {
                          width: parent.width
                          implicitHeight: fontSample.implicitHeight + Style.spacing.md * 2
                          color: Style.normalFillFor(root.foreground, Color.accent)
                          borderSpec: Border.controlSpec("normal", root.foreground, Color.accent)
                          padding: Style.spacing.md
                          Text {
                            id: fontSample
                            anchors.fill: parent
                            anchors.margins: parent.contentLeftInset
                            text: "The quick brown fox · 0123456789 · {}[]<>"
                            color: root.foreground
                            font.family: root.appearance.font.current === "Unknown" ? Style.font.family : root.appearance.font.current
                            font.pixelSize: Style.font.body
                            elide: Text.ElideRight
                          }
                        }

                        Text {
                          text: "TEXT SIZE  ·  " + (root.appearance.textSize.state === "ok" ? root.appearance.textSize.currentPx + "px" : "Unavailable")
                          color: root.mutedText
                          font.family: Style.font.family
                          font.pixelSize: Style.font.caption
                          font.bold: true
                        }

                        BorderSurface {
                          id: textSizeControl
                          width: parent.width
                          height: Style.space(48)
                          activeFocusOnTab: true
                          enabled: root.appearance.textSize.state === "ok" && !root.appearanceBusy
                          opacity: enabled ? 1 : 0.45
                          color: Style.controlFill(activeFocus, textSizeHover.hovered, root.foreground, Color.accent)
                          borderSpec: Border.controlSpec(activeFocus ? "focus" : (textSizeHover.hovered ? "hover-cursor" : "normal"), root.foreground, Color.accent)
                          radius: Style.cornerRadius

                          HoverHandler { id: textSizeHover }
                          Keys.onPressed: function(event) {
                            if (event.key === Qt.Key_Left || event.key === Qt.Key_Down) { root.requestTextSizeDelta(-1); event.accepted = true }
                            else if (event.key === Qt.Key_Right || event.key === Qt.Key_Up) { root.requestTextSizeDelta(1); event.accepted = true }
                          }
                          PanelSlider {
                            anchors.fill: parent
                            anchors.leftMargin: Style.spacing.md
                            anchors.rightMargin: Style.spacing.md
                            minimum: 0
                            maximum: root.appearance.textSize.stops.length - 1
                            step: 1
                            integer: true
                            tickCount: root.appearance.textSize.stops.length
                            value: Model.textSizeIndex(root.appearance.textSize.stops, root.appearance.textSize.currentPx)
                            trackColor: Style.selectedFillFor(root.foreground, Color.accent)
                            fillColor: root.foreground
                            knobColor: root.foreground
                            tickColor: root.background
                            onReleased: function(value) {
                              var index = Math.max(0, Math.min(root.appearance.textSize.stops.length - 1, Math.round(value)))
                              root.requestAppearanceSetting("text-size", root.appearance.textSize.stops[index])
                            }
                          }
                          MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.NoButton
                            onWheel: function(event) {
                              var distance = event.pixelDelta.y !== 0
                                ? -event.pixelDelta.y
                                : -event.angleDelta.y / 2
                              if (distance !== 0) root.scrollAppearance(distance)
                              event.accepted = true
                            }
                          }
                        }
                      }
                    }

                    PanelSectionHeader { width: parent.width; text: "BAR"; foreground: root.foreground; fontFamily: Style.font.family }

                    BorderSurface {
                      width: parent.width
                      implicitHeight: barColumn.implicitHeight + Style.spacing.panelPadding * 2
                      color: "transparent"
                      borderSpec: Border.controlSpec("normal", root.foreground, Color.accent)
                      padding: Style.spacing.panelPadding
                      opacity: root.appearance.bar.state === "ok" ? 1 : 0.45

                      Column {
                        id: barColumn
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: parent.contentLeftInset
                        spacing: Style.spacing.md

                        Text { text: "POSITION"; color: root.mutedText; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                        Row {
                          width: parent.width
                          spacing: Style.spacing.sm
                          Repeater {
                            model: ["top", "bottom", "left", "right"]
                            delegate: Button {
                              required property string modelData
                              width: (parent.width - parent.spacing * 3) / 4
                              text: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                              selected: root.appearance.bar.position === modelData
                              bordered: true
                              focusable: true
                              enabled: root.appearance.bar.state === "ok" && !root.appearanceBusy
                              onClicked: root.requestAppearanceSetting("bar-position", modelData)
                            }
                          }
                        }

                        Row {
                          width: parent.width
                          spacing: Style.spacing.md
                          Toggle {
                            width: (parent.width - parent.spacing) / 2
                            label: "Show bar"
                            description: "The same visibility setting as Super+Shift+Space."
                            checked: root.appearance.bar.visible
                            enabled: root.appearance.bar.state === "ok" && !root.appearanceBusy
                            foreground: root.foreground
                            fontFamily: Style.font.family
                            onClicked: root.requestAppearanceSetting("bar-visible", !root.appearance.bar.visible)
                          }
                          Toggle {
                            width: (parent.width - parent.spacing) / 2
                            label: "Transparent"
                            description: "Let the desktop show through the bar surface."
                            checked: root.appearance.bar.transparent
                            enabled: root.appearance.bar.state === "ok" && !root.appearanceBusy
                            foreground: root.foreground
                            fontFamily: Style.font.family
                            onClicked: root.requestAppearanceSetting("bar-transparency", !root.appearance.bar.transparent)
                          }
                        }
                      }
                    }

                    PanelSectionHeader { width: parent.width; text: "DISPLAYS"; foreground: root.foreground; fontFamily: Style.font.family }

                    BorderSurface {
                      width: parent.width
                      implicitHeight: displayRow.implicitHeight + Style.spacing.panelPadding * 2
                      color: Style.normalFillFor(root.foreground, Color.accent)
                      borderSpec: Border.controlSpec("normal", root.foreground, Color.accent)
                      padding: Style.spacing.panelPadding

                      Row {
                        id: displayRow
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: parent.contentLeftInset
                        spacing: Style.spacing.md
                        Text { text: root.appearance.display.count > 1 ? "󰍺" : "󰍹"; color: root.selectedText; font.family: Style.font.family; font.pixelSize: Style.font.display; anchors.verticalCenter: parent.verticalCenter }
                        Column {
                          width: parent.width - parent.children[0].width - displayButton.width - parent.spacing * 2
                          spacing: Style.spacing.xs
                          Text { text: root.appearance.display.state === "ok" ? "Display" : "Display unavailable"; color: root.foreground; font.family: Style.font.family; font.pixelSize: Style.font.subtitle; font.bold: true }
                          Text { width: parent.width; text: Model.displaySummary(root.appearance.display); color: root.mutedText; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
                          Text { visible: root.appearance.display.brightnessAvailable; text: root.appearance.display.brightnessPercent + "% brightness"; color: root.mutedText; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                        }
                        Button {
                          id: displayButton
                          text: "Open controls"
                          iconText: "󰁔"
                          bordered: true
                          focusable: true
                          enabled: root.appearance.display.state === "ok"
                          anchors.verticalCenter: parent.verticalCenter
                          onClicked: root.requestAppearanceHandoff("display")
                        }
                      }
                    }

                    Text {
                      width: parent.width
                      text: "Resolution, refresh rate, arrangement, and persistent monitor profiles remain planned for Devices."
                      color: root.mutedText
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption
                      wrapMode: Text.WordWrap
                      horizontalAlignment: Text.AlignHCenter
                    }
                  }
                }

                // ------------------------------------------------ Programs
                ColumnLayout {
                  spacing: Style.spacing.sm

                  RowLayout {
                    Layout.fillWidth: true
                    ColumnLayout {
                      Layout.fillWidth: true
                      spacing: 0
                      Text { text: "Programs"; color: root.foreground; font.family: Style.font.family; font.pixelSize: Style.font.title; font.bold: true }
                      Text { text: "Find software by what it is, then hand removal to the right tool."; color: root.mutedText; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                    }
                    Button {
                      iconText: "󰑐"
                      iconSpinning: root.programsLoading
                      tooltipText: "Refresh (Ctrl+R)"
                      onClicked: root.refreshPrograms()
                    }
                  }

                  RowLayout {
                    Layout.fillWidth: true
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
                          { label: "Launchers", value: "launcher" }, { label: "Packages", value: "package" },
                          { label: "Mise", value: "mise" }
                        ]
                        delegate: Button {
                          required property var modelData
                          text: modelData.label
                          selected: root.programFilter === modelData.value
                          visible: (modelData.value !== "package" && modelData.value !== "mise") || root.showAdvanced
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
                      text: root.programsLoading ? "Scanning… " + programModel.count + " found" : programModel.count + " result" + (programModel.count === 1 ? "" : "s")
                      color: root.mutedText
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption
                    }
                    Button {
                      text: root.showAdvanced ? "Hide advanced" : "Advanced tools"
                      iconText: "󰒓"
                      selected: root.showAdvanced
                      onClicked: {
                        root.showAdvanced = !root.showAdvanced
                        if (!root.showAdvanced && (root.programFilter === "package" || root.programFilter === "mise")) root.programFilter = "all"
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
                        QQC.ScrollBar.vertical: PersistentScrollBar {
                          id: programScrollbar
                          parent: programList
                          anchors.top: programList.top
                          anchors.right: programList.right
                          anchors.bottom: programList.bottom
                        }
                        delegate: CursorSurface {
                          id: programDelegate
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
                            ProgramIcon { row: programDelegate.row; iconSize: Style.space(32) }
                            ColumnLayout {
                              Layout.fillWidth: true
                              spacing: 0
                              Text { Layout.fillWidth: true; text: programDelegate.row ? programDelegate.row.name : ""; color: root.foreground; font.family: Style.font.family; font.pixelSize: Style.font.body; font.bold: true; elide: Text.ElideRight }
                              Text { Layout.fillWidth: true; text: programDelegate.row ? programDelegate.row.source + (programDelegate.row.version ? " · " + programDelegate.row.version : "") : ""; color: root.mutedText; font.family: Style.font.family; font.pixelSize: Style.font.caption; elide: Text.ElideRight }
                            }
                            Text { visible: programDelegate.row && programDelegate.row.protected === true; text: "󰌾"; color: root.mutedText; font.family: Style.font.family; font.pixelSize: Style.font.iconSmall }
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

                      LoadingState {
                        anchors.centerIn: parent
                        visible: root.programsLoading && programModel.count === 0
                        label: "Building your software inventory…"
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
                        ProgramIcon { row: root.selectedProgramRow; iconSize: Style.space(52) }
                        Text { Layout.fillWidth: true; text: root.selectedProgramRow ? root.selectedProgramRow.name : ""; color: root.foreground; font.family: Style.font.family; font.pixelSize: Style.font.title; font.bold: true; wrapMode: Text.WordWrap }
                        Text { Layout.fillWidth: true; text: root.selectedProgramRow ? Model.kindLabel(root.selectedProgramRow.kind) + " · " + root.selectedProgramRow.source : ""; color: root.mutedText; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
                        PanelSeparator { Layout.fillWidth: true; foreground: root.foreground }
                        PanelSectionHeader { Layout.fillWidth: true; text: "DETAILS"; foreground: root.foreground; fontFamily: Style.font.family }
                        Text { Layout.fillWidth: true; text: root.selectedProgramRow && root.selectedProgramRow.description ? root.selectedProgramRow.description : "No description is available."; color: root.foreground; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; wrapMode: Text.WordWrap }
                        Text { Layout.fillWidth: true; text: root.selectedProgramRow ? "Managed by: " + root.selectedProgramRow.source + "\nID: " + root.selectedProgramRow.sourceId + (root.selectedProgramRow.version ? "\nVersion: " + root.selectedProgramRow.version : "") + (root.selectedProgramRow.kind === "mise" ? "\nState: " + (root.selectedProgramRow.active ? "Active" : "Installed, inactive") : "") : ""; color: root.mutedText; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WrapAnywhere }
                        Text {
                          visible: root.selectedProgramRow && root.selectedProgramRow.impactLauncherCount > 0
                          Layout.fillWidth: true
                          text: Model.launcherImpactText(root.selectedProgramRow)
                          color: root.foreground
                          font.family: Style.font.family
                          font.pixelSize: Style.font.bodySmall
                          wrapMode: Text.WordWrap
                        }
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

                // --------------------------------------------------- Doctor
                ColumnLayout {
                  spacing: Style.spacing.sm

                  RowLayout {
                    Layout.fillWidth: true
                    ColumnLayout {
                      Layout.fillWidth: true
                      spacing: 0
                      Text { text: "Doctor"; color: root.foreground; font.family: Style.font.family; font.pixelSize: Style.font.title; font.bold: true }
                      Text { text: "Diagnose and explain; treatment stays in established Omarchy workflows."; color: root.mutedText; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                    }
                    BorderSurface {
                      visible: root.healthRaw.length > 0
                      implicitWidth: healthSummary.implicitWidth + Style.space(16)
                      implicitHeight: healthSummary.implicitHeight + Style.space(8)
                      color: Style.normalFillFor(root.foreground, Color.accent)
                      borderSpec: Border.controlSpec("normal", root.foreground, Color.accent)
                      radius: Style.cornerRadius
                      Text {
                        id: healthSummary
                        anchors.centerIn: parent
                        text: Model.statusIcon(root.overall.status) + "  " + root.overall.label
                        color: root.statusColor(root.overall.status)
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        font.bold: true
                      }
                    }
                    Button { text: "Copy shareable report"; iconText: "󰆏"; onClicked: root.requestAction("copy-report", "_") }
                    Button { text: root.healthLoading ? "Running…" : "Run Doctor"; iconText: "󰑐"; iconSpinning: root.healthLoading; tooltipText: "Run again (Ctrl+R)"; onClicked: root.refreshHealth() }
                  }

                  QQC.ScrollView {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Style.space(42)
                    QQC.ScrollBar.vertical.policy: QQC.ScrollBar.AlwaysOff
                    Row {
                      spacing: Style.spacing.xs
                      Repeater {
                        model: [
                          { label: "All", value: "all" }, { label: "Needs attention", value: "attention" },
                          { label: "Omarchy", value: "omarchy" }, { label: "Desktop", value: "desktop" },
                          { label: "Services", value: "services" }, { label: "Storage", value: "storage" },
                          { label: "Recovery", value: "recovery" }, { label: "OmaPanel", value: "omapanel" }
                        ]
                        delegate: Button {
                          required property var modelData
                          text: modelData.label
                          selected: root.doctorFilter === modelData.value
                          onClicked: {
                            root.doctorFilter = modelData.value
                            root.selectedHealthIndex = 0
                            root.detailOpen = false
                            root.rebuildHealth()
                          }
                        }
                      }
                    }
                  }

                  RowLayout {
                    Layout.fillWidth: true
                    Text {
                      Layout.fillWidth: true
                      text: root.healthLoading ? "Running privilege-free checks…" : healthModel.count + " check" + (healthModel.count === 1 ? "" : "s") + " in this view"
                      color: root.mutedText
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption
                    }
                    Text {
                      visible: root.doctorGeneratedAt !== ""
                      text: "Last run " + root.doctorGeneratedAt.replace("T", " ").replace("Z", " UTC")
                      color: root.mutedText
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption
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
                        id: healthList
                        anchors.fill: parent
                        clip: true
                        spacing: Style.spacing.xs
                        model: healthModel
                        section.property: "category"
                        section.criteria: ViewSection.FullString
                        section.delegate: Item {
                          required property string section
                          width: healthList.width
                          height: Style.space(32)
                          Text {
                            anchors.left: parent.left
                            anchors.leftMargin: Style.spacing.sm
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: Style.spacing.xs
                            text: parent.section.toUpperCase()
                            color: root.mutedText
                            font.family: Style.font.family
                            font.pixelSize: Style.font.caption
                            font.bold: true
                          }
                        }
                        QQC.ScrollBar.vertical: PersistentScrollBar {
                          id: healthScrollbar
                          parent: healthList
                          anchors.top: healthList.top
                          anchors.right: healthList.right
                          anchors.bottom: healthList.bottom
                        }
                        delegate: CursorSurface {
                          id: healthDelegate
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
                            Text { text: Model.statusIcon(healthDelegate.row ? healthDelegate.row.status : "unknown"); color: root.statusColor(healthDelegate.row ? healthDelegate.row.status : "unknown"); font.family: Style.font.family; font.pixelSize: Style.font.iconLarge }
                            ColumnLayout {
                              Layout.fillWidth: true
                              spacing: 0
                              Text { Layout.fillWidth: true; text: healthDelegate.row ? healthDelegate.row.title : ""; color: root.foreground; font.family: Style.font.family; font.pixelSize: Style.font.body; font.bold: true; elide: Text.ElideRight }
                              Text { Layout.fillWidth: true; text: healthDelegate.row ? healthDelegate.row.summary : ""; color: root.mutedText; font.family: Style.font.family; font.pixelSize: Style.font.caption; elide: Text.ElideRight }
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
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.healthError || "No Doctor results match this view."; color: root.foreground; font.family: Style.font.family; font.pixelSize: Style.font.body }
                      }

                      LoadingState {
                        anchors.centerIn: parent
                        visible: root.healthLoading && healthModel.count === 0
                        label: "Running Doctor's read-only checks…"
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
                        PanelSectionHeader { Layout.fillWidth: true; text: "WHAT OMAPANEL FOUND"; foreground: root.foreground; fontFamily: Style.font.family }
                        QQC.ScrollView {
                          Layout.fillWidth: true
                          Layout.fillHeight: true
                          Text { width: parent.width; text: root.selectedHealthRow ? root.selectedHealthRow.detail : ""; color: root.foreground; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; wrapMode: Text.WrapAnywhere }
                        }
                        PanelSectionHeader { Layout.fillWidth: true; text: "RECOMMENDED NEXT STEP"; foreground: root.foreground; fontFamily: Style.font.family }
                        Text { Layout.fillWidth: true; text: root.selectedHealthRow ? root.selectedHealthRow.recommendation : ""; color: root.foreground; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; wrapMode: Text.WordWrap }
                        Button {
                          Layout.fillWidth: true
                          visible: root.selectedHealthRow && root.selectedHealthRow.actionAdapter
                          text: root.selectedHealthRow ? root.selectedHealthRow.actionLabel : ""
                          iconText: "󰁔"
                          bordered: true
                          onClicked: root.requestSelectedAction()
                        }
                        Text { Layout.fillWidth: true; text: "Doctor never requests privilege or applies treatment."; color: root.mutedText; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter }
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
            var impact = Model.previewLauncherImpact(p.impactedLaunchers)
            return String(p.label || "Continue") + "?\n\n" + String(p.workflow || "")
              + impact
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
          implicitWidth: Math.min(toastRow.implicitWidth + Style.space(36), parent.width - Style.space(30))
          implicitHeight: Math.max(toastText.implicitHeight, undoButton.implicitHeight) + Style.spacing.md * 2
          color: Color.popups.background
          borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, 1)
          padding: Style.spacing.md
          Row {
            id: toastRow
            anchors.centerIn: parent
            spacing: Style.spacing.md
            Text {
              id: toastText
              anchors.verticalCenter: parent.verticalCenter
              width: Math.min(implicitWidth, keyCatcher.width - undoButton.width - Style.space(110))
              text: root.toastMessage
              color: Color.popups.text
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              wrapMode: Text.WordWrap
              horizontalAlignment: Text.AlignHCenter
            }
            Button {
              id: undoButton
              visible: root.undoAvailable
              anchors.verticalCenter: parent.verticalCenter
              text: "Undo"
              iconText: "󰕌"
              bordered: true
              focusable: true
              foreground: Color.popups.text
              onClicked: root.runUndo()
            }
          }
        }
      }
    }
  }
}
