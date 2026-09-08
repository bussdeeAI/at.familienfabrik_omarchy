# Changelog

Alle nennenswerten Änderungen an diesem PlugIn werden hier dokumentiert.
Format orientiert an [Keep a Changelog](https://keepachangelog.com/de/),
Versionierung an [SemVer](https://semver.org).

## [1.0.0] – 2026-09-08

### Hinzugefügt

- Leisten-Widget (`BarWidget.qml`): zeigt **nur ein ♪-Symbol** (der aktuelle
  Titel wandert ins Tooltip – das Widget behält seine Breite), Linksklick
  öffnet/schließt das Panel, Mittelklick schaltet Play/Pause.
- Panel mit vier Werkstätten:
  - **Musik:** Now-Playing mit animiertem Equalizer, Transport
    (Zurück/Play-Pause/Weiter) und Lautstärke-Regler via `playerctl`/MPRIS,
    Fortschrittsbalken mit Zeitangabe „m:ss / m:ss“ (Klick spult per
    `playerctl position`), **Shuffle an/aus** (`⇄`) und **Loop-Zyklus**
    aus/Titel/Liste (`↻`, `↻1`, `↻∞`).
  - **Playlist-Browser:** Übersicht ALLER Playlisten der Website
    (Die BausLs „Nordwind im Herzen“, Moderne Kinderlieder **Vol. 1 +
    Vol. 2**, Soundtracks „1, 2, 3, Peng“, Karaoke, Hörbücher, Coversongs
    und das **Mitsingen-Lied „Gute Laune“** – kuratiert aus
    `familienfabrik.at/musik`). Playlist wählen → Titel via
    `yt-dlp --flat-playlist` laden → **automatisch alle Titel nacheinander
    abspielen** (M3U-Datei in `mpv --no-video`) und Titel-Liste anzeigen;
    Klick auf einen Song startet die Kette ab diesem Titel. Das
    Mitsingen-Lied liegt als **direkte MP3-Datei** auf der Website und
    startet deshalb **ohne yt-dlp** sofort; `↗ text` öffnet die Mitsing-
    Seite, auf der der Text Zeile für Zeile zur Musik mitläuft.
    „▸ alle soundcloud-playlisten laden“ holt den aktuellen Stand des
    SoundCloud-Profils dynamisch dazu (Duplikate entfallen). Eigene
    Quellen weiterhin frei per URL-Feld importierbar.
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
  Playlist-Auswahl, News-Aufklapp). Keine hartcodierten Farben mehr.
- `README.md` mit zwei Installations-Varianten (Befehl, ZIP mit
  GitHub-„-main“-Suffix-Hinweis), Bedienung, Datenquellen, FAQ,
  Deinstallation.
- `LICENSE` (MIT), `preview.png`, dieses Changelog.

### Technisches

- Reine Qt-Quick/Quickshell-Umsetzung, keine externen QML-Pakete.
- System-Integration ausschließlich über kurzlebige Prozessaufrufe:
  `playerctl`, `mpv`, `yt-dlp`, `curl`, `xdg-open`, `bash`.
- Panel-Lifecycle nach Quattro-Vertrag (`KeyboardPanel` + `PanelKeyCatcher`,
  ESC schließt, Tab-Switch unterstützt).
- MPRIS-Polling alle 2 s (Titel, Interpret, Status, Lautstärke, Position,
  Titellänge, Shuffle- und Loop-Status); Lautstärke-Regler entprellt (180 ms).
- Position via `playerctl position` (Sekunden), Titellänge über
  `mpris:length` (Mikrosekunden → Sekunden).
- Shuffle/Loop: Setzen per `playerctl shuffle toggle` bzw.
  `playerctl loop <None|Track|Playlist>`, Rücklesen über den Status-Poll.
- Sequentielle Wiedergabe: `playFrom(index)` schreibt eine M3U-Datei nach
  `~/.local/state/familienfabrik/playlist.m3u` (nur Titel ab dem gewählten
  Index) und startet `mpv --no-video --playlist=…` in einem einzigen
  `bash -c`-Aufruf (atomar schreiben + starten). Ein neuer Start beendet
  die vorherige Wiedergabe („ein Player“-Prinzip, sauberes MPRIS-Bild).
- Geschichten-Parser (`parseStory`): isoliert `<main>`/`<article>`, sammelt
  H1 + Absätze, löst CDATA & gängige HTML-Entitäten, begrenzt auf ~4500
  Zeichen für flinke Panels.
- RSS-Beschreibungen: CDATA-Hülse wird vor dem Tag-Strippen gelöst
  (Reihenfolge wichtig), Ergebnis ist reiner Klartext.
- Kataloge in `Model.js` gepflegt aus den echten Website-Inhalten
  (Stand 09/2026): `FABRIK_PLAYLISTS` (8 – alle Alben der Musik-Seite
  inkl. Kinderlieder Vol. 2 und Mitsingen-MP3), `GESCHICHTEN` (18),
  `TOOLBOX` (9), `FABRIK_VIDEOS` (4), `PLAYLISTS_SOURCE`,
  `YOUTUBE_PLAYLIST_URL`.
- Direkte Audio-Dateien (`isAudioFile`): Katalog-Einträge mit `file`
  statt `url` werden ohne `yt-dlp` sofort zur eintiteligen M3U und
  abgespielt; `page`-Feld liefert optional eine Begleit-Seite.
- Validierung: 122 automatische Prüfungen (Manifest-Schema, Klammer-Balance,
  ID-Eindeutigkeit, Lifecycle-Vertrag, Parser-Schnelltests, Kataloge) –
  siehe `tools/validate-plugin.mjs`.

## [Geplant] – Ideen für 1.1

- Fabrik-Funk: Kategorien-Filter (Ankündigungen, Neuigkeiten, Tonstudio).
- Optional: Familienradar-Ausflugstipp des Tages in der Leiste.
- Optionale yt-dlp-Aktualisierung im Hintergrund erkennen und im Panel
  darauf hinweisen.
