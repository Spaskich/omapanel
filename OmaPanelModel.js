.pragma library

function normalized(value) {
  return String(value || "").toLowerCase().trim()
}

function emptyAppearance() {
  return {
    generatedAt: "",
    theme: { state: "unavailable", current: "Unknown" },
    background: { state: "unavailable", current: "Unknown", path: "" },
    font: { state: "unavailable", current: "Unknown", installed: [] },
    textSize: { state: "unavailable", currentPx: 0, stops: [9, 10, 11, 12, 14, 16, 20] },
    bar: { state: "unavailable", visible: true, position: "top", transparent: false },
    display: {
      state: "unavailable", focusedMonitor: "", scale: "", brightnessAvailable: false,
      brightnessPercent: 0, count: 0, enabledCount: 0, focusedWidth: 0, focusedHeight: 0, displays: []
    },
    errors: []
  }
}

function normalizeAppearance(payload) {
  if (!payload || Number(payload.schemaVersion) !== 1) return null
  var base = emptyAppearance()
  var theme = payload.theme || {}
  var background = payload.background || {}
  var font = payload.font || {}
  var textSize = payload.textSize || {}
  var bar = payload.bar || {}
  var display = payload.display || {}

  base.generatedAt = String(payload.generatedAt || "")
  base.theme = { state: String(theme.state || "unavailable"), current: String(theme.current || "Unknown") }
  base.background = {
    state: String(background.state || "unavailable"), current: String(background.current || "Unknown"),
    path: String(background.path || "")
  }
  base.font = {
    state: String(font.state || "unavailable"), current: String(font.current || "Unknown"),
    installed: Array.isArray(font.installed) ? font.installed.map(function(value) { return String(value) }) : []
  }
  base.textSize = {
    state: String(textSize.state || "unavailable"), currentPx: Number(textSize.currentPx) || 0,
    stops: Array.isArray(textSize.stops) && textSize.stops.length > 0
      ? textSize.stops.map(function(value) { return Number(value) }) : base.textSize.stops
  }
  base.bar = {
    state: String(bar.state || "unavailable"), visible: bar.visible !== false,
    position: String(bar.position || "top"), transparent: bar.transparent === true
  }
  base.display = {
    state: String(display.state || "unavailable"), focusedMonitor: String(display.focusedMonitor || ""),
    scale: String(display.scale || ""), brightnessAvailable: display.brightnessAvailable === true,
    brightnessPercent: Number(display.brightnessPercent) || 0, count: Number(display.count) || 0,
    enabledCount: Number(display.enabledCount) || 0, focusedWidth: Number(display.focusedWidth) || 0,
    focusedHeight: Number(display.focusedHeight) || 0,
    displays: Array.isArray(display.displays) ? display.displays : []
  }
  base.errors = Array.isArray(payload.errors) ? payload.errors : []
  return base
}

function appearanceValue(appearance, setting) {
  var state = appearance || emptyAppearance()
  switch (String(setting || "")) {
    case "font": return state.font.current
    case "text-size": return state.textSize.currentPx
    case "bar-position": return state.bar.position
    case "bar-transparency": return state.bar.transparent
    case "bar-visible": return state.bar.visible
    default: return null
  }
}

function textSizeIndex(stops, current) {
  var values = Array.isArray(stops) && stops.length > 0 ? stops : [9, 10, 11, 12, 14, 16, 20]
  var target = Number(current)
  var best = 0
  var distance = Infinity
  for (var i = 0; i < values.length; i++) {
    var nextDistance = Math.abs(Number(values[i]) - target)
    if (nextDistance < distance) { best = i; distance = nextDistance }
  }
  return best
}

function displaySummary(display) {
  var state = display || {}
  if (state.state !== "ok") return "Display controls unavailable"
  var count = Number(state.enabledCount) || 0
  var output = count + " active display" + (count === 1 ? "" : "s")
  if (state.focusedMonitor) output += " · " + state.focusedMonitor
  if (Number(state.focusedWidth) > 0 && Number(state.focusedHeight) > 0)
    output += " · " + state.focusedWidth + "×" + state.focusedHeight
  if (state.scale) output += " · " + state.scale + "×"
  return output
}

