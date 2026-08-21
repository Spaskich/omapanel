import QtQuick 2.15
import QtTest 1.3
import "../OmaPanelModel.js" as Model

TestCase {
  name: "OmaPanelModel"

  property var programs: [
    { name: "Alpha", kind: "app", source: "Pacman", sourceId: "alpha", advanced: false, searchText: "alpha app pacman" },
    { name: "Beta Web", kind: "webapp", source: "Omarchy", sourceId: "beta", advanced: false, searchText: "beta web omarchy" },
    { name: "Gamma", kind: "package", source: "AUR", sourceId: "gamma", advanced: true, searchText: "gamma package aur" },
    { name: "Node 22", kind: "mise", source: "Mise", sourceId: "node@22", advanced: true, searchText: "node 22 mise" }
  ]

  function test_filtering() {
    compare(Model.filterPrograms(programs, "", "all", false).length, 2)
    compare(Model.filterPrograms(programs, "beta", "all", false)[0].name, "Beta Web")
    compare(Model.filterPrograms(programs, "", "webapp", false).length, 1)
    compare(Model.filterPrograms(programs, "", "package", true).length, 1)
    compare(Model.filterPrograms(programs, "", "mise", true).length, 1)
  }

  function test_doctor_filtering() {
    var checks = [
      { category: "Omarchy", status: "ok" },
      { category: "Desktop", status: "warning" },
      { category: "Desktop", status: "unknown" },
      { category: "Storage", status: "error" }
    ]
    compare(Model.filterDoctor(checks, "all").length, 4)
    compare(Model.filterDoctor(checks, "attention").length, 3)
    compare(Model.filterDoctor(checks, "desktop").length, 2)
  }

  function test_launcher_impact() {
    var row = { impactLauncherCount: 2, impactLauncherNames: ["Alpha", "Alpha Helper"] }
    verify(Model.launcherImpactText(row).indexOf("2 launcher entries") !== -1)
    verify(Model.launcherImpactText(row).indexOf("Alpha Helper") !== -1)
    compare(Model.previewLauncherImpact([{name:"Alpha"}, {name:"Alpha Helper"}]), "\n\nLauncher entries affected (2):\nAlpha\nAlpha Helper")
  }

  function test_counts_hide_advanced() {
    var counts = Model.programCounts(programs)
    compare(counts.total, 2)
    compare(counts.app, 1)
    compare(counts.webapp, 1)
    compare(counts.package, 0)
  }

  function test_health() {
    var result = Model.overallHealth([
      { status: "ok" }, { status: "warning" }, { status: "info" }
    ])
    compare(result.status, "warning")
    compare(result.count, 1)
    compare(Model.overallHealth([]).status, "unknown")
  }

  function test_navigation() {
    compare(Model.wrapIndex(0, -1, 3), 2)
    compare(Model.wrapIndex(2, 1, 3), 0)
    compare(Model.clampIndex(9, 3), 2)
  }

  function test_escape_precedence() {
    compare(Model.escapeAction(true, "query", true), "dialog")
    compare(Model.escapeAction(false, "query", true), "search")
    compare(Model.escapeAction(false, "", true), "detail")
    compare(Model.escapeAction(false, "", false), "close")
  }
}
