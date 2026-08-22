# TestFlight-Pipeline — Einrichtung

Einmalige Einrichtung für [`.github/workflows/testflight.yml`](../../.github/workflows/testflight.yml).
Der Workflow archiviert bei jedem Push auf `main` das `Toolbox`-Schema (iOS-App
inklusive eingebetteter Watch-App und Dice-Widget) und lädt das Ergebnis nach
TestFlight hoch. Kein App-Store-Release, keine Screenshots.

---

## 1. Repo-Secrets

Anzulegen unter **Settings → Secrets and variables → Actions → New repository secret**.
Die Namen müssen exakt so lauten:

| Secret | Inhalt |
|---|---|
| `BUILD_CERTIFICATE_BASE64` | Apple-Distribution-Zertifikat als `.p12`, base64-kodiert (Schritt 3) |
| `P12_PASSWORD` | Passwort, das du beim `.p12`-Export vergeben hast |
| `KEYCHAIN_PASSWORD` | Frei wählbar. Schützt nur die temporäre Keychain, die am Jobende gelöscht wird — irgendein zufälliger String, z.B. `openssl rand -base64 24` |
| `ASC_KEY_ID` | Key ID des App-Store-Connect-API-Keys, 10 Zeichen (Schritt 2) |
| `ASC_ISSUER_ID` | Issuer ID, eine UUID. Steht über der Key-Liste und gilt für das ganze Team |
| `ASC_KEY_P8_BASE64` | Die `.p8`-Datei des API-Keys, base64-kodiert (Schritt 2) |

Nicht als Secret nötig: die **Team ID** `VA79D2T9W7` steht bereits als
`DEVELOPMENT_TEAM` in `project.pbxproj` und ist damit ohnehin öffentlich. Sie ist
im Workflow als `env.TEAM_ID` hinterlegt.

> Das Repo ist öffentlich. Secrets werden in Workflow-Läufen von Forks **nicht**
> bereitgestellt, und der Workflow triggert ohnehin nur auf `push` zu `main` und
> `workflow_dispatch` — ein Fork-PR kann also nicht an die Signing-Materialien.

---

## 2. App-Store-Connect-API-Key

**App Store Connect → Users and Access → Integrations → App Store Connect API →
Team Keys → +**

- **Rolle: `Admin`.** `App Manager` reicht **nicht**. Sie genügt zwar zum
  Hochladen eines Builds, aber beim `exportArchive` muss der Key per Cloud
  Signing ein Distribution-Profil ausstellen und auf das Cloud-Managed
  Distribution Certificate zugreifen — das ist Admin vorbehalten. Mit
  `App Manager` läuft das Archive noch durch und der Export bricht dann ab mit:

  ```
  error: exportArchive Cloud signing permission error
  error: exportArchive No profiles for 'de.sivery.toolbox' were found
  ```

  Die „No profiles"-Zeilen sind Folgefehler; maßgeblich ist die
  Permission-Zeile darüber. Die Rolle eines bestehenden Keys lässt sich in
  App Store Connect nicht nachträglich ändern — in dem Fall den alten Key
  widerrufen und einen neuen als `Admin` anlegen.
- **Team Key, kein Individual Key.** Individual Keys hängen an einer Person und
  haben keinen Zugriff auf Certificates, Identifiers & Profiles. Der Key muss
  unter **Team Keys** stehen.
- Nach dem Anlegen die `.p8`-Datei herunterladen. **Der Download ist einmalig** —
  Apple gibt sie kein zweites Mal heraus. Geht sie verloren, muss der Key
  widerrufen und neu erzeugt werden.
- **Key ID** (10 Zeichen) und **Issuer ID** (UUID, steht oberhalb der Tabelle) aus
  derselben Ansicht abschreiben.

Key in base64 umwandeln und direkt in die Zwischenablage legen:

```bash
base64 -i ~/Downloads/AuthKey_XXXXXXXXXX.p8 | pbcopy
```

Das ist der Wert für `ASC_KEY_P8_BASE64`. Danach:

```bash
rm ~/Downloads/AuthKey_XXXXXXXXXX.p8
```

---

