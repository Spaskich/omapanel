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

  function test_appearance() {
    var state = Model.normalizeAppearance({
      schemaVersion: 1,
      generatedAt: "now",
      theme: { state: "ok", current: "Tokyo Night" },
      background: { state: "ok", current: "Road", path: "/tmp/road.jpg" },
      font: { state: "ok", current: "Mono", installed: ["Mono", "Other"] },
      textSize: { state: "ok", currentPx: 13, stops: [9, 10, 12, 14, 16] },
      bar: { state: "ok", visible: false, position: "left", transparent: true },
      display: { state: "ok", focusedMonitor: "DP-1", scale: "1.25", brightnessAvailable: true, brightnessPercent: 40, count: 2, enabledCount: 1, focusedWidth: 2560, focusedHeight: 1440, displays: [] },
      errors: []
    })
    verify(state !== null)
    compare(Model.appearanceValue(state, "font"), "Mono")
    compare(Model.appearanceValue(state, "bar-visible"), false)
    compare(Model.textSizeIndex(state.textSize.stops, state.textSize.currentPx), 2)
    compare(Model.displaySummary(state.display), "1 active display · DP-1 · 2560×1440 · 1.25×")
    compare(Model.normalizeAppearance({schemaVersion: 2}), null)
  }

  function test_devices() {
    var state = Model.normalizeDevices({
      schemaVersion: 1,
      generatedAt: "now",
      display: {
        state: "ok", focusedMonitor: "DP-1", brightnessAvailable: true, brightnessPercent: 55,
        displays: [{name:"DP-1",label:"Desk 27",enabled:true,focused:true,width:2560,height:1440,refreshHz:143.998,x:0,y:0,scale:1,transform:0}]
      },
      input: {
        state: "ok", mainKeyboard: {name:"keyboard",keymap:"English (US)",main:true},
        keyboards: [{name:"keyboard"}], pointers: [{name:"mouse",kind:"mouse"}], tablets: [], touchscreens: [], switches: [],
        touchpad: {present:true,name:"touchpad",enabled:false}
      },
      network: {state:"ok",type:"wifi",interface:"wlan0",ssid:"Home",signal:73,ip:"192.0.2.24",prefix:"24"},
      errors: []
    })
    verify(state !== null)
    compare(Model.deviceDisplaySummary(state.display), "1 active display · 2560×1440 @ 144 Hz")
    compare(Model.inputSummary(state.input), "English (US) · 1 pointer · Touchpad off")
    compare(Model.formatRefreshRate(59.951), "59.95 Hz")
    compare(Model.normalizeDevices({schemaVersion: 2}), null)
  }

  function test_live_device_summaries() {
    var audio = Model.normalizeAudioSnapshot({state:"ok",outputName:"Speakers",outputVolume:0.42,outputMuted:false,inputName:"Microphone",inputVolume:0.8,inputMuted:true})
    compare(Model.audioSummary(audio), "Speakers · 42%")
    compare(audio.inputVolume, 80)
    compare(Model.audioSummary({state:"unavailable"}), "Audio service unavailable")

    var bluetooth = Model.normalizeBluetoothSnapshot({state:"ok",powered:true,connectedNames:["Headphones"]})
    compare(Model.bluetoothSummary(bluetooth), "1 connected · Headphones")
    compare(Model.bluetoothSummary({state:"ok",powered:false}), "Bluetooth off")

    var network = Model.normalizeNetworkSnapshot({state:"ok",type:"wifi",ssid:"Home",signal:75,wifiEnabled:true,details:{interface:"wlan0",ip:"192.0.2.24",prefix:"24"}})
    compare(Model.networkSummary(network), "Home · 192.0.2.24/24")
    compare(Model.networkSummary({state:"ok",type:"disconnected",wifiEnabled:false}), "Wi-Fi off")
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
    var row = { impactLauncherCount: 2, impactLauncherNames: ["Alpha", "Alpha Helper"], impactLauncherNamesText: "Alpha\nAlpha Helper" }
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
