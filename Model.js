// =============================================================================
//  Model.js · Familienfabrik.at · at.familienfabrik.omarchy
//
//  Reine Hilfsfunktionen für BarWidget.qml und Panel.qml:
//  · Parsen der playerctl-Ausgaben (Felder, Lautstärke)
//  · Katalog der Website (Playlisten, Geschichten, Toolbox, Videos)
//  · Parsen der yt-dlp-Antworten (Tracks UND Playlist-Übersicht)
//  · Parsen des Fabrik-Funk-RSS-Feeds (inkl. Beschreibung)
//  · Geschichten-Parser (HTML → lesbarer Text für das Panel)
//  · Verlauf „zuletzt genutzte Videos“ (JSON-Datei)
//  · kleine Text-/Format-Helfer
//
//  Bewusst pragmatisch (Regex statt XML-Parser): QML-JavaScript bringt keine
//  DOM-API mit, die Quellen sind wohlgeformt und die Felder werden fehlert-
//  olerant ausgewertet. Als .pragma-library geteilt und ohne QML-Zustand.
// =============================================================================

.pragma library

// --- Fabrik-Katalog (Quelle: familienfabrik.at, Stand 09/2026) ---------------
// Kuratierte Playlisten der Musik-Seite (familienfabrik.at/musik) – ALLE dort
// gelisteten Alben, in Reihenfolge der Seite. Die Adressen stammen aus den
// Album-Seiten der Website (SoundCloud- und hearthis.at-Einbettungen) und
// lassen sich von yt-dlp direkt auflösen. „Moderne Kinderlieder“ umfasst auf
// der Website zwei Playlisten (Vol. 1 + Vol. 2) – beide stehen hier.
// Das Mitsingen-Lied „Gute Laune“ liegt als direkte MP3-Datei auf der Website
// („file“ statt „url“): es läuft sofort, ganz OHNE yt-dlp; „page“ verweist auf
// die Mitsing-Seite, auf der der Text zur Musik mitläuft.
const FABRIK_PLAYLISTS = [
    { name: "Die BausLs",            note: "unsere hausband · „nordwind im herzen“",
      url: "https://api.soundcloud.com/playlists/soundcloud:playlists:2173649216" },
    { name: "Moderne Kinderlieder · Vol. 1", note: "kinderlieder vol. 1 · familienfabrik",
      url: "https://api.soundcloud.com/playlists/soundcloud:playlists:2172950636" },
    { name: "Moderne Kinderlieder · Vol. 2", note: "kinderlieder vol. 2 · familienfabrik",
      url: "https://api.soundcloud.com/playlists/soundcloud:playlists:2204299847" },
    { name: "Soundtracks",           note: "„1, 2, 3, peng“ · die fahrrad-gang (ost)",
      url: "https://api.soundcloud.com/playlists/soundcloud:playlists:2172980420" },
    { name: "Karaoke",               note: "instrumentals · tonstudio lübeck",
      url: "https://api.soundcloud.com/playlists/soundcloud:playlists:405742340" },
    { name: "Hörbücher",             note: "„lukas die kleine springspinne“ · vorgelesen",
      url: "https://hearthis.at/bussdee/dadb01-lukas/" },
    { name: "Coversongs",            note: "bausls & friends · eigene aufnahmen",
      url: "https://hearthis.at/bausls/set/coversongsbynise/" },
    { name: "Mitsingen: „gute laune“", note: "text läuft mit · direktes mp3 ohne yt-dlp",
      file: "https://familienfabrik.at/dateien/2026/08/a03ec75382a92979.mp3",
      page: "https://familienfabrik.at/mitsingen/gute-laune" }
]

// „Alle Playlisten“-Quelle: das SoundCloud-Profil der Fabrik listet alle dort
// veröffentlichten Playlisten auf (dynamisch, immer aktuell).
const PLAYLISTS_SOURCE = "https://soundcloud.com/familienfabrik/playlists"