function emptyDevices() {
  return {
    generatedAt: "",
    display: { state: "unavailable", focusedMonitor: "", brightnessAvailable: false, brightnessPercent: 0, displays: [] },
    input: {
      state: "unavailable", mainKeyboard: null, keyboards: [], pointers: [], tablets: [], touchscreens: [], switches: [],
      touchpad: { present: false, name: "", enabled: false }
    },
    network: { state: "unavailable", type: "unknown", interface: "", ssid: "", signal: null, ip: "", prefix: "" },
    errors: []
  }
}

function normalizeDevices(payload) {
  if (!payload || Number(payload.schemaVersion) !== 1) return null
  var base = emptyDevices()
  var display = payload.display || {}
  var input = payload.input || {}
  var touchpad = input.touchpad || {}
  var network = payload.network || {}

  base.generatedAt = String(payload.generatedAt || "")
  base.display = {
    state: String(display.state || "unavailable"),
    focusedMonitor: String(display.focusedMonitor || ""),
    brightnessAvailable: display.brightnessAvailable === true,
    brightnessPercent: Number(display.brightnessPercent) || 0,
    displays: Array.isArray(display.displays) ? display.displays : []
  }
  base.input = {
    state: String(input.state || "unavailable"),
    mainKeyboard: input.mainKeyboard && typeof input.mainKeyboard === "object" ? input.mainKeyboard : null,
    keyboards: Array.isArray(input.keyboards) ? input.keyboards : [],
    pointers: Array.isArray(input.pointers) ? input.pointers : [],
    tablets: Array.isArray(input.tablets) ? input.tablets : [],
    touchscreens: Array.isArray(input.touchscreens) ? input.touchscreens : [],
    switches: Array.isArray(input.switches) ? input.switches : [],
    touchpad: {
      present: touchpad.present === true,
      name: String(touchpad.name || ""),
      enabled: touchpad.enabled === true
    }
  }
  base.network = {
    state: String(network.state || "unavailable"),
    type: String(network.type || "unknown"),
    interface: String(network.interface || ""),
    ssid: String(network.ssid || ""),
    signal: network.signal === null || network.signal === undefined ? null : Number(network.signal),
    ip: String(network.ip || ""),
    prefix: String(network.prefix || "")
  }
  base.errors = Array.isArray(payload.errors) ? payload.errors : []
  return base
}

function formatRefreshRate(value) {
  var hz = Number(value) || 0
  if (hz <= 0) return "Unknown refresh rate"
  var rounded = Math.round(hz * 100) / 100
  return String(rounded).replace(/\.0+$/, "") + " Hz"
}

function deviceDisplaySummary(display) {
  var state = display || {}
  if (state.state !== "ok") return "Display details unavailable"
  var records = Array.isArray(state.displays) ? state.displays : []
  var enabled = records.filter(function(row) { return row && row.enabled !== false }).length
  var focused = records.filter(function(row) { return row && row.focused === true })[0]
  var result = enabled + " active display" + (enabled === 1 ? "" : "s")
  if (focused && Number(focused.width) > 0 && Number(focused.height) > 0)
    result += " · " + Number(focused.width) + "×" + Number(focused.height)
  if (focused && Number(focused.refreshHz) > 0) result += " @ " + formatRefreshRate(focused.refreshHz)
  return result
}

function inputSummary(input) {
  var state = input || {}
  if (state.state !== "ok") return "Input details unavailable"
  var keyboard = state.mainKeyboard || null
  var parts = []
  if (keyboard && keyboard.keymap) parts.push(String(keyboard.keymap))
  var pointers = Array.isArray(state.pointers) ? state.pointers : []
  var mouseCount = pointers.filter(function(row) { return row && row.kind !== "touchpad" }).length
  if (mouseCount > 0) parts.push(mouseCount + " pointer" + (mouseCount === 1 ? "" : "s"))
  if (state.touchpad && state.touchpad.present) parts.push(state.touchpad.enabled ? "Touchpad on" : "Touchpad off")
  return parts.length > 0 ? parts.join(" · ") : "No input devices reported"
}

