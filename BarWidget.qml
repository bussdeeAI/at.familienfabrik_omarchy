// =============================================================================
//  BarWidget.qml · Familienfabrik.at · at.familienfabrik.omarchy
//
//  Kompakter Eintrag für die Quattro-Leiste (Omarchy 4).
//
//  · Zeigt NUR ein Symbol (♪) – der aktuelle Titel steht als Tooltip bereit.
//    So bleibt das Widget unabhängig vom Wiedergabe-Zustand kompakt und
//    verändert seine Breite nicht.
//  · Linksklick  → öffnet/schließt das Panel (Musik · Video · Lesen · Funk).
//  · Mittelklick → Play/Pause umschalten, ohne das Panel zu öffnen.
//  · Pulsierender Akzent-Punkt, während Musik läuft (Theme-Akzentfarbe).
//
//  Bewusst nur Qt Quick + Quickshell – keine externen QML-Abhängigkeiten.
//  System-Integration läuft ausschließlich über kurze Prozessaufrufe
//  (playerctl). Der Lebenszyklus des Panels folgt exakt dem offiziellen
//  Plugin-Vertrag der Quattro-Shell (open/close/toggle/closeForPopoutSwitch).
// =============================================================================

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui

import "Model.js" as Model

BarWidget {
    id: root

    // Muss exakt der ID aus manifest.json entsprechen.
    moduleName: "at.familienfabrik.omarchy"

    // ------------------- Öffentlicher Zustand (MPRIS) -----------------------
    // Leiste und Panel lesen diese Eigenschaften gemeinsam.
    property string trackTitle: ""           // aktueller Titel (leer = kein Player)
    property string trackArtist: ""          // Interpret
    property string playerStatus: "Stopped"  // Playing | Paused | Stopped
    property real trackVolume: 0.5           // normiert auf 0.0 – 1.0
    property real trackPosition: 0           // aktuelle Position in Sekunden
    property real trackDuration: 0           // Titellänge in Sekunden (0 = unbekannt)
    property bool shuffleOn: false            // Shuffle aktiv? (MPRIS)
    property string loopState: "None"         // None | Track | Playlist (MPRIS)

    readonly property bool isPlaying: playerStatus === "Playing"

    // ------------- Panel-Lifecycle (Vertrag der Quattro-Shell) --------------
    // Die Shell steuert das Widget u. a. über:
    //   omarchy-shell shell summon at.familienfabrik.omarchy
    //   omarchy-shell shell hide   at.familienfabrik.omarchy
    readonly property bool opened: panelLoader.item
        ? panelLoader.item.opened === true : false
    readonly property bool popoutSwitchClosing: panelLoader.item
        ? panelLoader.item.popoutSwitchClosing === true : false

    function open()  { if (panelLoader.item) panelLoader.item.open() }
    function close() { if (panelLoader.item) panelLoader.item.close() }
    function toggle() { if (panelLoader.item) panelLoader.item.toggle() }
    function closeForPopoutSwitch() {
        if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
    }

    // Reicht Leiste, Anker-Element und Widget an das Panel weiter.
    function injectPanel() {
        if (!panelLoader.item) return
        panelLoader.item.bar = root.bar
        panelLoader.item.anchorItem = button
        panelLoader.item.hostWidget = root
    }

    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight
    onBarChanged: injectPanel()

    // ------------------------- MPRIS-Polling ---------------------------------
    // Sieben kurze, wohldokumentierte playerctl-Aufrufe alle 2 Sekunden:
    //   1) Titel + Interpret, 2) Wiedergabestatus, 3) Lautstärke,
    //   4) aktuelle Position, 5) Titellänge, 6) Shuffle-Status, 7) Loop-Status.
    // Läuft kein MPRIS-Player, bleibt der alte Stand einfach stehen.
    Timer {
        id: mprisTimer
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            metaProc.running = true
            statusProc.running = true
            volumeProc.running = true
            positionProc.running = true
            durationProc.running = true
            shuffleStateProc.running = true
            loopStateProc.running = true
        }
    }

    // 1) Titel + Interpret abfragen (format-Template ist playerctl-Standard).
    Process {
        id: metaProc
        command: ["playerctl", "metadata", "--format",
                  "title={{title}}\nartist={{artist}}"]
        stdout: StdioCollector {
            onStreamFinished: {
                const fields = Model.parseFields(this.text)
                if (fields.title !== undefined) root.trackTitle = fields.title
                if (fields.artist !== undefined) root.trackArtist = fields.artist
            }
        }
    }

    // 2) Wiedergabestatus (gibt „Playing“, „Paused“ oder „Stopped“ aus).
    Process {
        id: statusProc
        command: ["playerctl", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                const s = this.text.trim()
                // Nur bekannte Stati übernehmen, Fehlerausgaben ignorieren.
                if (s === "Playing" || s === "Paused" || s === "Stopped")
                    root.playerStatus = s
            }
        }
    }

    // 3) Lautstärke (playerctl meldet je nach Version 0..1 oder Prozent).
    Process {
        id: volumeProc
        command: ["playerctl", "volume"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = Model.parseVolume(this.text)
                if (!isNaN(v)) root.trackVolume = v
            }
        }
    }

    // 4) Aktuelle Position in Sekunden (z. B. „83.26“).
    Process {
        id: positionProc
        command: ["playerctl", "position"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = parseFloat(String(this.text).trim())
                if (!isNaN(v) && v >= 0) root.trackPosition = v
            }
        }
    }

    // 5) Titellänge: mpris:length wird in Mikrosekunden gemeldet.
    Process {
        id: durationProc
        command: ["playerctl", "metadata", "mpris:length"]
        stdout: StdioCollector {
            onStreamFinished: {
                const s = String(this.text).trim()
                if (s === "") return // kein Player oder Feld fehlt
                const us = parseInt(s, 10)
                if (!isNaN(us) && us > 0) root.trackDuration = us / 1000000
            }
        }
    }

    // 6) Shuffle-Status (gibt „On“ oder „Off“ aus; unklar = ignorieren).
    Process {
        id: shuffleStateProc
        command: ["playerctl", "shuffle"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = Model.parseOnOff(this.text)
                if (v !== null) root.shuffleOn = v
            }
        }
    }

    // 7) Loop-Status (gibt „None“, „Track“ oder „Playlist“ aus).
    Process {
        id: loopStateProc
        command: ["playerctl", "loop"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = Model.parseLoop(this.text)
                if (v !== "") root.loopState = v
            }
        }
    }

    // ------------------------- Panel-Ladung ----------------------------------
    // Das Panel wird einmalig geladen und über injectPanel() verdrahtet.
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

    // ------------------------- Leisten-Knopf ----------------------------------
    // Nur ein Symbol (♪) – bewusst ohne Titel-Text, damit das Widget in der
    // Leiste stets kompakt bleibt. Der aktuelle Titel wandert ins Tooltip.
    WidgetButton {
        id: button
        anchors.fill: parent
        bar: root.bar

        text: "♪"
        tooltipText: root.trackTitle !== ""
            ? (root.trackArtist !== ""
              ? root.trackTitle + " · " + root.trackArtist
              : root.trackTitle)
            : "Familienfabrik.at – Musik, Video, Geschichten & Fabrik-Funk öffnen"

        onPressed: function (buttonCode) {
            // Linksklick: Panel öffnen/schließen.
            if (buttonCode === Qt.LeftButton) root.toggle()
            // Mittelklick: Play/Pause direkt aus der Leiste.
            if (buttonCode === Qt.MiddleButton) toggleProc.running = true
        }
    }

    // Mittelklick → Play/Pause (MPRIS).
    Process {
        id: toggleProc
        command: ["playerctl", "play-pause"]
    }
}