## 3. Distribution-Zertifikat als `.p12` exportieren

Der Workflow importiert ein **Apple Distribution**-Zertifikat samt privatem
Schlüssel. Existiert lokal noch keines: Xcode → *Settings → Accounts → dein
Account → Manage Certificates → + → Apple Distribution*.

**Schlüsselbundverwaltung** öffnen, links *Anmeldung* → *Meine Zertifikate*.
Das Dreieck vor „Apple Distribution: … (VA79D2T9W7)" aufklappen — darunter muss
ein privater Schlüssel hängen. Fehlt er, ist das Zertifikat für CI unbrauchbar
(dann auf dem Mac neu erzeugen, der es ursprünglich angelegt hat, oder ein neues
ausstellen).

Zertifikat **und** privaten Schlüssel gemeinsam markieren → Rechtsklick →
*2 Objekte exportieren…* → Format **Personal Information Exchange (.p12)** →
speichern als `~/Downloads/distribution.p12`. Das dabei vergebene Passwort ist
`P12_PASSWORD`.

Dann konvertieren:

```bash
base64 -i ~/Downloads/distribution.p12 | pbcopy
```

Das ist der Wert für `BUILD_CERTIFICATE_BASE64`. Anschließend:

```bash
rm ~/Downloads/distribution.p12
```

> `base64` ohne `-i` liest von stdin und bricht bei Binärdateien je nach Shell ab —
> deshalb explizit `-i`. macOS-`base64` umbricht nicht, die Ausgabe ist eine
> einzige Zeile; GitHub-Secrets akzeptieren aber auch mehrzeilige Werte.

Prüfen, dass der Export stimmt, bevor du ihn hochlädst:

```bash
/usr/bin/openssl pkcs12 -in ~/Downloads/distribution.p12 -nokeys -passin pass:DEIN_PASSWORT | /usr/bin/openssl x509 -noout -subject -dates
```

Der Subject muss `Apple Distribution` enthalten und das Zertifikat darf nicht
abgelaufen sein.

> **Der absolute Pfad ist Absicht.** Die Schlüsselbundverwaltung verschlüsselt
> `.p12`-Dateien mit **RC2-40-CBC**. OpenSSL 3 hat RC2 in den Legacy-Provider
> verschoben und standardmäßig abgeschaltet, weshalb ein per Homebrew
> installiertes `openssl` (das im PATH vor dem System liegt) hier aussteigt mit:
>
> ```
> error:0308010C:digital envelope routines:inner_evp_generic_fetch:unsupported:
> ... Algorithm (RC2-40-CBC : 0)
> Could not find certificate from <stdin>
> ```
>
> `/usr/bin/openssl` ist LibreSSL und liest das Format ohne Zusatzflag. Wenn du
> lieber bei OpenSSL 3 bleibst, tut es auch `-legacy`:
>
> ```bash
> openssl pkcs12 -legacy -in ~/Downloads/distribution.p12 -nokeys -passin pass:DEIN_PASSWORT | openssl x509 -noout -subject -dates
> ```
>
> Das betrifft **nur diesen Prüfbefehl**. Die Pipeline selbst nutzt
> `security import`, das über Apples Security-Framework läuft und mit dem
> RC2-Format problemlos umgeht — ein `.p12`, das hier eine Fehlermeldung
> produziert, ist deswegen nicht kaputt.

---

## 4. Vorbereitung in App Store Connect / Developer Portal

Damit der **erste** Upload durchgeht:

1. **Alle drei App IDs müssen existieren** (Developer Portal → Identifiers):
   - `de.sivery.toolbox`
   - `de.sivery.toolbox.watchkitapp`
   - `de.sivery.toolbox.diceWidget` ← wird gern übersehen; das Widget ist ein
     eigenständiges Target und bricht sonst den Archive-Schritt ab.

   Die App ist bereits im Store (ID `1638758005`), die ersten beiden existieren
   also. Prüfe gezielt die dritte.

