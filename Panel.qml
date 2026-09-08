// =============================================================================
//  Panel.qml · Familienfabrik.at · at.familienfabrik.omarchy
//
//  Aufklappendes Quattro-Panel (max. ~480 px breit) mit vier Werkstätten:
//
//    ♪ Musik      – Now Playing + Play/Pause/Weiter/Zurück (playerctl/MPRIS),
//                   Spul-Balken, Shuffle & Loop, Lautstärke-Regler,
//                   Playlist-Browser mit ALLEN Playlisten der Website
//                   (Übersicht → Auswahl → Titel-Liste), sequenzielle
//                   Wiedergabe via mpv/M3U (ab gewähltem Titel),
//                   Free-URL-Import via yt-dlp.
//    ▶ Video      – mpv-Launcher für YouTube-Links/-Playlisten und Dateien,
//                   die Fabrik-Videos („Animierte Kinderlieder“, inkl.
//                   Untertitel) plus Verlauf „zuletzt genutzt“.
//    ✎ Lesen      – die Geschichten von familienfabrik.at/geschichten
//                   direkt im Panel (Buchreihe + Einzelnsgeschichten) –
//                   ohne Browser. Lesetext wird per curl geladen und
//                   im Panel gescrollt; der Browser bleibt optional.
//    Funk         – Fabrik-Funk-News-Feed (RSS) von familienfabrik.at,
//                   Beiträge klappen direkt im Panel auf (inkl. Text);
//                   darunter die Toolbox-Werkzeuge als Schnellstart.
//
//  Architektur: Alle Aktionen sind kurze Prozessaufrufe (playerctl, mpv,
//  yt-dlp, curl, xdg-open, bash) – keine externen QML-Bibliotheken. Startet
//  das Panel z. B. mpv, greift die MPRIS-Abfrage in BarWidget.qml den Titel
//  automatisch auf. Der Panel-Lifecycle folgt dem offiziellen Quattro-Vertrag
//  (KeyboardPanel + PanelKeyCatcher, ESC schließt das Panel).
//
//  Farben: Das Panel folgt dem Omarchy-Theme – Text via barForeground,
//  Akzente (aktiver Tab, Equalizer, Fortschritt, aktive Knöpfe) über die
//  Theme-Akzentfarbe Color.accent aus qs.Commons.
//
//  Die vier Tabs bleiben dauerhaft instanziiert (visible-Umschaltung statt
//  Loader) – so gehen Eingaben und Listen beim Wechseln nicht verloren.
// =============================================================================

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

import "Model.js" as Model