// Geschichten-Katalog (familienfabrik.at/geschichten): vier Fahrrad-Gang-
// Bände (Lesen-Seiten) plus die Einzelnsgeschichten.
// „kind“: "band" = Buchreihe, "geschichte" = Einzelgeschichte.
const GESCHICHTEN = [
    { kind: "band", title: "Band 1: Startschuss für die Fahrrad-Gang",
      path: "/lesen/1-2-3-peng-die-fahrrad-gang-band-1-startschuss-fuer-die-fahrrad-gang/1" },
    { kind: "band", title: "Band 2: Das Geheimnis der alten Backstube",
      path: "/lesen/1-2-3-peng-die-fahrrad-gang-band-2-das-geheimnis-der-alten-backstube/1" },
    { kind: "band", title: "Band 3: Das Geheimnis der Salzspeicher",
      path: "/lesen/1-2-3-peng-die-fahrrad-gang-band-3-das-geheimnis-der-salzspeicher/1" },
    { kind: "band", title: "Band 4: Die Drachenboot-Sabotage",
      path: "/lesen/1-2-3-peng-die-fahrrad-gang-band-4-die-drachenboot-sabotage/1" },
    { kind: "geschichte", title: "Das Geheimnis mit dem Apfelkuchen",
      path: "/geschichte/das-geheimnis-mit-dem-apfelkuchen" },
    { kind: "geschichte", title: "Der Bowlingkugel-Zauber",
      path: "/geschichte/der-bowlingkugel-zauber" },
    { kind: "geschichte", title: "Lukas, die kleine Springspinne",
      path: "/geschichte/lukas-die-kleine-springspinne" },
    { kind: "geschichte", title: "Das Grillfest im Altenheim",
      path: "/geschichte/das-grillfest-im-altenheim-begegnungen-die-bleiben" },
    { kind: "geschichte", title: "Mini und der verlorene Hausschuh",
      path: "/geschichte/mini-und-der-verlorene-hausschuh-eine-kleine-geschichte" },
    { kind: "geschichte", title: "Papa und die Taschenlampe im Dunkeln",
      path: "/geschichte/papa-und-die-taschenlampe-im-dunkeln" },
    { kind: "geschichte", title: "Mini lernt Fahrrad fahren",
      path: "/geschichte/mini-lernt-fahrrad-fahren-ein-grosser-schritt" },
    { kind: "geschichte", title: "Die Bibliotheks-Schatzsuche",
      path: "/geschichte/die-bibliotheks-schatzsuche-lesen-als-abenteuer" },
    { kind: "geschichte", title: "Das Fahrrad, das den Blues sang",
      path: "/geschichte/das-fahrrad-das-den-blues-sang-eine-besondere-geschichte" },
    { kind: "geschichte", title: "Mini hilft im Garten",
      path: "/geschichte/mini-hilft-im-garten-kleine-haende-grosse-hilfe" },
    { kind: "geschichte", title: "Der große Apfelkuchen-Test",
      path: "/geschichte/der-grosse-apfelkuchen-test-welcher-ueberzeugt" },
    { kind: "geschichte", title: "In der Kletterhalle",
      path: "/geschichte/in-der-kletterhalle-ein-erlebnisbericht" },
    { kind: "geschichte", title: "Die geliehene Gitarre",
      path: "/geschichte/die-geliehene-gitarre-eine-persoenliche-geschichte" },
    { kind: "geschichte", title: "Das große Boßel-Fest",
      path: "/geschichte/das-grosse-bossel-fest" }
]

// Toolbox-Katalog (familienfabrik.at/toolbox): kleine Online-Werkzeuge.
// Interaktive Werkzeuge bleiben Web-Apps – das Panel zeigt sie als Liste
// und öffnet die gewählte Seite im Browser.
const TOOLBOX = [
    { title: "QR-Codes",      path: "/toolbox/qr-code-generator" },
    { title: "Passwörter",    path: "/toolbox/passwort-generator" },
    { title: "Einheiten",     path: "/toolbox/einheitenumrechner" },
    { title: "Zufallszahlen", path: "/toolbox/zufallszahlengenerator" },
    { title: "Farbpaletten", path: "/toolbox/farbpaletten-generator" },
    { title: "BMI",           path: "/toolbox/bmi-rechner" },
    { title: "Kalorien",      path: "/toolbox/kalorien-bedarfsrechner" },
    { title: "IP-Adresse",    path: "/toolbox/wie-ist-meine-ip" },
    { title: "Liquid-Mischer", path: "/toolbox/liquidrechner-fuer-selbstmischer" }
]