2. **Build-Nummer muss steigen.** App Store Connect lehnt jeden Build ab, dessen
   `CFBundleVersion` nicht echt größer ist als der höchste bereits existierende
   für dieselbe `CFBundleShortVersionString` (aktuell `1.4`). Der letzte von Hand
   hochgeladene Build war **736**; gerechnet wird
   `BUILD_NUMBER_BASE (1000) + git rev-list --count HEAD`, aktuell also **1206**.
   Falls in App Store Connect für 1.4 schon etwas ≥ 1206 liegt, `BUILD_NUMBER_BASE`
   anheben — an **beiden** Stellen, siehe Abschnitt 5.

3. **Export-Compliance** ist bereits erledigt: `ITSAppUsesNonExemptEncryption` ist
   in `Toolbox/Info.plist` auf `false` gesetzt, TestFlight fragt also nicht nach.

4. **Vereinbarungen.** Unter *Business* darf keine ungezeichnete Vereinbarung
   offen sein — sonst schlägt der Upload mit einer generischen
   „not authorized"-Meldung fehl, die nicht auf die Ursache hinweist.

5. **Xcode-Version.** Das iOS-Target steht auf Deployment Target **26.0**. Der
   Workflow wählt die neueste Xcode-Version mit dem Major aus `XCODE_MAJOR`
   (aktuell `26`) — bewusst gepinnt und nicht „das Neueste, was da ist", damit
   ein neuer Major im Runner-Image nicht unbemerkt die Toolchain wechselt.
   Verschwindet 26 irgendwann aus dem Image, bricht der Step ab und listet die
   vorhandenen Versionen; dann `XCODE_MAJOR` bewusst anheben.

---

## 5. Build-Nummer, Commit-Hash und Datum

Alle drei Werte kommen aus **einer** Quelle: der Build-Phase
**„Stamp Version Metadata (SCRIPT)"**, letzte Phase im `Toolbox`-Target. Sie
leitet sie per `PlistBuddy` aus git ab und schreibt sie direkt in die fertige
`Info.plist` im App-Bundle — nach dem Zusammenbauen, vor dem Signieren.

| Key | Wert | Quelle |
|---|---|---|
| `CFBundleVersion` | `1206` | `BUILD_NUMBER_BASE + git rev-list --count HEAD` |
| `GIT_COMMIT` | `c2fa4e8` | `git rev-parse --short HEAD`, mit `*` bei dreckigem Baum |
| `LAST_UPDATE` | `2026-08-21` | Commit-Datum von `HEAD` |

Lokaler Xcode-Build und CI verwenden **denselben** Mechanismus. Gleicher Commit
ergibt dieselbe Build-Nummer, es gibt keine zwei Nummernräume und keinen
gitignorten Zwischenstand mehr. `Buildnumber.xcconfig` und die frühere Phase
*Update Build Number* sind entfallen.

**Warum nicht über eine xcconfig:** Build-Settings werden einmal beim Build-Start
ausgewertet, eine Build-Phase schreibt aber erst währenddessen. Ein dort
abgelegter Wert landet deshalb immer erst im *nächsten* Build. Bei einem reinen
Hochzähler fällt das nicht auf, bei einem aus `HEAD` abgeleiteten Wert wäre es
schlicht falsch.

**Warum getrennte Keys:** `CFBundleVersion` muss numerisch sein (max. drei
punktgetrennte Integer) und pro `MARKETING_VERSION` echt steigen — ein Hash ist
dort nicht zulässig. Der Info-Screen der App zeigt unter „Build" deshalb
`GIT_COMMIT`, nicht die Zahl.

**Alle drei Bundles tragen dieselben Werte.** App Store Connect lehnt einen
Upload ab, wenn die eingebettete Watch-App nicht exakt dieselbe
`CFBundleShortVersionString` **und** `CFBundleVersion` hat wie die Host-App
(Fehler 90379); beim Widget ist dieselbe Abweichung nur eine Warnung (90473).
Deshalb hat die Stamp-Phase jedes der drei Targets, jeweils als letzte Phase vor
dessen eigener Signatur — die eingebetteten Bundles nachträglich zu patchen
würde ihre Signatur brechen.