Panel {
    id: root

    moduleName: "at.familienfabrik.omarchy"
    manageIpc: false

    // Von BarWidget.injectPanel() gesetzte Anker.
    property var anchorItem: null
    property var hostWidget: null

    // ------------------------- Panel-Lifecycle --------------------------------
    function open()  { root.controller.show() }
    function close() { root.controller.hide() }
    function switchPanel(direction) {
        if (root.bar && typeof root.bar.switchPanelFrom === "function")
            return root.bar.switchPanelFrom(root.hostWidget || root, direction)
        return false
    }

    // Beim ersten Öffnen automatisch den Fabrik-Funk-Feed laden.
    onOpenedChanged: {
        if (opened && funkNews.length === 0 && funkStatus === "")
            fetchFunk()
    }
    Component.onCompleted: recentsLoadProc.running = true

    // ------------------------- Zustand ----------------------------------------
    property int activeTab: 0          // 0 Musik · 1 Video · 2 Lesen · 3 Funk
    // Musik: Titel-Liste der GEWÄHLTEN Playlist ( yt-dlp-Import).
    property var playlist: []          // [{ title, url }]
    property string playlistSource: "" // URL der importierten Playlist
    property string importState: ""    // "", "lädt…", Anzahl/Fehlermeldung
    property bool autoPlayOnLoad: false // nach dem Laden automatisch starten
    // Musik: Playlist-Browser (Übersicht aller Playlisten der Website).
    property var playlists: Model.FABRIK_PLAYLISTS  // [{ name, note, url }]
    property string playlistsState: "" // "", "lädt…", "N playlists", Fehler
    property string currentPlaylist: ""// Name der gewählten Playlist ("" = Übersicht)
    property string currentPlaylistPage: "" // Mitsing-Seite ("" = keine, nur beim Mitsingen-Lied)
    // Lesen: Geschichten-Katalog + gewählte Geschichte.
    property var stories: Model.GESCHICHTEN          // [{ kind, title, path }]
    property string storyTitle: ""   // "" = Liste, sonst Titel der offenen Geschichte
    property string storyPath: ""
    property string storyText: ""    // geladener Lesetext
    property string storyStatus: ""  // "", "lädt…", "nicht lesbar"
    // Video: Fabrik-Videos (YouTube-Playlist „Animierte Kinderlieder“).
    property var fabrikVideos: Model.FABRIK_VIDEOS   // [{ title, url }]
    // Funk: aufgeklappter Beitrag (Index, -1 = keiner).
    property int expandedNews: -1
    property var videoRecents: []      // [{ title, url }]
    property var funkNews: []          // [{ title, link, date, description }]
    property string funkStatus: ""     // "", "lädt…", "fehler", Anzahl
    property real pendingVolume: 0.5   // Reglerwert beim Ziehen
    property string videoHint: "enter im feld oder ▶ mpv startet die wiedergabe"

    // Nützliche Ableitungen (hostWidget = BarWidget mit MPRIS-Daten).
    readonly property bool playing: root.hostWidget
        ? root.hostWidget.isPlaying : false
    readonly property string nowTitle: root.hostWidget
        ? (root.hostWidget.trackTitle || "") : ""
    readonly property string nowArtist: root.hostWidget
        ? (root.hostWidget.trackArtist || "") : ""
    readonly property string statusText: root.hostWidget
        ? root.hostWidget.playerStatus : "Stopped"
    readonly property string monoFont: root.bar
        ? root.bar.fontFamily : Style.font.family
    readonly property real panelWidthHint: Style.space(480)
    // Anzeige-Lautstärke: beim Ziehen der Reglerwert, sonst der Player-Stand.
    readonly property real volumeShown: volArea.pressed
        ? pendingVolume
        : (root.hostWidget ? root.hostWidget.trackVolume : 0)
    // Fortschritt des aktuellen Titels (0..1; 0 solange Länge unbekannt).
    readonly property real trackFraction: (root.hostWidget && root.hostWidget.trackDuration > 0)
        ? Math.max(0, Math.min(1,
            (root.hostWidget.trackPosition || 0) / root.hostWidget.trackDuration))
        : 0
    // Shuffle/Loop-Stand (vom BarWidget gepollt, hier nur angezeigt).
    readonly property bool shuffleOn: root.hostWidget
        ? root.hostWidget.shuffleOn === true : false
    readonly property string loopState: root.hostWidget
        ? (root.hostWidget.loopState || "None") : "None"
    // Anzeige-Texte für den Loop-Zustand.
    readonly property string loopLabel: loopState === "Track"
        ? "titel" : loopState === "Playlist" ? "liste" : "aus"

    // ------------------------- Aktionen ---------------------------------------

    // Lautstärke ans MPRIS-System durchreichen (playerctl nimmt 0.00–1.00).
    function applyVolume() {
        const v = Math.max(0, Math.min(1, pendingVolume))
        setVolumeProc.command = ["playerctl", "volume", v.toFixed(2)]
        setVolumeProc.running = true
        if (root.hostWidget) root.hostWidget.trackVolume = v
    }
    function volumeDrag(x, w) {
        if (w <= 0) return
        pendingVolume = Math.max(0, Math.min(1, x / w))
        volumeDebounce.restart()
    }

    // Spulen: Klick auf den Fortschrittsbalken setzt die Position (Sekunden).
    function seekTo(fraction) {
        if (!root.hostWidget || !(root.hostWidget.trackDuration > 0)) return
        const target = Math.max(0, Math.min(1, fraction))
            * root.hostWidget.trackDuration
        seekProc.command = ["playerctl", "position", Math.round(target).toString()]
        seekProc.running = true
        // Sofortiges visuelles Feedback, bis der nächste Poll nachzieht.
        root.hostWidget.trackPosition = Math.round(target)
    }

    // Shuffle an/aus schalten (MPRIS „shuffle toggle“).
    function toggleShuffle() {
        shuffleSetProc.running = true
        // Sofortiges visuelles Feedback, bis der nächste Poll nachzieht.
        if (root.hostWidget) root.hostWidget.shuffleOn = !root.shuffleOn
    }

    // Loop-Zyklus durchschalten: aus → titel → liste → aus.
    function cycleLoop() {
        const order = ["None", "Track", "Playlist"]
        const idx = order.indexOf(root.loopState)
        const next = order[(idx + 1 + order.length) % order.length]
        loopSetProc.command = ["playerctl", "loop", next]
        loopSetProc.running = true
        // Sofortiges visuelles Feedback, bis der nächste Poll nachzieht.
        if (root.hostWidget) root.hostWidget.loopState = next
    }

    // ---- Playlist-Browser (Musik-Tab) ----------------------------------

    // Playlist aus der Übersicht wählen: Titel laden, automatisch die
    // GANZE Playlist nacheinander abspielen und die Titel-Liste anzeigen
    // (Klick auf einen Titel startet ab dort neu).
    function selectPlaylist(index) {
        const p = playlists[index]
        if (!p) return
        currentPlaylistPage = p.page !== undefined ? p.page : ""
        // Direkte Audio-Datei (Mitsingen-Lied): läuft ohne yt-dlp sofort –
        // Eintrag „file“ wird zur eintiteligen Wiedergabeliste und startet.
        if (p.file !== undefined && Model.isHttpUrl(p.file)) {
            currentPlaylist = p.name
            playlistSource = p.file
            playlist = [{ title: p.name, url: p.file }]
            importState = "direktes mp3 · läuft ohne yt-dlp"
            playFrom(0)
            return
        }
        if (!Model.isHttpUrl(p.url)) {
            importState = "playlist nicht abspielbar"
            return
        }
        currentPlaylist = p.name
        playlistSource = p.url
        importState = "lädt… „" + p.name + "“"
        autoPlayOnLoad = true
        playlist = []
        importProc.command = ["yt-dlp", "--flat-playlist", "--no-warnings", "-J", p.url]
        importProc.running = true
    }

    // Zurück zur Playlist-Übersicht (Wiedergabe läuft weiter).
    function backToPlaylists() {
        currentPlaylist = ""
        currentPlaylistPage = ""
        importState = ""
    }

    // ALLE Playlisten des SoundCloud-Profils dynamisch nachladen und an die
    // kuratierte Übersicht anhängen (Duplikate per URL überspringen).
    function loadAllPlaylists() {
        playlistsState = "lädt… playlists werden gelesen"
        listsProc.running = true
    }

    // Titel ab Index abspielen: M3U-Datei mit allen Titeln ab hier schreiben
    // und mpv starten (spielt die Liste nacheinander ab; ein neuer Start
    // stoppt die vorherige Wiedergabe – bewusst als „ein Player“-Prinzip).
    function playFrom(index) {
        if (playlist.length === 0) return
        const m3u = Model.buildM3U(playlist, index)
        importState = "spiele ab titel " + (Math.max(0, index) + 1)
        m3uPlayProc.command = ["bash", "-c",
            'mkdir -p "$HOME/.local/state/familienfabrik" && printf \'%s\\n\' "$1" > "$HOME/.local/state/familienfabrik/playlist.m3u" && exec mpv --no-video --playlist="$HOME/.local/state/familienfabrik/playlist.m3u"',
            "mpv", m3u]
        m3uPlayProc.running = true
    }

    // Ganze Playlist abspielen (Knopf in der Titel-Liste).
    function playPlaylist() {
        if (playlist.length > 0) { playFrom(0); return }
        // Fallback: Quelle direkt an mpv übergeben.
        if (!Model.isHttpUrl(playlistSource)) return
        mpvPlaylistProc.command = ["mpv", "--no-video", "--", playlistSource]
        mpvPlaylistProc.running = true
    }

    // Einzelnen Titel aus der Liste abspielen –Playlist läuft NACH diesem
    // Titel weiter (M3U beginnt hier).
    function playTrack(url) {
        for (let i = 0; i < playlist.length; i++) {
            if (playlist[i].url === url) { playFrom(i); return }
        }
        mpvMusicProc.command = ["mpv", "--no-video", "--", String(url)]
        mpvMusicProc.running = true
    }

    // Beliebige Playlist-URL importieren (Free-Import, yt-dlp versteht
    // SoundCloud, hearthis.at, YouTube-Mixe und mehr).
    function importPlaylist(url) {
        if (!Model.isHttpUrl(url)) {
            importState = "bitte eine http(s)-URL eingeben"
            return
        }
        currentPlaylist = "eigene quelle"
        currentPlaylistPage = ""
        playlistSource = url
        importState = "lädt… liste wird gelesen"
        autoPlayOnLoad = false
        importProc.command = ["yt-dlp", "--flat-playlist", "--no-warnings", "-J", url]
        importProc.running = true
    }

    // ---- Lesen (Geschichten-Tab) ----------------------------------------

    // Geschichte öffnen: Seite laden und im Panel anzeigen.
    function selectStory(index) {
        const s = stories[index]
        if (!s) return
        storyTitle = s.title
        storyPath = s.path
        storyText = ""
        storyStatus = "lädt… geschichte wird geholt"
        storyProc.command = ["curl", "-sL", "--max-time", "20",
                             "https://familienfabrik.at" + s.path]
        storyProc.running = true
    }

    // Zurück zur Geschichten-Liste.
    function backToStories() {
        storyTitle = ""
        storyPath = ""
        storyText = ""
        storyStatus = ""
    }

    // Aktuelle Geschichte im Browser öffnen (optionaler Umweg).
    function openStoryInBrowser() {
        if (storyPath !== "") openLink("https://familienfabrik.at" + storyPath)
    }

    // ---- Fabrik-Videos (Video-Tab) ---------------------------------------

    // Video aus der YouTube-Playlist „Animierte Kinderlieder“ abspielen;
    // mpv lädt vorhandene deutsche/englische Untertitel mit.
    function playFabrikVideo(url) {
        videoHint = "starte mpv… (untertitel: de/en, sofern vorhanden)"
        mpvVideoProc.command = ["mpv", "--slang=de,en", "--", String(url)]
        mpvVideoProc.running = true
    }

    // Ganze Fabrik-Videos-Playlist abspielen.
    function playAllVideos() {
        videoHint = "starte mpv… ganze wiedergabeliste"
        mpvVideoProc.command = ["mpv", "--slang=de,en", "--", Model.YOUTUBE_PLAYLIST_URL]
        mpvVideoProc.running = true
    }

    // Video/Datei mit mpv öffnen und in den Verlauf legen.
    // URLs direkt; „~/…“-Pfade werden über bash zu $HOME aufgelöst.
    function openVideo(url) {
        const u = String(url).trim()
        if (Model.isHttpUrl(u)) {
            mpvVideoProc.command = ["mpv", "--", u]
        } else if (u.indexOf("/") === 0 || u.indexOf("~/") === 0) {
            mpvVideoProc.command = ["bash", "-c",
                'exec mpv -- "${1/#~/$HOME}"', "mpv", u]
        } else {
            videoHint = "bitte eine URL (https://…) oder einen Pfad (/…, ~/…) eingeben"
            return
        }
        videoHint = "starte mpv…"
        mpvVideoProc.running = true
        pushRecent(u)
    }

    // Verlauf pflegen: neueste vorne, Duplikate entfernen, max. 10 Einträge.
    function pushRecent(url) {
        const next = [{ title: Model.shortUrl(url), url: String(url) }]
        for (let i = 0; i < videoRecents.length && next.length < 10; i++) {
            if (videoRecents[i].url !== url) next.push(videoRecents[i])
        }
        videoRecents = next
        saveRecents()
    }
    function removeRecent(url) {
        const next = []
        for (let i = 0; i < videoRecents.length; i++) {
            if (videoRecents[i].url !== url) next.push(videoRecents[i])
        }
        videoRecents = next
        saveRecents()
    }
    function saveRecents() {
        recentsSaveProc.command = ["bash", "-c",
            'mkdir -p "$HOME/.local/state/familienfabrik" && printf \'%s\' "$1" > "$HOME/.local/state/familienfabrik/recents.json"',
            "save", JSON.stringify(videoRecents)]
        recentsSaveProc.running = true
    }

    // Fabrik-Funk: RSS-Feed der Website laden und anzeigen.
    function fetchFunk() {
        funkStatus = "lädt…"
        funkProc.running = true
    }
    // Beliebigen Link im Standard-Browser öffnen.
    function openLink(url) {
        openLinkProc.command = ["xdg-open", String(url)]
        openLinkProc.running = true
    }

    // ------------------------- Prozesse (System-Integration) ------------------

    // Transport via MPRIS – drei Standardaufrufe, Shuffle/Loop (siehe unten).
    Process { id: ppProc;   command: ["playerctl", "play-pause"] }
    Process { id: nextProc; command: ["playerctl", "next"] }
    Process { id: prevProc; command: ["playerctl", "previous"] }

    // Lautstärke setzen (command wird in applyVolume() gesetzt).
    Process { id: setVolumeProc }

    // Spulen (command wird in seekTo() gesetzt).
    Process { id: seekProc }

    // Shuffle umschalten (playerctl kennt „toggle“ als direktes Argument).
    Process { id: shuffleSetProc; command: ["playerctl", "shuffle", "toggle"] }

    // Loop setzen (command wird in cycleLoop() gesetzt).
    Process { id: loopSetProc }

    // Wiedergabe in mpv (command wird jeweils vor dem Start gesetzt).
    Process { id: mpvMusicProc }     // einzelner Musik-Titel (--no-video, Fallback)
    Process { id: mpvPlaylistProc }  // ganze Playlist direkt (--no-video, Fallback)
    Process { id: m3uPlayProc }      // M3U-Playlist ab gewähltem Titel (--no-video)
    Process { id: mpvVideoProc }     // Video/Datei

    // Titel-Liste einer Playlist via yt-dlp laden. Bei Auswahl aus dem
    // Browser (autoPlayOnLoad) startet die Wiedergabe sofort nacheinander.
    Process {
        id: importProc
        stdout: StdioCollector {
            onStreamFinished: {
                const res = Model.parseYtDlp(this.text)
                root.playlist = res.items
                root.importState = res.items.length > 0
                    ? res.items.length + " titel geladen"
                    : ("keine titel gefunden" + (res.error ? " – " + res.error : ""))
                if (res.items.length > 0 && root.autoPlayOnLoad) {
                    root.autoPlayOnLoad = false
                    root.playFrom(0)
                }
            }
        }
    }

    // Übersicht ALLER Playlisten des SoundCloud-Profils laden; das Ergebnis
    // wird an die kuratierte Übersicht angehängt (Duplikate übersprungen).
    Process {
        id: listsProc
        command: ["yt-dlp", "--flat-playlist", "--no-warnings", "-J", Model.PLAYLISTS_SOURCE]
        stdout: StdioCollector {
            onStreamFinished: {
                const res = Model.parseYtDlp(this.text)
                if (res.items.length === 0) {
                    root.playlistsState = "keine weiteren playlists" +
                        (res.error ? " (" + res.error + ")" : "")
                    return
                }
                const known = {}
                const merged = []
                for (let i = 0; i < root.playlists.length; i++) {
                    known[root.playlists[i].url] = true
                    merged.push(root.playlists[i])
                }
                for (let j = 0; j < res.items.length && merged.length < 40; j++) {
                    const e = res.items[j]
                    if (e.url && !known[e.url]) {
                        known[e.url] = true
                        merged.push({ name: e.title, note: "soundcloud", url: e.url })
                    }
                }
                root.playlists = merged
                root.playlistsState = merged.length + " playlists"
            }
        }
    }

    // Geschichten-Seite laden (curl) – der Text wird im Panel angezeigt.
    Process {
        id: storyProc
        stdout: StdioCollector {
            onStreamFinished: {
                const text = Model.parseStory(this.text)
                root.storyText = text
                root.storyStatus = text !== "" ? "" : "nicht lesbar – browser nutzen"
            }
        }
    }

    // Fabrik-Funk-Feed abrufen (RSS der Website).
    Process {
        id: funkProc
        command: ["curl", "-sL", "--max-time", "15", "https://familienfabrik.at/feed.xml"]
        stdout: StdioCollector {
            onStreamFinished: {
                const items = Model.parseRss(this.text)
                root.funkNews = items
                root.funkStatus = items.length > 0
                    ? items.length + " beiträge"
                    : "feed leer oder nicht erreichbar"
            }
        }
    }

    // Links im Standard-Browser öffnen.
    Process { id: openLinkProc }

    // Verlauf lesen/schreiben (~/.local/state/familienfabrik/recents.json).
    Process {
        id: recentsLoadProc
        command: ["bash", "-c",
            'cat "$HOME/.local/state/familienfabrik/recents.json" 2>/dev/null || echo "[]"']
        stdout: StdioCollector {
            onStreamFinished: root.videoRecents = Model.parseRecents(this.text)
        }
    }
    Process { id: recentsSaveProc }  // command wird in saveRecents() gesetzt

    // Entprell-Timer: Lautstärke erst nach kurzer Pause an playerctl geben.
    Timer {
        id: volumeDebounce
        interval: 180
        onTriggered: root.applyVolume()
    }

    // ------------------------- Panel-Fläche -----------------------------------

    KeyboardPanel {
        id: panel
        anchorItem: root.anchorItem
        owner: root.hostWidget || root
        bar: root.bar
        open: root.opened
        focusTarget: keyCatcher
        // Vorgabe: kompakt, max. rund 480 px Breit.
        contentWidth: panel.fittedContentWidth(Style.space(480))
        contentHeight: panel.fittedContentHeight(content.implicitHeight)

        PanelKeyCatcher {
            id: keyCatcher
            anchors.fill: parent
            onCloseRequested: root.close()
            onTabRequested: function (direction) { root.switchPanel(direction) }
        }

        Column {
            id: content
            width: parent.width
            spacing: Style.space(8)

            // ------------------------- Kopfzeile -----------------------------
            Rectangle {
                width: parent.width
                height: headerTitle.implicitHeight + Style.space(8)
                radius: Style.space(10)
                color: Qt.alpha(root.barForeground, 0.07)
                border.width: 1
                border.color: Qt.alpha(root.barForeground, 0.16)

                Text {
                    id: headerTitle
                    anchors.left: parent.left
                    anchors.leftMargin: Style.space(12)
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Familienfabrik.at"
                    color: root.barForeground
                    font.family: root.monoFont
                    font.pixelSize: Style.font.subtitle
                    font.bold: true
                }
                Text {
                    anchors.left: headerTitle.right
                    anchors.leftMargin: Style.space(8)
                    anchors.baseline: headerTitle.baseline
                    text: "v1.0.0"
                    color: Qt.alpha(root.barForeground, 0.55)
                    font.family: root.monoFont
                    font.pixelSize: Style.font.subtitle
                }
                // Schließen-Knopf (Alternative zu ESC).
                Rectangle {
                    anchors.right: parent.right
                    anchors.rightMargin: Style.space(8)
                    anchors.verticalCenter: parent.verticalCenter
                    width: Style.space(22)
                    height: Style.space(22)
                    radius: Style.space(6)
                    color: Qt.alpha(root.barForeground, closeArea.containsMouse ? 0.2 : 0.08)
                    Text {
                        anchors.centerIn: parent
                        text: "×"
                        color: root.barForeground
                        font.family: root.monoFont
                        font.pixelSize: Style.font.subtitle
                    }
                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.close()
                    }
                }
            }

            // ------------------------- Tab-Leiste -----------------------------
            // Vier Tabs; der aktive Tab hebt sich mit der Theme-Akzentfarbe ab.
            Row {
                id: tabBar
                width: parent.width
                spacing: Style.space(4)

                Repeater {
                    model: ["♪ Musik", "▶ Video", "✎ Lesen", "Funk"]

                    delegate: Rectangle {
                        height: Style.space(28)
                        width: tabLabel.implicitWidth + Style.space(18)
                        radius: Style.space(8)
                        // Aktiver Tab leuchtet in der Akzentfarbe.
                        color: root.activeTab === index
                               ? Qt.alpha(Color.accent, 0.22)
                               : Qt.alpha(root.barForeground, 0.06)
                        border.width: 1
                        border.color: root.activeTab === index
                               ? Qt.alpha(Color.accent, 0.55)
                               : Qt.alpha(root.barForeground, 0.15)

                        Text {
                            id: tabLabel
                            anchors.centerIn: parent
                            text: modelData
                            color: root.activeTab === index
                                   ? Color.accent
                                   : Qt.alpha(root.barForeground, 0.7)
                            font.family: root.monoFont
                            font.pixelSize: Style.font.subtitle
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.activeTab = index
                        }
                    }
                }
            }

            // ------------------------- TAB 1 · MUSIK ---------------------------
            Column {
                id: musicTab
                width: parent.width
                spacing: Style.space(8)
                visible: root.activeTab === 0

                // ---- Now Playing -------------------------------------------------
                Rectangle {
                    width: parent.width
                    // Ohne bekannte Titellänge entfällt der Fortschrittsbalken.
                    height: (root.hostWidget && root.hostWidget.trackDuration > 0)
                            ? Style.space(96) : Style.space(72)
                    radius: Style.space(10)
                    color: Qt.alpha(root.barForeground, 0.05)
                    border.width: 1
                    border.color: Qt.alpha(root.barForeground, 0.15)

                    Column {
                        anchors.fill: parent
                        anchors.margins: Style.space(12)
                        spacing: Style.space(6)

                        Row {
                            width: parent.width
                            spacing: Style.space(12)

                        // Animierter Equalizer – läuft nur bei Wiedergabe.
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Style.space(2)

                            Repeater {
                                model: 5

                                delegate: Rectangle {
                                    id: eqBar
                                    width: Style.space(3)
                                    height: Style.space(4)
                                    radius: width / 2
                                    color: Color.accent
                                    opacity: 0.9

                                    SequentialAnimation {
                                        id: eqAnim
                                        loops: Animation.Infinite
                                        running: root.playing
                                        NumberAnimation {
                                            target: eqBar
                                            property: "height"
                                            from: Style.space(4)
                                            to: Style.space(13)
                                            duration: 260 + index * 70
                                            easing.type: Easing.InOutQuad
                                        }
                                        NumberAnimation {
                                            target: eqBar
                                            property: "height"
                                            from: Style.space(13)
                                            to: Style.space(4)
                                            duration: 260 + index * 70
                                            easing.type: Easing.InOutQuad
                                        }
                                        onRunningChanged: if (!running) eqBar.height = Style.space(4)
                                    }
                                }
                            }
                        }

                        // Titel, Interpret, Status.
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            Text {
                                width: root.panelWidthHint - Style.space(100)
                                text: root.nowTitle !== ""
                                      ? root.nowTitle : "– keine wiedergabe –"
                                color: root.barForeground
                                font.family: root.monoFont
                                font.pixelSize: Style.font.subtitle
                                font.bold: true
                                elide: Text.ElideRight
                            }
                            Text {
                                width: root.panelWidthHint - Style.space(100)
                                text: root.nowArtist !== "" ? root.nowArtist : " "
                                color: Qt.alpha(root.barForeground, 0.65)
                                font.family: root.monoFont
                                font.pixelSize: Style.font.subtitle
                                elide: Text.ElideRight
                            }
                            Text {
                                text: root.statusText === "Playing"
                                      ? "läuft · steuerung via playerctl/mpris"
                                      : root.statusText === "Paused"
                                      ? "pausiert"
                                      : "kein player aktiv – titel unten starten"
                                color: Qt.alpha(root.barForeground, 0.45)
                                font.family: root.monoFont
                                font.pixelSize: Style.font.subtitle
                            }
                        }
                        }

                        // ---- Fortschritt: Balken + Zeit, Klick spult -------------
                        Row {
                            width: parent.width
                            spacing: Style.space(8)
                            visible: root.hostWidget
                                     && root.hostWidget.trackDuration > 0

                            // Dünner Spul-Balken.
                            Rectangle {
                                id: seekTrack
                                width: parent.width - timeLabel.implicitWidth
                                       - Style.space(8)
                                height: Style.space(10)
                                anchors.verticalCenter: parent.verticalCenter
                                radius: height / 2
                                color: Qt.alpha(root.barForeground, 0.12)

                                // Füllstand = Position/Länge (Akzentfarbe).
                                Rectangle {
                                    width: Math.round(parent.width * root.trackFraction)
                                    height: parent.height
                                    radius: parent.radius
                                    color: Color.accent
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true
                                    // Klickposition = Zielposition (Bruchteil).
                                    onClicked: root.seekTo(mouse.x / width)
                                }
                            }

                            // Zeit „1:23 / 3:12“.
                            Text {
                                id: timeLabel
                                anchors.verticalCenter: parent.verticalCenter
                                text: Model.fmtTime(root.hostWidget
                                          ? root.hostWidget.trackPosition : 0)
                                      + " / "
                                      + Model.fmtTime(root.hostWidget
                                          ? root.hostWidget.trackDuration : 0)
                                color: Qt.alpha(root.barForeground, 0.55)
                                font.family: root.monoFont
                                font.pixelSize: Style.font.subtitle
                            }
                        }
                    }
                }

                // ---- Transport: Zurück · Play/Pause · Weiter ---------------------
                Row {
                    spacing: Style.space(8)

                    // Zurück.
                    Rectangle {
                        width: Style.space(44); height: Style.space(32)
                        radius: Style.space(8)
                        color: Qt.alpha(root.barForeground, prevArea.containsMouse ? 0.18 : 0.07)
                        border.width: 1
                        border.color: Qt.alpha(root.barForeground, 0.2)
                        Text {
                            anchors.centerIn: parent
                            text: "««"
                            color: root.barForeground
                            font.family: root.monoFont
                            font.pixelSize: Style.font.subtitle
                        }
                        MouseArea {
                            id: prevArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: prevProc.running = true
                        }
                    }

                    // Play/Pause (Beschriftung folgt dem Status; Akzent).
                    Rectangle {
                        width: Style.space(52); height: Style.space(32)
                        radius: Style.space(8)
                        color: Qt.alpha(Color.accent, ppArea.containsMouse ? 0.3 : 0.16)
                        border.width: 1
                        border.color: Qt.alpha(Color.accent, 0.5)
                        Text {
                            anchors.centerIn: parent
                            text: root.playing ? "||" : "▶"
                            color: root.barForeground
                            font.family: root.monoFont
                            font.pixelSize: Style.font.subtitle
                        }
                        MouseArea {
                            id: ppArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: ppProc.running = true
                        }
                    }

                    // Weiter.
                    Rectangle {
                        width: Style.space(44); height: Style.space(32)
                        radius: Style.space(8)
                        color: Qt.alpha(root.barForeground, nextArea.containsMouse ? 0.18 : 0.07)
                        border.width: 1
                        border.color: Qt.alpha(root.barForeground, 0.2)
                        Text {
                            anchors.centerIn: parent
                            text: "»»"
                            color: root.barForeground
                            font.family: root.monoFont
                            font.pixelSize: Style.font.subtitle
                        }
                        MouseArea {
                            id: nextArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: nextProc.running = true
                        }
                    }

                    // Shuffle an/aus (aktiv = Akzentfarbe).
                    Rectangle {
                        width: Style.space(44); height: Style.space(32)
                        radius: Style.space(8)
                        color: root.shuffleOn
                               ? Qt.alpha(Color.accent, shufArea.containsMouse ? 0.32 : 0.2)
                               : Qt.alpha(root.barForeground, shufArea.containsMouse ? 0.18 : 0.07)
                        border.width: 1
                        border.color: root.shuffleOn
                               ? Qt.alpha(Color.accent, 0.55)
                               : Qt.alpha(root.barForeground, 0.2)
                        Text {
                            anchors.centerIn: parent
                            text: "⇄"
                            color: root.shuffleOn ? Color.accent : root.barForeground
                            opacity: root.shuffleOn ? 1 : 0.55
                            font.family: root.monoFont
                            font.pixelSize: Style.font.subtitle
                        }
                        MouseArea {
                            id: shufArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggleShuffle()
                        }
                    }

                    // Loop: aus → titel (↻1) → liste (↻∞) → aus (aktiv = Akzent).
                    Rectangle {
                        width: Style.space(52); height: Style.space(32)
                        radius: Style.space(8)
                        color: root.loopState !== "None"
                               ? Qt.alpha(Color.accent, loopArea.containsMouse ? 0.32 : 0.2)
                               : Qt.alpha(root.barForeground, loopArea.containsMouse ? 0.18 : 0.07)
                        border.width: 1
                        border.color: root.loopState !== "None"
                               ? Qt.alpha(Color.accent, 0.55)
                               : Qt.alpha(root.barForeground, 0.2)
                        Text {
                            anchors.centerIn: parent
                            text: root.loopState === "Track" ? "↻1"
                                  : root.loopState === "Playlist" ? "↻∞" : "↻"
                            color: root.loopState !== "None" ? Color.accent : root.barForeground
                            opacity: root.loopState !== "None" ? 1 : 0.55
                            font.family: root.monoFont
                            font.pixelSize: Style.font.subtitle
                        }
                        MouseArea {
                            id: loopArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.cycleLoop()
                        }
                    }
                }

                // Zustandszeile unter dem Transport (reine Anzeige).
                Text {
                    text: "shuffle " + (root.shuffleOn ? "an" : "aus")
                          + " · loop " + root.loopLabel
                          + " · klick auf ⇄/↻ schaltet um"
                    color: Qt.alpha(root.barForeground, 0.45)
                    font.family: root.monoFont
                    font.pixelSize: Style.font.subtitle
                }

                // ---- Lautstärke ----------------------------------------------------
                Text {
                    text: "lautstärke · " + Math.round(root.volumeShown * 100) + " %"
                    color: Qt.alpha(root.barForeground, 0.65)
                    font.family: root.monoFont
                    font.pixelSize: Style.font.subtitle
                }
                Rectangle {
                    id: volTrack
                    width: parent.width
                    height: Style.space(10)
                    radius: height / 2
                    color: Qt.alpha(root.barForeground, 0.14)

                    // Füllstand folgt dem angezeigten Wert (Akzentfarbe).
                    Rectangle {
                        width: Math.round(parent.width * Math.max(0, Math.min(1, root.volumeShown)))
                        height: parent.height
                        radius: parent.radius
                        color: Color.accent
                    }

                    MouseArea {
                        id: volArea
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        // Klick springt, Drag zieht kontinuierlich (entprellt).
                        onPressed: function(mouse) { root.volumeDrag(mouse.x, width) }
                        onMouseXChanged: if (pressed) root.volumeDrag(mouse.x, width)
                        onReleased: root.applyVolume()
                    }
                }

                // ---- Playlist-Browser -----------------------------------------------
                // Übersicht über ALLE Playlisten der Website (kuratiert aus
                // familienfabrik.at/musik, dynamisch erweiterbar). Auswahl:
                // Titel laden, automatisch nacheinander abspielen und die
                // Titel-Liste zum Auswählen einzelner Songs anzeigen.

                // Zweig A: Übersicht (noch keine Playlist gewählt).
                Column {
                    width: parent.width
                    spacing: Style.space(8)
                    visible: root.currentPlaylist === ""

                    Text {
                        text: "// playlists · alle listen von familienfabrik.at"
                        color: Qt.alpha(root.barForeground, 0.5)
                        font.family: root.monoFont
                        font.pixelSize: Style.font.subtitle
                    }

                    // ALLE Playlisten des SoundCloud-Profils nachladen
                    // (kommt zu den kuratierten dazu; Duplikate entfallen).
                    Rectangle {
                        width: listsLabel.implicitWidth + Style.space(24)
                        height: Style.space(28)
                        radius: Style.space(8)
                        color: Qt.alpha(Color.accent, listsArea.containsMouse ? 0.28 : 0.14)
                        border.width: 1
                        border.color: Qt.alpha(Color.accent, 0.45)
                        Text {
                            id: listsLabel
                            anchors.centerIn: parent
                            text: "▸ alle soundcloud-playlisten laden"
                            color: Color.accent
                            font.family: root.monoFont
                            font.pixelSize: Style.font.subtitle
                        }
                        MouseArea {
                            id: listsArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.loadAllPlaylists()
                        }
                    }

                    // Status des dynamischen Nachladens.
                    Text {
                        visible: root.playlistsState !== ""
                        text: root.playlistsState
                        color: Qt.alpha(root.barForeground, 0.55)
                        font.family: root.monoFont
                        font.pixelSize: Style.font.subtitle
                    }

                    // Playlist-Übersicht: klickbare Zeilen (Name + Hinweis).
                    ListView {
                        width: parent.width
                        height: Math.min(contentHeight, Style.space(230))
                        clip: true
                        spacing: Style.space(4)
                        model: root.playlists

                        delegate: Rectangle {
                            width: ListView.view.width
                            height: Style.space(44)
                            radius: Style.space(8)
                            color: Qt.alpha(root.barForeground, plRowArea.containsMouse ? 0.12 : 0.05)
                            border.width: 1
                            border.color: Qt.alpha(root.barForeground, 0.12)

                            // Ganze Zeile klickbar (unter dem Row deklariert,
                            // damit der ▶-Knopf oben seine Klicks behält).
                            MouseArea {
                                id: plRowArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.selectPlaylist(index)
                            }

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: Style.space(10)
                                anchors.rightMargin: Style.space(6)
                                spacing: Style.space(10)

                                // Akzent-Marker am linken Rand.
                                Rectangle {
                                    width: Style.space(3)
                                    height: parent.height - Style.space(16)
                                    anchors.verticalCenter: parent.verticalCenter
                                    radius: width / 2
                                    color: Color.accent
                                    opacity: 0.75
                                }

                                // Name + Kurzbeschreibung der Playlist.
                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 1

                                    Text {
                                        width: root.panelWidthHint - Style.space(130)
                                        text: modelData.name
                                        color: root.barForeground
                                        font.family: root.monoFont
                                        font.pixelSize: Style.font.subtitle
                                        font.bold: true
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        width: root.panelWidthHint - Style.space(130)
                                        text: modelData.note
                                        color: Qt.alpha(root.barForeground, 0.5)
                                        font.family: root.monoFont
                                        font.pixelSize: Style.font.subtitle
                                        elide: Text.ElideRight
                                    }
                                }

                                // ▶ Playlist wählen und abspielen.
                                Rectangle {
                                    width: Style.space(30)
                                    height: Style.space(28)
                                    anchors.verticalCenter: parent.verticalCenter
                                    radius: Style.space(6)
                                    color: Qt.alpha(Color.accent, plPlayArea.containsMouse ? 0.35 : 0.18)
                                    Text {
                                        anchors.centerIn: parent
                                        text: "▶"
                                        color: Color.accent
                                        font.family: root.monoFont
                                        font.pixelSize: Style.font.subtitle
                                    }
                                    MouseArea {
                                        id: plPlayArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.selectPlaylist(index)
                                    }
                                }
                            }
                        }
                    }

                    // Eigene Quelle: Playlist-URL frei importieren.
                    Text {
                        text: "// eigene quelle · url importieren (yt-dlp)"
                        color: Qt.alpha(root.barForeground, 0.5)
                        font.family: root.monoFont
                        font.pixelSize: Style.font.subtitle
                    }

                    // URL-Feld + Import-Knopf.
                    Row {
                        width: parent.width
                        spacing: Style.space(8)

                        Rectangle {
                            width: parent.width - importBtn.width - Style.space(8)
                            height: Style.space(32)
                            radius: Style.space(8)
                            color: Qt.alpha(root.barForeground, 0.06)
                            border.width: 1
                            border.color: playlistUrl.activeFocus
                                ? Qt.alpha(Color.accent, 0.6)
                                : Qt.alpha(root.barForeground, 0.18)

                            TextInput {
                                id: playlistUrl
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: Style.space(10)
                                anchors.rightMargin: Style.space(10)
                                color: root.barForeground
                                selectionColor: Color.accent
                                // Auswahl-Kontrast aus dem Theme (keine
                                // fest verdrahtete Farbe).
                                selectedTextColor: Color.bar.background
                                font.family: root.monoFont
                                font.pixelSize: Style.font.subtitle
                                clip: true
                                // Enter startet den Import direkt.
                                onAccepted: root.importPlaylist(text)

                                Text {
                                    anchors.fill: parent
                                    visible: playlistUrl.text === "" && !playlistUrl.activeFocus
                                    verticalAlignment: Text.AlignVCenter
                                    text: "playlist-url einfügen…"
                                    color: Qt.alpha(root.barForeground, 0.4)
                                    font.family: root.monoFont
                                    font.pixelSize: Style.font.subtitle
                                }
                            }
                        }

                        // Import-Knopf.
                        Rectangle {
                            id: importBtn
                            width: Style.space(96); height: Style.space(32)
                            radius: Style.space(8)
                            color: Qt.alpha(root.barForeground, importArea.containsMouse ? 0.22 : 0.1)
                            border.width: 1
                            border.color: Qt.alpha(root.barForeground, 0.4)
                            Text {
                                anchors.centerIn: parent
                                text: "import"
                                color: root.barForeground
                                font.family: root.monoFont
                                font.pixelSize: Style.font.subtitle
                            }
                            MouseArea {
                                id: importArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.importPlaylist(playlistUrl.text)
                            }
                        }
                    }
                }

                // Zweig B: Playlist gewählt – Kopfzeile + Titel-Liste.
                // Wiedergabe startet automatisch bei der Auswahl und läuft
                // nacheinander weiter; ein Klick auf einen Titel springt
                // dorthin und spielt ab dort weiter.
                Column {
                    width: parent.width
                    spacing: Style.space(8)
                    visible: root.currentPlaylist !== ""

                    // Zurück zur Übersicht + Name der Playlist.
                    Row {
                        spacing: Style.space(8)

                        Rectangle {
                            width: backLabel.implicitWidth + Style.space(22)
                            height: Style.space(28)
                            radius: Style.space(8)
                            color: Qt.alpha(root.barForeground, backArea.containsMouse ? 0.2 : 0.08)
                            border.width: 1
                            border.color: Qt.alpha(root.barForeground, 0.3)
                            Text {
                                id: backLabel
                                anchors.centerIn: parent
                                text: "◀ übersicht"
                                color: root.barForeground
                                font.family: root.monoFont
                                font.pixelSize: Style.font.subtitle
                            }
                            MouseArea {
                                id: backArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.backToPlaylists()
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: root.panelWidthHint
                                - (root.currentPlaylistPage !== "" ? Style.space(280) : Style.space(180))
                            text: "♪ " + root.currentPlaylist
                            color: Color.accent
                            font.family: root.monoFont
                            font.pixelSize: Style.font.subtitle
                            font.bold: true
                            elide: Text.ElideRight
                        }

                        // Mitsing-Text öffnen (nur beim Mitsingen-Lied sichtbar):
                        // auf der Website läuft der Text Zeile für Zeile zur Musik mit.
                        Rectangle {
                            visible: root.currentPlaylistPage !== ""
                            width: singLabel.implicitWidth + Style.space(22)
                            height: Style.space(28)
                            anchors.verticalCenter: parent.verticalCenter
                            radius: Style.space(8)
                            color: Qt.alpha(Color.accent, singArea.containsMouse ? 0.28 : 0.14)
                            border.width: 1
                            border.color: Qt.alpha(Color.accent, 0.45)
                            Text {
                                id: singLabel
                                anchors.centerIn: parent
                                text: "↗ text"
                                color: Color.accent
                                font.family: root.monoFont
                                font.pixelSize: Style.font.subtitle
                            }
                            MouseArea {
                                id: singArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.openLink(root.currentPlaylistPage)
                            }
                        }
                    }

                    // Import-/Wiedergabe-Status (Ladefortschritt, Hinweise).
                    Text {
                        visible: root.importState !== ""
                        text: root.importState
                        color: Qt.alpha(root.barForeground, 0.6)
                        font.family: root.monoFont
                        font.pixelSize: Style.font.subtitle
                    }

                    // Kopfzeile der Titel-Liste: Anzahl + „ganze playlist“.
                    Row {
                        width: parent.width
                        visible: root.playlist.length > 0
                        spacing: Style.space(8)

                        Text {
                            id: playlistCount
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.playlist.length + " titel · klick = ab hier weiterspielen"
                            color: Qt.alpha(root.barForeground, 0.7)
                            font.family: root.monoFont
                            font.pixelSize: Style.font.subtitle
                            width: parent.width - playAllBtn.width - Style.space(16)
                            elide: Text.ElideRight
                        }

                        // Ganze Playlist (nochmal von vorn) abspielen.
                        Rectangle {
                            id: playAllBtn
                            width: Style.space(150); height: Style.space(28)
                            radius: Style.space(8)
                            color: Qt.alpha(Color.accent, playAllArea.containsMouse ? 0.28 : 0.14)
                            border.width: 1
                            border.color: Qt.alpha(Color.accent, 0.45)
                            Text {
                                anchors.centerIn: parent
                                text: "▶ ganze playlist"
                                color: Color.accent
                                font.family: root.monoFont
                                font.pixelSize: Style.font.subtitle
                            }
                            MouseArea {
                                id: playAllArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.playPlaylist()
                            }
                        }
                    }

                    // Titel-Liste: Klick spielt diesen Titel und danach
                    // alle folgenden nacheinander (M3U ab Klick-Index).
                    ListView {
                        width: parent.width
                        height: Math.min(contentHeight, Style.space(190))
                        visible: root.playlist.length > 0
                        clip: true
                        spacing: Style.space(2)
                        model: root.playlist

                        delegate: Rectangle {
                            width: ListView.view.width
                            height: Style.space(30)
                            radius: Style.space(6)
                            color: Qt.alpha(root.barForeground, trackRowArea.containsMouse ? 0.12 : 0.05)
                            border.width: 1
                            border.color: Qt.alpha(root.barForeground, 0.12)

                            // Ganze Zeile klickbar = ebenfalls abspielen.
                            // (Unter dem Row deklariert, damit die Knöpfe
                            // darüber ihre Klicks selbst behalten.)
                            MouseArea {
                                id: trackRowArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.playTrack(modelData.url)
                            }

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: Style.space(10)
                                anchors.rightMargin: Style.space(6)
                                spacing: Style.space(8)

                                // Laufende Nummer.
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: (index + 1) + "."
                                    color: Qt.alpha(root.barForeground, 0.45)
                                    font.family: root.monoFont
                                    font.pixelSize: Style.font.subtitle
                                }

                                // Titel (einzeilig gekürzt).
                                Text {
                                    width: parent.width - Style.space(80)
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.title
                                    color: root.barForeground
                                    font.family: root.monoFont
                                    font.pixelSize: Style.font.subtitle
                                    elide: Text.ElideRight
                                }

                                // Diesen Titel abspielen.
                                Rectangle {
                                    width: Style.space(26); height: Style.space(24)
                                    anchors.verticalCenter: parent.verticalCenter
                                    radius: Style.space(6)
                                    color: Qt.alpha(Color.accent, trackPlayArea.containsMouse ? 0.35 : 0.18)
                                    Text {
                                        anchors.centerIn: parent
                                        text: "▶"
                                        color: Color.accent
                                        font.family: root.monoFont
                                        font.pixelSize: Style.font.subtitle
                                    }
                                    MouseArea {
                                        id: trackPlayArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.playTrack(modelData.url)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ------------------------- TAB 2 · VIDEO ---------------------------
            Column {
                id: videoTab
                width: parent.width
                spacing: Style.space(8)
                visible: root.activeTab === 1

                Text {
                    text: "// video starten · youtube-links, -playlisten & dateien via mpv"
                    color: Qt.alpha(root.barForeground, 0.5)
                    font.family: root.monoFont
                    font.pixelSize: Style.font.subtitle
                }

                // URL/Pfad + mpv-Knopf.
                Row {
                    width: parent.width
                    spacing: Style.space(8)

                    Rectangle {
                        width: parent.width - mpvBtn.width - Style.space(8)
                        height: Style.space(32)
                        radius: Style.space(8)
                        color: Qt.alpha(root.barForeground, 0.06)
                        border.width: 1
                        border.color: videoUrl.activeFocus
                            ? Qt.alpha(root.barForeground, 0.55)
                            : Qt.alpha(root.barForeground, 0.18)

                        TextInput {
                            id: videoUrl
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: Style.space(10)
                            anchors.rightMargin: Style.space(10)
                            color: root.barForeground
                            selectionColor: Color.accent
                            // Auswahl-Kontrast aus dem Theme.
                            selectedTextColor: Color.bar.background
                            font.family: root.monoFont
                            font.pixelSize: Style.font.subtitle
                            clip: true
                            onAccepted: root.openVideo(text)

                            Text {
                                anchors.fill: parent
                                visible: videoUrl.text === "" && !videoUrl.activeFocus
                                verticalAlignment: Text.AlignVCenter
                                text: "youtube-url oder datei-pfad einfügen…"
                                color: Qt.alpha(root.barForeground, 0.4)
                                font.family: root.monoFont
                                font.pixelSize: Style.font.subtitle
                            }
                        }
                    }

                    Rectangle {
                        id: mpvBtn
                        width: Style.space(88); height: Style.space(32)
                        radius: Style.space(8)
                        color: Qt.alpha(root.barForeground, mpvArea2.containsMouse ? 0.22 : 0.1)
                        border.width: 1
                        border.color: Qt.alpha(root.barForeground, 0.4)
                        Text {
                            anchors.centerIn: parent
                            text: "▶ mpv"
                            color: root.barForeground
                            font.family: root.monoFont
                            font.pixelSize: Style.font.subtitle
                        }
                        MouseArea {
                            id: mpvArea2
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.openVideo(videoUrl.text)
                        }
                    }
                }

                // Kurzer Status/Hinweis unter dem Feld.
                Text {
                    text: root.videoHint
                    color: Qt.alpha(root.barForeground, 0.45)
                    font.family: root.monoFont
                    font.pixelSize: Style.font.subtitle
                }

                // ---- Fabrik-Videos (YouTube-Playlist „Animierte Kinderlieder“) --
                // Die eigenen animierten Musikvideos – klick startet mpv mit
                // deutschen/englischen Untertiteln (sofern vorhanden).
                Text {
                    text: "// fabrik-videos · animierte kinderlieder"
                    color: Qt.alpha(root.barForeground, 0.5)
                    font.family: root.monoFont
                    font.pixelSize: Style.font.subtitle
                }

                // Ganze Wiedergabeliste abspielen.
                Rectangle {
                    width: allVideosLabel.implicitWidth + Style.space(24)
                    height: Style.space(28)
                    radius: Style.space(8)
                    color: Qt.alpha(Color.accent, allVideosArea.containsMouse ? 0.28 : 0.14)
                    border.width: 1
                    border.color: Qt.alpha(Color.accent, 0.45)
                    Text {
                        id: allVideosLabel
                        anchors.centerIn: parent
                        text: "▶ alle videos nacheinander"
                        color: Color.accent
                        font.family: root.monoFont
                        font.pixelSize: Style.font.subtitle
                    }
                    MouseArea {
                        id: allVideosArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.playAllVideos()
                    }
                }

                // Video-Liste (Titel aus der echten Wiedergabeliste).
                ListView {
                    width: parent.width
                    height: Math.min(contentHeight, Style.space(160))
                    clip: true
                    spacing: Style.space(2)
                    model: root.fabrikVideos

                    delegate: Rectangle {
                        width: ListView.view.width
                        height: Style.space(30)
                        radius: Style.space(6)
                        color: Qt.alpha(root.barForeground, videoRowArea.containsMouse ? 0.12 : 0.05)
                        border.width: 1
                        border.color: Qt.alpha(root.barForeground, 0.12)

                        // Ganze Zeile klickbar = Video starten.
                        MouseArea {
                            id: videoRowArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.playFabrikVideo(modelData.url)
                        }

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: Style.space(10)
                            anchors.rightMargin: Style.space(6)
                            spacing: Style.space(8)

                            // Akzent-Punkt als Video-Marker.
                            Rectangle {
                                width: Style.space(5)
                                height: Style.space(5)
                                radius: width / 2
                                anchors.verticalCenter: parent.verticalCenter
                                color: Color.accent
                                opacity: 0.8
                            }

                            // Videotitel (einzeilig gekürzt).
                            Text {
                                width: parent.width - Style.space(70)
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.title
                                color: root.barForeground
                                font.family: root.monoFont
                                font.pixelSize: Style.font.subtitle
                                elide: Text.ElideRight
                            }

                            // Dieses Video abspielen.
                            Rectangle {
                                width: Style.space(26); height: Style.space(24)
                                anchors.verticalCenter: parent.verticalCenter
                                radius: Style.space(6)
                                color: Qt.alpha(Color.accent, videoPlayArea.containsMouse ? 0.35 : 0.18)
                                Text {
                                    anchors.centerIn: parent
                                    text: "▶"
                                    color: Color.accent
                                    font.family: root.monoFont
                                    font.pixelSize: Style.font.subtitle
                                }
                                MouseArea {
                                    id: videoPlayArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.playFabrikVideo(modelData.url)
                                }
                            }
                        }
                    }
                }

                // ---- Verlauf „zuletzt genutzt“ ------------------------------------
                Text {
                    visible: root.videoRecents.length > 0
                    text: "// zuletzt genutzt"
                    color: Qt.alpha(root.barForeground, 0.5)
                    font.family: root.monoFont
                    font.pixelSize: Style.font.subtitle
                }

                ListView {
                    width: parent.width
                    height: Math.min(contentHeight, Style.space(160))
                    visible: root.videoRecents.length > 0
                    clip: true
                    spacing: Style.space(2)
                    model: root.videoRecents

                    delegate: Rectangle {
                        width: ListView.view.width
                        height: Style.space(30)
                        radius: Style.space(6)
                        color: Qt.alpha(root.barForeground, recRowArea.containsMouse ? 0.12 : 0.05)
                        border.width: 1
                        border.color: Qt.alpha(root.barForeground, 0.12)

                        // Ganze Zeile klickbar = ebenfalls abspielen.
                        // (Unter dem Row deklariert, damit ▶ und × darüber
                        // ihre Klicks selbst behalten.)
                        MouseArea {
                            id: recRowArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.openVideo(modelData.url)
                        }

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: Style.space(10)
                            anchors.rightMargin: Style.space(6)
                            spacing: Style.space(8)

                            Text {
                                width: parent.width - Style.space(70)
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.title
                                color: root.barForeground
                                font.family: root.monoFont
                                font.pixelSize: Style.font.subtitle
                                elide: Text.ElideMiddle
                            }

                            // Nochmal abspielen.
                            Rectangle {
                                width: Style.space(26); height: Style.space(24)
                                anchors.verticalCenter: parent.verticalCenter
                                radius: Style.space(6)
                                color: Qt.alpha(root.barForeground, replayArea.containsMouse ? 0.25 : 0.12)
                                Text {
                                    anchors.centerIn: parent
                                    text: "▶"
                                    color: root.barForeground
                                    font.family: root.monoFont
                                    font.pixelSize: Style.font.subtitle
                                }
                                MouseArea {
                                    id: replayArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.openVideo(modelData.url)
                                }
                            }

                            // Aus Verlauf entfernen.
                            Rectangle {
                                width: Style.space(26); height: Style.space(24)
                                anchors.verticalCenter: parent.verticalCenter
                                radius: Style.space(6)
                                color: Qt.alpha(root.barForeground, delArea.containsMouse ? 0.25 : 0.12)
                                Text {
                                    anchors.centerIn: parent
                                    text: "×"
                                    color: root.barForeground
                                    font.family: root.monoFont
                                    font.pixelSize: Style.font.subtitle
                                }
                                MouseArea {
                                    id: delArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.removeRecent(modelData.url)
                                }
                            }
                        }
                    }
                }
            }

            // ------------------------- TAB 3 · LESEN --------------------------
            // Geschichten von familienfabrik.at/geschichten – direkt im Panel
            // lesbar (Text wird per curl geholt), ganz ohne Browser.
            Column {
                id: lesenTab
                width: parent.width
                spacing: Style.space(8)
                visible: root.activeTab === 2

                // Zweig A: Geschichten-Übersicht.
                Column {
                    width: parent.width
                    spacing: Style.space(8)
                    visible: root.storyTitle === ""

                    Text {
                        text: "// geschichten · zum lesen im panel"
                        color: Qt.alpha(root.barForeground, 0.5)
                        font.family: root.monoFont
                        font.pixelSize: Style.font.subtitle
                    }

                    // Hinweiszeile: Buchreihe + Einzelnsgeschichten.
                    Text {
                        text: "fahrrad-gang bände 1–4 und einzelnsgeschichten · klick öffnet"
                        color: Qt.alpha(root.barForeground, 0.4)
                        font.family: root.monoFont
                        font.pixelSize: Style.font.subtitle
                        elide: Text.ElideRight
                        width: parent.width
                    }

                    // Geschichten-Liste.
                    ListView {
                        width: parent.width
                        height: Math.min(contentHeight, Style.space(300))
                        clip: true
                        spacing: Style.space(2)
                        model: root.stories

                        delegate: Rectangle {
                            width: ListView.view.width
                            height: Style.space(30)
                            radius: Style.space(6)
                            color: Qt.alpha(root.barForeground, storyRowArea.containsMouse ? 0.12 : 0.05)
                            border.width: 1
                            border.color: Qt.alpha(root.barForeground, 0.12)

                            // Ganze Zeile klickbar = Geschichte öffnen.
                            MouseArea {
                                id: storyRowArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.selectStory(index)
                            }

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: Style.space(10)
                                anchors.rightMargin: Style.space(6)
                                spacing: Style.space(8)

                                // Band-Marker (Buchreihe) oder Punkt.
                                Rectangle {
                                    width: Style.space(6)
                                    height: Style.space(6)
                                    anchors.verticalCenter: parent.verticalCenter
                                    radius: width / 2
                                    color: modelData.kind === "band"
                                           ? Color.accent
                                           : Qt.alpha(root.barForeground, 0.45)
                                }

                                // Titel (einzeilig gekürzt).
                                Text {
                                    width: parent.width - Style.space(70)
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.title
                                    color: root.barForeground
                                    font.family: root.monoFont
                                    font.pixelSize: Style.font.subtitle
                                    elide: Text.ElideRight
                                }

                                // „band“-Kennzeichnung für die Buchreihe.
                                Text {
                                    visible: modelData.kind === "band"
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "buch"
                                    color: Qt.alpha(root.barForeground, 0.45)
                                    font.family: root.monoFont
                                    font.pixelSize: Style.font.subtitle
                                }
                            }
                        }
                    }
                }

                // Zweig B: Geschichte geöffnet – im Panel lesen.
                Column {
                    width: parent.width
                    spacing: Style.space(8)
                    visible: root.storyTitle !== ""

                    // Kopfzeile: zurück + Titel + Browser-Knopf (optional).
                    Row {
                        width: parent.width
                        spacing: Style.space(8)

                        Rectangle {
                            width: storyBackLabel.implicitWidth + Style.space(22)
                            height: Style.space(28)
                            radius: Style.space(8)
                            color: Qt.alpha(root.barForeground, storyBackArea.containsMouse ? 0.2 : 0.08)
                            border.width: 1
                            border.color: Qt.alpha(root.barForeground, 0.3)
                            Text {
                                id: storyBackLabel
                                anchors.centerIn: parent
                                text: "◀ liste"
                                color: root.barForeground
                                font.family: root.monoFont
                                font.pixelSize: Style.font.subtitle
                            }
                            MouseArea {
                                id: storyBackArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.backToStories()
                            }
                        }

                        // Titel der offenen Geschichte.
                        Text {
                            width: parent.width - storyBackLabel.width
                                   - browserBtn.width - Style.space(32)
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.storyTitle
                            color: Color.accent
                            font.family: root.monoFont
                            font.pixelSize: Style.font.subtitle
                            font.bold: true
                            elide: Text.ElideRight
                        }

                        // Optionaler Umweg über den Browser.
                        Rectangle {
                            id: browserBtn
                            width: Style.space(34); height: Style.space(28)
                            anchors.verticalCenter: parent.verticalCenter
                            radius: Style.space(6)
                            color: Qt.alpha(root.barForeground, storyBrowserArea.containsMouse ? 0.2 : 0.08)
                            border.width: 1
                            border.color: Qt.alpha(root.barForeground, 0.2)
                            Text {
                                anchors.centerIn: parent
                                text: "↗"
                                color: root.barForeground
                                font.family: root.monoFont
                                font.pixelSize: Style.font.subtitle
                            }
                            MouseArea {
                                id: storyBrowserArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.openStoryInBrowser()
                            }
                        }
                    }

                    // Lade-Status.
                    Text {
                        visible: root.storyStatus !== ""
                        text: root.storyStatus
                        color: Qt.alpha(root.barForeground, 0.55)
                        font.family: root.monoFont
                        font.pixelSize: Style.font.subtitle
                    }

                    // Lesetext: scrollbarer Bereich direkt im Panel.
                    Flickable {
                        id: storyFlick
                        width: parent.width
                        height: Math.min(Style.space(300), contentHeight + Style.space(8))
                        clip: true
                        contentWidth: width
                        contentHeight: storyTextItem.implicitHeight + Style.space(4)

                        // Dünner Akzent-Rand als „Lesefenster“.
                        Rectangle {
                            anchors.fill: parent
                            color: Qt.alpha(root.barForeground, 0.04)
                            radius: Style.space(8)
                            border.width: 1
                            border.color: Qt.alpha(root.barForeground, 0.14)
                        }

                        Text {
                            id: storyTextItem
                            x: Style.space(10)
                            width: parent.width - Style.space(20)
                            text: root.storyText
                            color: root.barForeground
                            font.family: root.monoFont
                            font.pixelSize: Style.font.subtitle
                            lineHeight: 1.25
                            wrapMode: Text.WordWrap
                            visible: root.storyText !== ""
                        }

                        // Rollrad-Markierung (Position im Text).
                        Rectangle {
                            visible: storyFlick.contentHeight > storyFlick.height
                            width: Style.space(2)
                            radius: width / 2
                            x: parent.width - width
                            height: Math.max(Style.space(14),
                                storyFlick.height * storyFlick.height / storyFlick.contentHeight)
                            y: storyFlick.contentY
                                * (storyFlick.height - height)
                                / Math.max(1, storyFlick.contentHeight - storyFlick.height)
                            color: Qt.alpha(Color.accent, 0.6)
                            anchors.right: parent.right
                            anchors.rightMargin: Style.space(2)
                        }
                    }

                    // Fußzeile: Quelle der Geschichte.
                    Text {
                        visible: root.storyText !== ""
                        text: "quelle: familienfabrik.at · esc oder ◀ liste zum schließen"
                        color: Qt.alpha(root.barForeground, 0.4)
                        font.family: root.monoFont
                        font.pixelSize: Style.font.subtitle
                    }
                }
            }

            // ------------------------- TAB 4 · FABRIK-FUNK ---------------------
            Column {
                id: funkTab
                width: parent.width
                spacing: Style.space(8)
                visible: root.activeTab === 3

                Text {
                    text: "// fabrik-funk · neuigkeiten von familienfabrik.at"
                    color: Qt.alpha(root.barForeground, 0.5)
                    font.family: root.monoFont
                    font.pixelSize: Style.font.subtitle
                }

                Row {
                    spacing: Style.space(8)

                    // Feed (neu) laden – Akzent als Primäraktion.
                    Rectangle {
                        width: Style.space(150); height: Style.space(30)
                        radius: Style.space(8)
                        color: Qt.alpha(Color.accent, funkArea.containsMouse ? 0.28 : 0.14)
                        border.width: 1
                        border.color: Qt.alpha(Color.accent, 0.45)
                        Text {
                            anchors.centerIn: parent
                            text: "feed laden"
                            color: Color.accent
                            font.family: root.monoFont
                            font.pixelSize: Style.font.subtitle
                        }
                        MouseArea {
                            id: funkArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.fetchFunk()
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.funkStatus
                        color: Qt.alpha(root.barForeground, 0.55)
                        font.family: root.monoFont
                        font.pixelSize: Style.font.subtitle
                    }
                }

                ListView {
                    width: parent.width
                    height: Math.min(contentHeight, Style.space(280))
                    visible: root.funkNews.length > 0
                    clip: true
                    spacing: Style.space(4)
                    model: root.funkNews

                    // Beiträge klappen AUF: Datum + Titel in der Zeile,
                    // Beschreibung direkt darunter im Panel (kein Browser
                    // nötig). Der ↗-Knopf ist der optionale Browser-Umweg.
                    delegate: Rectangle {
                        width: ListView.view.width
                        height: root.expandedNews === index
                                ? newsColumn.implicitHeight + Style.space(16)
                                : Style.space(44)
                        radius: Style.space(8)
                        color: root.expandedNews === index
                               ? Qt.alpha(Color.accent, 0.08)
                               : Qt.alpha(root.barForeground, newsArea.containsMouse ? 0.12 : 0.05)
                        border.width: 1
                        border.color: root.expandedNews === index
                               ? Qt.alpha(Color.accent, 0.35)
                               : Qt.alpha(root.barForeground, 0.12)

                        MouseArea {
                            id: newsArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            // Klick klappt den Beitrag auf/zu.
                            onClicked: {
                                root.expandedNews =
                                    root.expandedNews === index ? -1 : index
                            }
                        }

                        Column {
                            id: newsColumn
                            anchors.fill: parent
                            anchors.leftMargin: Style.space(10)
                            anchors.rightMargin: Style.space(10)
                            anchors.topMargin: Style.space(6)
                            spacing: Style.space(4)

                            Row {
                                width: parent.width
                                spacing: Style.space(10)

                                // Datum als kleiner Vorschub.
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.date
                                    color: Qt.alpha(root.barForeground, 0.5)
                                    font.family: root.monoFont
                                    font.pixelSize: Style.font.subtitle
                                }

                                Text {
                                    width: parent.width - newsBrowserBtn.width
                                           - Style.space(110)
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: Model.ellipsis(modelData.title, 64)
                                    color: root.barForeground
                                    font.family: root.monoFont
                                    font.pixelSize: Style.font.subtitle
                                    elide: Text.ElideRight
                                }

                                // Aufklapp-Pfeil.
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.expandedNews === index ? "▾" : "▸"
                                    color: root.expandedNews === index
                                           ? Color.accent
                                           : Qt.alpha(root.barForeground, 0.5)
                                    font.family: root.monoFont
                                    font.pixelSize: Style.font.subtitle
                                }

                                // Optional: Beitrag im Browser öffnen.
                                Rectangle {
                                    id: newsBrowserBtn
                                    width: Style.space(26); height: Style.space(24)
                                    anchors.verticalCenter: parent.verticalCenter
                                    radius: Style.space(6)
                                    color: Qt.alpha(root.barForeground,
                                        newsBrowserArea.containsMouse ? 0.25 : 0.1)
                                    Text {
                                        anchors.centerIn: parent
                                        text: "↗"
                                        color: root.barForeground
                                        font.family: root.monoFont
                                        font.pixelSize: Style.font.subtitle
                                    }
                                    MouseArea {
                                        id: newsBrowserArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: if (modelData.link !== "")
                                            root.openLink(modelData.link)
                                    }
                                }
                            }

                            // Beschreibungstext – direkt im Panel lesbar.
                            Text {
                                width: parent.width
                                visible: root.expandedNews === index
                                text: modelData.description || ""
                                color: Qt.alpha(root.barForeground, 0.75)
                                font.family: root.monoFont
                                font.pixelSize: Style.font.subtitle
                                wrapMode: Text.WordWrap
                                lineHeight: 1.2
                            }
                        }
                    }
                }

                // ---- Toolbox-Schnellstart ---------------------------------------
                // Kleine Werkzeuge der Website; interaktive Helfer bleiben
                // Web-Apps und öffnen per Klick im Browser.
                Text {
                    visible: root.funkNews.length > 0
                    text: "// toolbox · kleine werkzeuge der fabrik"
                    color: Qt.alpha(root.barForeground, 0.5)
                    font.family: root.monoFont
                    font.pixelSize: Style.font.subtitle
                }

                Flow {
                    width: parent.width
                    spacing: Style.space(4)
                    visible: root.funkNews.length > 0

                    Repeater {
                        model: Model.TOOLBOX

                        delegate: Rectangle {
                            height: Style.space(26)
                            width: toolLabel.implicitWidth + Style.space(18)
                            radius: height / 2
                            color: Qt.alpha(root.barForeground,
                                toolArea.containsMouse ? 0.2 : 0.08)
                            border.width: 1
                            border.color: Qt.alpha(root.barForeground, 0.22)

                            Text {
                                id: toolLabel
                                anchors.centerIn: parent
                                text: modelData.title
                                color: Qt.alpha(root.barForeground, 0.85)
                                font.family: root.monoFont
                                font.pixelSize: Style.font.subtitle
                            }
                            MouseArea {
                                id: toolArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.openLink(
                                    "https://familienfabrik.at" + modelData.path)
                            }
                        }
                    }
                }

                // Leerzustand / Hinweis.
                Text {
                    visible: root.funkNews.length === 0
                    text: root.funkStatus === "" || root.funkStatus === "lädt…"
                          ? "feed wird beim ersten öffnen geladen"
                          : "keine beiträge – „feed laden“ probieren"
                    color: Qt.alpha(root.barForeground, 0.45)
                    font.family: root.monoFont
                    font.pixelSize: Style.font.subtitle
                }

                Text {
                    text: "quelle: familienfabrik.at/feed.xml"
                    color: Qt.alpha(root.barForeground, 0.4)
                    font.family: root.monoFont
                    font.pixelSize: Style.font.subtitle
                }
            }

            // ------------------------- Fußzeile -------------------------------
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: "at.familienfabrik.omarchy · MIT · playerctl · mpv · yt-dlp · curl"
                color: Qt.alpha(root.barForeground, 0.4)
                font.family: root.monoFont
                font.pixelSize: Style.font.subtitle
            }
        }
    }
}
