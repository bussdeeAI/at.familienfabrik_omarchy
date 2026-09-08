# Changelog

Alle nennenswerten Änderungen an diesem PlugIn werden hier dokumentiert.
Format orientiert an [Keep a Changelog](https://keepachangelog.com/de/),
Versionierung an [SemVer](https://semver.org). Jede Version erscheint
zusätzlich als GitHub-Release mit Tag `v<Version>` – neue Versionen immer
nach oben, das Neueste zuerst.

## [Unveröffentlicht]

### Geplant (Ideen für 1.2)

- Fabrik-Funk: Kategorien-Filter (Ankündigungen, Neuigkeiten, Tonstudio).
- Optional: Familienradar-Ausflugstipp des Tages in der Leiste.
- Katalog-Refresh-Skript in `tools/`, um neue Songs direkt aus den
  SoundCloud-/hearthis.at-APIs in `Model.js` zu übernehmen.
- Hinweis im Panel, wenn eine neuere PlugIn-Version auf GitHub liegt.

## [1.1.1] – 2026-09-08

Patch-Release: Die **Projekt-Seite spielt jetzt echte Musik und echte
Videos** – vorher war die Browser-Demo eine reine Simulation ohne Ton.
Die Laufzeit-Dateien des PlugIns (BarWidget.qml, Panel.qml, Model.js)
sind unverändert; der Patch richtet die Release-Kette (Manifest,
Panel-Fußzeile, Badge, ZIP) auf den neuen Stand der Projekt-Seite aus.

### Hinzugefügt (Projekt-Seite <https://familienfabrik-omarchy.space-z.ai>)

- **Echter Musik-Player im Browser:** Die Demo löst die Songs
  serverseitig auf und streamt echte MP3s – SoundCloud (128 kbps),
  hearthis.at (192 kbps) und direkte MP3s von familienfabrik.at – über
  einen Streaming-Proxy **mit echtem Spulen** (Range-Requests).
  Play/Pause/Stopp, Lautstärke, Shuffle/Loop und automatische
  Titelketten wirken auf die echte Wiedergabe; Cover-Artwork und
  Titel-Dauern kommen aus den Quellen. Startet die Wiedergabe im
  Panel, läuft sie beim Schließen im Hintergrund weiter.
- **Vollformat-Popup-Player (⧉):** Jede Playlist lässt sich per Knopf
  in einem eigenen Popup öffnen – großes Cover, Transport, Lautstärke,
  Titelliste zum Direktsprung – genau wie die Video-Popups.
- **Coversongs im offiziellen Tonstudio-Player:** Das Album spielt als
  hearthis.at-Einbettung – dieselbe, die familienfabrik.at selbst
  einbindet.
- **Fabrik-Videos als echte YouTube-Embeds** im selben Popup-Stil mit
  autoplay, „vorheriges/nächstes Video“ und Link zum Kanal.
- **Autoplay-Sperre erkannt:** Blockiert der Browser den Autostart,
  zeigt der Player einen klaren Hinweis („autostart geblockt – ▶
  klicken“) statt stumm zu versagen.
- Abspiel-Zähler je Titel in der Datenbank der Projekt-Seite
  (Grundlage für künftige Statistik-Auswertungen).

### Behoben (Projekt-Seite)

- Die Demo zeigte vorher einen simulierten Fortschrittsbalken ohne
  Ton – Play/Pause, Spulen, Nächster-Titel und Stopp steuern jetzt
  die echte Wiedergabe. „Gute Laune“ (Mitsingen) und die Hörbücher
  laufen ebenfalls als echte Streams.

## [1.1.0] – 2026-09-08

Erste Pflege-Version: alle drei gemeldeten Probleme behoben (Pause/Stopp,
fehlende Songtitel, unvollständige Playlist-Liste) und das Repository
für GitHub aufgeräumt (Funding, CI, portabler Validator, SemVer-Prozess).

### Hinzugefügt

- **Song-Katalog ab Werk:** Alle **40 Titel** der kuratierten Playlisten
  stehen jetzt mit Titel, Dauer und URL direkt in `Model.js` (Stand 09/2026,
  ausgelesen aus den öffentlichen SoundCloud-/hearthis.at-APIs). Eine
  Playlist anzuklicken genügt – die Titelliste erscheint **sofort**, ohne
  yt-dlp, ohne Wartezeit, ohne Netz.
- **Moderne Kinderlieder Vol. 2** als achte kuratierte Playlist – die
  Musik-Seite listet zwei Kinderlieder-Alben, vorher fehlte Vol. 2.
- **Mitsingen-Lied „Gute Laune“** als direktes MP3 von der Website: startet
  ohne yt-dlp sofort; `↗ text` öffnet die Mitsing-Seite, auf der der Text
  Zeile für Zeile zur Musik mitläuft.
- **Titel-Dauern sichtbar:** jede Zeile der Titelliste zeigt die echte
  Dauer (m:ss), die Kopfzeile die Gesamtdauer der Playlist, die Übersicht
  die Titel-Anzahl je Playlist.
- **Neue Stopp-Taste `■`:** beendet die Wiedergabe komplett (Musik oder
  Video) – MPRIS-Stop plus sicheres Beenden der Panel-Player-Prozesse; die
  Anzeige springt zurück auf „keine wiedergabe“.
- **yt-dlp-Fehler verständlich:** freier URL-Import und „alle
  soundcloud-playlisten laden“ laufen über `bash` mit zusammengeführtem
  stderr (2>&1). Schlägt yt-dlp fehl, zeigt die Statuszeile die Ursache –
  inkl. Installations-Hinweis (`sudo pacman -S yt-dlp`), wenn das Tool
  fehlt. Notfall-Titel werden aus der URL abgeleitet.
- **GitHub-Repo pflegeleicht gemacht:** `.github/FUNDING.yml` (PayPal +
  Support-Seite), CI-Workflow (`.github/workflows/validate.yml`) mit den
  automatischen Prüfungen bei jedem Push, portabler Validator in
  `tools/validate-plugin.mjs` und `.gitignore`.
- **Projekt-Seite mit Demo:** README und Releases verlinken die interaktive
  Projekt-Seite (PlugIn-Vorschau mit Musik, Video, Lesen und Funk im
  Browser) unter
  `https://familienfabrik-omarchy.space-z.ai`.

### Behoben

- **Pause/Stopp treffen jetzt immer den Familienfabrik-Song:** Sämtliche
  Transport-Befehle (Play/Pause, Weiter, Zurück, Stopp, Spulen, Lautstärke,
  Shuffle, Loop) und das MPRIS-Polling laufen mit `playerctl -p mpv` –
  gezielt auf das mpv dieses PlugIns. Vorher konnte playerctl bei parallel
  laufenden MPRIS-Playern (Browser, Spotify …) versehentlich den falschen
  Player steuern, sodass der Song trotz Pause-Klick weiterlief.
- **Songtitel erscheinen jetzt IMMER:** Vorher blieb die Titelliste leer,
  wenn yt-dlp fehlte, die SoundCloud-API hakte oder die Antwort unlesbar
  war – die Statuszeile zeigte nur kryptisch „keine titel gefunden“.
  Seit der Katalog ab Werk dabe ist, kann das nicht mehr passieren.
- **Ein-Player-Prinzip jetzt garantiert:** jeder neue Start (Titel,
  Playlist, Video) beendet vorher ALLE laufenden Wiedergabe-Prozesse
  (`killAllPlayback`) – vorher war ein Neustart bei laufendem Titel je
  nach Quickshell-Version ein No-Op, der alte Song lief einfach weiter.
- **Status friert nicht mehr ein:** meldet `playerctl` nach dem Ende des
  mpv (Playlist-Ende, Stopp) keinen Status mehr, springt die Anzeige sauber
  auf „Stopped“ zurück und räumt Titel/Position/Länge ab.
- **„▶ ganze playlist“ bleibt bedienbar:** die Taste ist jetzt auch ohne
  geladene Titelliste sichtbar und startet die Quelle dann direkt über mpv.
- **Sofortiges Play-Feedback:** `markPlaying()` zeigt „Playing“ direkt beim
  Klick, bevor der nächste MPRIS-Poll (2 s) bestätigt.

### Technisches

- yt-dlp-Aufrufe in `bash -c '… 2>&1'` verpackt (3 Stellen), Fehler werden
  lesbar und Ursache-genau übersetzt (`Model.ytDlpError`).
- `Model.titleFromUrl` leitet Notfall-Titel aus dem URL-Slug ab, falls ein
  Eintrag mal ohne Titel kommt.
- Validierung auf **176 automatische Prüfungen** erweitert und als
  `tools/validate-plugin.mjs` ins Repository gezogen (läuft portabel per
  `node tools/validate-plugin.mjs` und im GitHub-Workflow bei jedem Push
  und Pull Request).
- Versionierung ab jetzt konsequent nach SemVer: jedes Release bekommt
  Version im Manifest, Eintrag hier und GitHub-Tag `v<Version>`.

## [1.0.0] – 2026-09-08

Erstveröffentlichung.

### Hinzugefügt

- Leisten-Widget (`BarWidget.qml`): zeigt **nur ein ♪-Symbol** (der aktuelle
  Titel wandert ins Tooltip – das Widget behält seine Breite), Linksklick
  öffnet/schließt das Panel, Mittelklick schaltet Play/Pause.
- Panel mit vier Werkstätten:
  - **Musik:** Now-Playing mit animiertem Equalizer, Transport
    (Zurück/Play-Pause/Weiter) und Lautstärke-Regler via
    `playerctl`/MPRIS, Fortschrittsbalken mit Zeitangabe „m:ss / m:ss“
    (Klick spult per `playerctl position`), **Shuffle an/aus** (`⇄`) und
    **Loop-Zyklus** aus/Titel/Liste (`↻`, `↻1`, `↻∞`).
  - **Playlist-Browser:** Übersicht der kuratierten Playlisten der Website
    (Die BausLs „Nordwind im Herzen“, Moderne Kinderlieder, Soundtracks
    „1, 2, 3, Peng“, Karaoke, Hörbücher, Coversongs – kuratiert aus
    `familienfabrik.at/musik`). Playlist wählen → Titel via
    `yt-dlp --flat-playlist` laden → **automatisch alle Titel nacheinander
    abspielen** (M3U-Datei in `mpv --no-video`) und Titel-Liste anzeigen;
    Klick auf einen Song startet die Kette ab diesem Titel.
    „▸ alle soundcloud-playlisten laden“ holt den aktuellen Stand des
    SoundCloud-Profils dynamisch dazu (Duplikate entfallen). Eigene
    Quellen frei per URL-Feld importierbar.
  - **Video:** mpv-Launcher für YouTube-Links, -Playlisten und lokale
    Dateien (`/…`, `~/…`), Verlauf „zuletzt genutzt“ (max. 10 Einträge,
    gespeichert in `~/.local/state/familienfabrik/recents.json`).
  - **Fabrik-Videos:** die YouTube-Wiedergabeliste „Animierte Kinderlieder“
    (4 Videos, echte Titel) – einzeln oder komplett nacheinander, mit
    Untertitel-Unterstützung (`--slang=de,en`, sofern vorhanden).
  - **Lesen:** Geschichten von `familienfabrik.at/geschichten` (Fahrrad-Gang
    Bände 1–4 + 14 Einzelnsgeschichten) **direkt im Panel lesen** – Text per
    `curl` laden, HTML-Parser entfernt Navigation/Tags, scrollbarer Text
    mit Rollrad-Anzeige; „↗“ öffnet optional den Browser.
  - **Funk:** News-Feed (RSS) von `familienfabrik.at/feed.xml`; Beiträge
    **klappen direkt im Panel auf** (Beschreibungstext wird mitgeliefert),
    Browser-Öffnen bleibt optionaler Pfeil-Knopf. Darunter
    **Toolbox-Schnellstart** mit 9 Werkzeugen als Chips (QR-Codes,
    Passwörter, Einheiten, Zufallszahlen, Farbpaletten, BMI, Kalorien,
    IP-Adresse, Liquid-Mischer).
- **Theme-Anpassung:** Text folgt `barForeground`, aktive Elemente nutzen
  die Theme-Akzentfarbe `Color.accent` aus `qs.Commons` (aktiver Tab,
  Equalizer, Fortschritt, Lautstärke, Shuffle/Loop, Play-Knöpfe,
  Playlist-Auswahl, News-Aufklapp). Keine hartcodierten Farben.
- `README.md` mit zwei Installations-Varianten (Befehl, ZIP mit
  GitHub-„-main“-Suffix-Hinweis), Bedienung, Datenquellen, FAQ,
  Deinstallation.
- `LICENSE` (MIT), `preview.png`, dieses Changelog.

[Unveröffentlicht]: https://github.com/bussdeeAI/at.familienfabrik_omarchy/compare/v1.1.1...HEAD
[1.1.1]: https://github.com/bussdeeAI/at.familienfabrik_omarchy/releases/tag/v1.1.1
[1.1.0]: https://github.com/bussdeeAI/at.familienfabrik_omarchy/releases/tag/v1.1.0
[1.0.0]: https://github.com/bussdeeAI/at.familienfabrik_omarchy/releases/tag/v1.0.0