function normalizeAudioSnapshot(snapshot) {
  var state = snapshot || {}
  var outputVolume = Number(state.outputVolume) || 0
  var inputVolume = Number(state.inputVolume) || 0
  return {
    state: String(state.state || "unavailable"),
    outputName: String(state.outputName || "No output"),
    inputName: String(state.inputName || "No input"),
    outputVolume: Math.max(0, Math.round(outputVolume <= 1 ? outputVolume * 100 : outputVolume)),
    outputMuted: state.outputMuted === true,
    inputVolume: Math.max(0, Math.round(inputVolume <= 1 ? inputVolume * 100 : inputVolume)),
    inputMuted: state.inputMuted === true
  }
}

function audioSummary(audio) {
  var state = normalizeAudioSnapshot(audio)
  if (state.state !== "ok") return "Audio service unavailable"
  return state.outputName + " · " + (state.outputMuted ? "Muted" : state.outputVolume + "%")
}

function normalizeBluetoothSnapshot(snapshot) {
  var state = snapshot || {}
  return {
    state: String(state.state || "unavailable"),
    powered: state.powered === true,
    connectedNames: Array.isArray(state.connectedNames) ? state.connectedNames.map(function(value) { return String(value) }) : []
  }
}

function bluetoothSummary(bluetooth) {
  var state = normalizeBluetoothSnapshot(bluetooth)
  if (state.state !== "ok") return "Bluetooth unavailable"
  if (!state.powered) return "Bluetooth off"
  var count = state.connectedNames.length
  return count === 0 ? "On · No connected devices" : count + " connected · " + state.connectedNames.join(", ")
}

function normalizeNetworkSnapshot(snapshot) {
  var state = snapshot || {}
  var details = state.details || {}
  var type = String(state.type || details.type || "unknown")
  return {
    state: String(state.state || details.state || "unavailable"),
    type: type,
    wifiEnabled: state.wifiEnabled !== false,
    ssid: String(state.ssid || details.ssid || ""),
    signal: state.signal === null || state.signal === undefined ? details.signal : Number(state.signal),
    interface: String(state.interface || details.interface || ""),
    ip: String(state.ip || details.ip || ""),
    prefix: String(state.prefix || details.prefix || "")
  }
}

function networkSummary(network) {
  var state = normalizeNetworkSnapshot(network)
  if (state.state !== "ok") return "Network service unavailable"
  if (state.type === "disconnected") return state.wifiEnabled ? "Disconnected" : "Wi-Fi off"
  var name = state.type === "wifi" ? (state.ssid || "Wi-Fi") : "Ethernet"
  if (state.ip) name += " · " + state.ip + (state.prefix ? "/" + state.prefix : "")
  return name
}

function filterPrograms(programs, query, filter, showAdvanced) {
  var source = Array.isArray(programs) ? programs : []
  var needle = normalized(query)
  var selectedFilter = normalized(filter || "all")
  var out = []

  for (var i = 0; i < source.length; i++) {
    var row = source[i] || {}
    if (row.advanced === true && !showAdvanced) continue
    if (selectedFilter !== "all" && normalized(row.kind) !== selectedFilter) continue
    var haystack = normalized(row.searchText || [row.name, row.description, row.kind, row.source, row.sourceId].join(" "))
    if (needle !== "" && haystack.indexOf(needle) === -1) continue
    out.push(row)
  }

  out.sort(function(a, b) {
    return normalized(a.name).localeCompare(normalized(b.name))
  })
  return out
}