// Fabrik-Videos: die YouTube-Wiedergabeliste „Animierte Kinderlieder“
// (Untertitel inklusive – mpv lädt deutsche/englische Untertitel, sofern
// das Video sie mitbringt).
const YOUTUBE_PLAYLIST_URL =
    "https://www.youtube.com/playlist?list=PLV4Cqp2ak_1wTIJ9HeO5YwoyDAJ4dqFim"
const FABRIK_VIDEOS = [
    { title: "Gute Laune! – Kinderlied zum Tanzen & Mitsingen",
      url: "https://www.youtube.com/watch?v=qXF5qQLujxA" },
    { title: "FamilienFabrik – der Kanal",
      url: "https://www.youtube.com/watch?v=u_-lsAfQsQg" },
    { title: "Der Morgen-Sprint – wenn Kinder nicht aufstehen wollen",
      url: "https://www.youtube.com/watch?v=EqMnmVi8VVw" },
    { title: "Brot im Regal – animiertes Familien-Musikvideo",
      url: "https://www.youtube.com/watch?v=VxlPAEf8FSg" }
]

// --- playerctl ---------------------------------------------------------------

// „key=value“-Zeilen (siehe BarWidget.qml) in ein Objekt überführen.
// Leere oder Klammern-Ausgaben wie „(default)“ werden übersprungen.
function parseFields(text) {
    const out = {}
    const lines = String(text).split("\n")
    for (let i = 0; i < lines.length; i++) {
        const eq = lines[i].indexOf("=")
        if (eq < 0) continue
        const key = lines[i].slice(0, eq).trim()
        const value = lines[i].slice(eq + 1).trim()
        if (value === "" || value === "(default)" || value === "Not available")
            continue
        out[key] = value
    }
    return out
}

// Lautstärke normalisieren: playerctl meldet je nach Version 0.0–1.0
// (z. B. „0.500000“) oder Prozent (z. B. „50.00%“).
// Rückgabe NaN, wenn nichts Verwertbares enthalten ist.
function parseVolume(text) {
    const s = String(text).replace("%", "").trim()
    if (s === "") return NaN
    const v = parseFloat(s)
    if (isNaN(v)) return NaN
    return v > 1 ? v / 100 : v
}

// Shuffle-Status normalisieren: „On“/„Off“ → true/false, sonst null
// (null = keine gültige Antwort, Zustand unverändert lassen).
function parseOnOff(text) {
    const s = String(text).trim()
    if (s === "On") return true
    if (s === "Off") return false
    return null
}

// Loop-Status normalisieren: „None“ | „Track“ | „Playlist“, sonst ""
// (leer = keine gültige Antwort, Zustand unverändert lassen).
function parseLoop(text) {
    const s = String(text).trim()
    if (s === "None" || s === "Track" || s === "Playlist") return s
    return ""
}

// --- Playlisten (yt-dlp) -----------------------------------------------------

// JSON-Antwort von „yt-dlp --flat-playlist -J <url>“ in Titel/URL-Paare
// umwandeln. Unterstützt Listen (entries[]) und einzelne Tracks.
// Ober Grenze 200 Einträge, damit die QML-Liste flink bleibt.
function parseYtDlp(text) {
    const items = []
    if (!text || text.trim() === "") return { items: items, error: "keine Antwort" }
    let data
    try {
        data = JSON.parse(text)
    } catch (e) {
        return { items: items, error: "unlesbare Antwort" }
    }

    // Fall 1: ganze Playlist mit entries[]
    if (data && data._type === "playlist" && data.entries) {
        for (let i = 0; i < data.entries.length && items.length < 200; i++) {
            const e = data.entries[i]
            if (!e) continue
            const url = e.webpage_url || e.url || ""
            if (!url) continue
            items.push({
                title: e.title || "ohne Titel",
                url: String(url)
            })
        }
        return { items: items, error: items.length === 0 ? "leere Playlist" : "" }
    }

    // Fall 2: einzelner Track (direkt geöffneter Link)
    if (data && (data.webpage_url || data.url)) {
        items.push({
            title: data.title || "ohne Titel",
            url: String(data.webpage_url || data.url)
        })
        return { items: items, error: "" }
    }

    return { items: items, error: "unbekanntes Format" }
}