`MARKETING_VERSION` steht dafür nur noch **einmal** auf Projektebene. Vorher
hatte jedes Target einen eigenen Wert (1.4 / 1.0.1 / 1.0), was genau diesen
Fehler erzeugt hat. Ein Versionssprung ist jetzt eine einzige Änderung.

Der Workflow prüft das direkt nach dem Archive, statt es `altool` erst nach
Archive und Export finden zu lassen.

**`BUILD_NUMBER_BASE` steht an zwei Stellen:** in der Build-Phase (maßgeblich)
und als `env` im Workflow (nur zur Gegenprobe). Weichen sie voneinander ab,
bricht der Step *Verify stamped build metadata* ab, statt eine überraschende
Nummer hochzuladen.

Zwei Dinge, die die Phase bewusst hart abbricht bzw. markiert:

- **Shallow Clone** → Build-Fehler. `git rev-list --count` liefert dort einen zu
  kleinen Wert; der Workflow checkt deshalb mit `fetch-depth: 0` aus.
- **Dreckiger Arbeitsbaum** → `*` hinter dem Hash. Lokal siehst du das
  typischerweise, in CI nie — der Workflow bricht sogar ab, falls doch.

---

## 6. Release Notes für „What to Test"

Der Workflow **setzt das Feld nicht selbst** — er bereitet den Text auf, du fügst
ihn in App Store Connect ein. Automatisch setzen ginge nur über die
`betaBuildLocalizations`-Ressource der ASC-API, und die ist erst erreichbar,
wenn der Build fertig verarbeitet ist; der Job müsste also 5–15 Minuten pollen.
Für ein Feld, das vor dem Ausliefern ohnehin gegengelesen wird, lohnt das nicht.

Zu finden nach jedem Lauf an zwei Stellen:

- in der **Job-Summary** als Codeblock zum direkten Kopieren
- als Artefakt **`whats-new`**, mit zwei Dateien:
  - `WhatToTest.txt` — nur die Commit-Betreffs, das ist der Text zum Einfügen
  - `changelog-full.txt` — dieselben Commits mit Datum und vollem Body, gedacht
    als Vorlage, falls du daraus etwas Lesbares zusammenfassen lässt

Der Schritt läuft **vor** dem Build, die Notizen liegen also auch dann vor, wenn
das Archiv scheitert. Das Artefakt wird 30 Tage aufbewahrt.

**Bereich:** alle Commits seit dem letzten Tag, der auf `v*` passt. Gibt es
keinen, fällt der Schritt auf den neuesten Tag beliebiger Form zurück, sonst auf
die gesamte Historie — die Summary schreibt jeweils dazu, welche Quelle benutzt
wurde. Aktuell greift der Rückfall: der einzige Tag im Repo ist `1.3.2` vom
August 2023, entsprechend lang ist die Liste. **Sobald du pro Release ein `v1.4`
o.ä. setzt, wird der Bereich sinnvoll.**

**Gefiltert** werden Commits, die ausschließlich `.github/` oder `docs/`
anfassen — reine Pipeline- und Doku-Arbeit interessiert Tester nicht. Sobald ein
Commit *irgendeine* Datei außerhalb dieser beiden Pfade berührt, bleibt er drin.

Die Liste wird **nicht gekürzt**. TestFlight nimmt maximal 4000 Zeichen an; wird
das überschritten, warnt der Lauf und schreibt es in die Summary.

---

## 7. Erster Lauf

Nicht direkt auf `main` pushen zum Testen. Der Workflow hat `workflow_dispatch`:
**Actions → TestFlight → Run workflow**, Branch auswählen, starten.

Läuft er durch, erscheint der Build nach 5–15 Minuten Verarbeitungszeit in
TestFlight. Die Job-Summary zeigt Version, Build-Nummer und Commit.

Scheitert er, liegt unter *Artifacts* ein `build-logs`-Bundle mit dem
`.xcresult` und der verwendeten `ExportOptions.plist`. Die erfahrungsgemäß
häufigsten Ursachen sind im YAML an Ort und Stelle als `PITFALL` kommentiert:
Keychain-Partition-List, fehlende Widget-App-ID, `manageAppVersionAndBuildNumber`
und der `method`-String in den Export-Options.
