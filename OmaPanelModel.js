.pragma library

function normalized(value) {
  return String(value || "").toLowerCase().trim()
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