// --- Fabrik-Funk (RSS) -------------------------------------------------------

// Minimaler RSS-Parser: <item>…</item> splitten, danach Titel/Link/Datum
// entnehmen. CDATA-Hüllen und die häufigsten XML-Entitäten werden gelöst.
function parseRss(xml) {
    const items = []
    if (!xml || xml.indexOf("<item") < 0) return items

    const blocks = xml.split(/<item[\s>]/).slice(1)
    for (let i = 0; i < blocks.length && items.length < 30; i++) {
        const block = blocks[i].split("</item>")[0]

        const title = decodeXml(tagText(block, "title"))
        const link = tagText(block, "link")
        const date = tagText(block, "pubDate")
        // CDATA-Hülle ZUERST lösen, danach HTML-Tags entfernen – sonst
        // frisst der Tag-Stripper den CDATA-Anfang mit.
        const description = stripTags(decodeXml(tagText(block, "description")))

        if (title !== "" || link !== "") {
            items.push({
                title: title !== "" ? title : "ohne Titel",
                link: link,
                date: fmtDate(date),
                description: description
            })
        }
    }
    return items
}

// ersten Inhalt von <tag>…</tag> liefern (CDATA-fest).
function tagText(block, tag) {
    const m = block.match(new RegExp("<" + tag + "[^>]*>([\\s\\S]*?)</" + tag + ">", "i"))
    return m ? m[1].trim() : ""
}

// CDATA entfernen + gängige XML-/HTML-Entitäten dekodieren.
function decodeXml(s) {
    let out = String(s)
    const cdata = out.match(/^<!\[CDATA\[([\s\S]*?)\]\]>$/)
    if (cdata) out = cdata[1]
    return out
        .replace(/&amp;/g, "&")
        .replace(/&lt;/g, "<")
        .replace(/&gt;/g, ">")
        .replace(/&quot;/g, "\"")
        .replace(/&#39;/g, "'")
        .replace(/&apos;/g, "'")
        .replace(/&middot;/g, "·")
        .replace(/&ndash;/g, "–")
        .replace(/&mdash;/g, "—")
        .replace(/&hellip;/g, "…")
        .replace(/&nbsp;/g, " ")
        .replace(/&#(\d+);/g, function (m, code) {
            return String.fromCharCode(parseInt(code, 10))
        })
}

// HTML-Tags entfernen und Whitespace normalisieren (für RSS-Beschreibungen
// und Geschichten-Seiten). Tags werden ohne Ersatzzeichen entfernt – die
// trennenden Leerzeichen stehen bereits im Quelltext.
function stripTags(s) {
    return String(s)
        .replace(/<[^>]+>/g, "")
        .replace(/\s+/g, " ")
        .trim()
}

// --- Geschichten (HTML → Text) ----------------------------------------------

// Lesetext aus einer Geschichten-Seite ziehen: <main> bzw. <article>
// isolieren, Überschrift + Absätze sammeln, Tags lösen. Auf ~4500 Zeichen
// begrenzt, damit das Panel auch bei langen Geschichten flink bleibt.
// Leerer Rückgabewert = „nicht lesbar“ (Panel zeigt dann einen Hinweis).
function parseStory(html) {
    if (!html) return ""
    const source = String(html)
    const area = source.match(/<(?:main|article)[^>]*>([\s\S]*?)<\/(?:main|article)>/i)
    const body = area ? area[1] : source

    const chunks = []
    const head = body.match(/<h1[^>]*>([\s\S]*?)<\/h1>/i)
    if (head) {
        const t = decodeXml(stripTags(head[1]))
        if (t !== "") chunks.push(t)
    }

    const paras = body.match(/<p[^>]*>[\s\S]*?<\/p>/gi) || []
    for (let i = 0; i < paras.length; i++) {
        const t = decodeXml(stripTags(paras[i]))
        if (t.length > 1) chunks.push(t)
    }

    let out = chunks.join("\n\n")
    if (out.length > 4500) out = out.slice(0, 4500) + " …"
    return out
}