function programCounts(programs) {
  var result = { total: 0, app: 0, webapp: 0, tui: 0, plugin: 0, flatpak: 0, launcher: 0, package: 0, mise: 0 }
  var source = Array.isArray(programs) ? programs : []
  for (var i = 0; i < source.length; i++) {
    var row = source[i] || {}
    if (row.advanced === true) continue
    result.total++
    var key = normalized(row.kind)
    if (result[key] !== undefined) result[key]++
  }
  return result
}

function filterDoctor(checks, filter) {
  var source = Array.isArray(checks) ? checks : []
  var selected = normalized(filter || "all")
  if (selected === "all") return source.slice()
  if (selected === "attention") {
    return source.filter(function(row) {
      var status = normalized(row.status)
      return status === "error" || status === "warning" || status === "unknown"
    })
  }
  return source.filter(function(row) { return normalized(row.category) === selected })
}

function severityRank(status) {
  switch (normalized(status)) {
    case "error": return 4
    case "warning": return 3
    case "unknown": return 2
    case "info": return 1
    default: return 0
  }
}

function overallHealth(health) {
  var source = Array.isArray(health) ? health : []
  if (source.length === 0) return { status: "unknown", label: "Not checked", count: 0 }
  var worst = "ok"
  var actionable = 0
  for (var i = 0; i < source.length; i++) {
    var status = normalized(source[i].status)
    if (severityRank(status) > severityRank(worst)) worst = status
    if (status === "error" || status === "warning") actionable++
  }
  var label = worst === "ok" ? "All checks look good"
    : worst === "error" ? "Attention required"
    : worst === "warning" ? "Review recommended"
    : worst === "info" ? "Information available"
    : "Some checks are unknown"
  return { status: worst, label: label, count: actionable }
}

function clampIndex(index, count) {
  if (count <= 0) return 0
  return Math.max(0, Math.min(Number(index) || 0, count - 1))
}

function wrapIndex(index, delta, count) {
  if (count <= 0) return 0
  return ((clampIndex(index, count) + delta) % count + count) % count
}

function kindLabel(kind) {
  switch (normalized(kind)) {
    case "app": return "Application"
    case "webapp": return "Web App"
    case "tui": return "TUI"
    case "plugin": return "Plugin"
    case "flatpak": return "Flatpak"
    case "launcher": return "Launcher"
    case "package": return "Package"
    case "mise": return "Mise Tool"
    default: return "Software"
  }
}

function kindIcon(kind, fallback) {
  if (fallback) return fallback
  switch (normalized(kind)) {
    case "app": return "󰀻"
    case "webapp": return ""
    case "tui": return ""
    case "plugin": return "󰏗"
    case "flatpak": return ""
    case "launcher": return "󰍉"
    case "package": return "󰣇"
    case "mise": return "󰏗"
    default: return "󰏖"
  }
}

function launcherImpactText(row) {
  if (!row || Number(row.impactLauncherCount || 0) <= 0) return ""
  var namesText = String(row.impactLauncherNamesText || "")
  if (namesText === "" && Array.isArray(row.impactLauncherNames)) namesText = row.impactLauncherNames.join("\n")
  return Number(row.impactLauncherCount) + " launcher entr"
    + (Number(row.impactLauncherCount) === 1 ? "y" : "ies")
    + " discovered:\n" + namesText
}

function previewLauncherImpact(launchers) {
  if (!Array.isArray(launchers) || launchers.length === 0) return ""
  var names = []
  for (var i = 0; i < launchers.length; i++) names.push(String(launchers[i].name || launchers[i].id || "Unknown launcher"))
  return "\n\nLauncher entries affected (" + names.length + "):\n" + names.join("\n")
}

function statusIcon(status) {
  switch (normalized(status)) {
    case "ok": return "󰄬"
    case "error": return "󰅚"
    case "warning": return "󰀦"
    case "info": return "󰋼"
    default: return "󰋗"
  }
}

function escapeAction(dialogOpen, searchText, detailOpen) {
  if (dialogOpen) return "dialog"
  if (String(searchText || "") !== "") return "search"
  if (detailOpen) return "detail"
  return "close"
}