// „Mon, 08 Sep 2026 10:00:00 +0000“ oder ISO → „08.09.26“.
function fmtDate(s) {
    if (!s) return ""
    const d = new Date(s)
    if (isNaN(d.getTime())) return String(s).slice(0, 10)
    const dd = ("0" + d.getDate()).slice(-2)
    const mm = ("0" + (d.getMonth() + 1)).slice(-2)
    const yy = String(d.getFullYear()).slice(-2)
    return dd + "." + mm + "." + yy
}

// --- Video-Verlauf -------------------------------------------------------------

// Gespeicherter Verlauf aus ~/.local/state/familienfabrik/recents.json.
function parseRecents(text) {
    if (!text || text.trim() === "") return []
    try {
        const data = JSON.parse(text)
        if (!Array.isArray(data)) return []
        // Nur gültige Einträge behalten (robust gegen alte Formate).
        const out = []
        for (let i = 0; i < data.length && out.length < 10; i++) {
            const e = data[i]
            if (e && typeof e.url === "string" && e.url !== "") {
                out.push({ title: e.title || shortUrl(e.url), url: e.url })
            }
        }
        return out
    } catch (err) {
        return []
    }
}

// --- Text-Helfer ---------------------------------------------------------------

// Sekunden → „m:ss“ (ab einer Stunde „h:mm:ss“).
function fmtTime(seconds) {
    const s = Math.max(0, Math.floor(Number(seconds) || 0))
    const h = Math.floor(s / 3600)
    const m = Math.floor((s % 3600) / 60)
    const sec = s % 60
    const mm = h > 0 ? ("0" + m).slice(-2) : String(m)
    return (h > 0 ? h + ":" : "") + mm + ":" + ("0" + sec).slice(-2)
}

// Länge begrenzen: „Sehr langer Tit…“
function ellipsis(s, max) {
    const t = String(s)
    return t.length > max ? t.slice(0, max - 1) + "…" : t
}

// „https://www.youtube.com/watch?v=xyz“ → „youtube.com/watch?v=xyz“ (gekürzt).
function shortUrl(url) {
    const s = String(url)
    const stripped = s.replace(/^https?:\/\//, "").replace(/^www\./, "")
    return ellipsis(stripped, 40)
}

// Grobe URL-Prüfung für Eingabefelder.
function isHttpUrl(s) {
    return /^https?:\/\/\S+$/.test(String(s).trim())
}

// Direkte Audio-Datei (mp3/ogg/opus/m4a/wav/flac)? Solche Links spielt mpv
// ohne Umweg über yt-dlp direkt ab – praktisch für Einbettungs-Dateien wie
// das Mitsingen-Lied der Website.
function isAudioFile(s) {
    return /^https?:\/\/\S+\.(mp3|ogg|opus|m4a|wav|flac)(\?\S*)?$/i
        .test(String(s).trim())
}

// M3U-Playliste aus Titel-URL-Paaren bauen: mpv spielt die Liste der Reihe
// nach ab; #EXTINF-Zeilen liefern die Titel für Player-Anzeigen. „fromIndex“
// startet die Liste ab einem bestimmten Titel (Klick in der Titelliste).
function buildM3U(items, fromIndex) {
    const lines = ["#EXTM3U"]
    const start = Math.max(0, fromIndex || 0)
    for (let i = start; i < items.length; i++) {
        const it = items[i]
        if (!it || !it.url) continue
        lines.push("#EXTINF:-1," + String(it.title || "ohne titel"))
        lines.push(String(it.url))
    }
    return lines.join("\n")
}
