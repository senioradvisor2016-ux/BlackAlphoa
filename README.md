# BlackAlphoa

## Alpha Juno-2 Editor (JUCE)

Det här repot innehåller en **standalone JUCE-app** som är tänkt som en startpunkt för en Alpha Juno-2 editor/librarian via **MIDI SysEx**.

### Bygga (macOS)

Förutsättningar:

- **Xcode Command Line Tools**:

```bash
xcode-select --install
```

- **CMake** (valfritt: Ninja). Enkelt via Homebrew:

```bash
brew install cmake ninja
```

Bygg:

```bash
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build
```

Kör (macOS bygger en `.app`-bundle):

```bash
open build/AlphaJuno2Editor_artefacts/Release/"Alpha Juno-2 Editor".app
```

Alternativt kan du generera ett Xcode-projekt:

```bash
cmake -B build-xcode -G Xcode
cmake --build build-xcode --config Release
```

### Bygga (Linux)

Installera vanliga JUCE-beroenden (GTK + ljud/MIDI):

```bash
sudo apt-get update
sudo apt-get install -y build-essential cmake ninja-build \
  libasound2-dev \
  libx11-dev libxext-dev libxinerama-dev libxrandr-dev libxcursor-dev \
  libfreetype6-dev libfontconfig1-dev \
  libgtk-3-dev
```

Bygg sedan med CMake:

```bash
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build
```

Kör appen:

```bash
./build/AlphaJuno2Editor_artefacts/Release/"Alpha Juno-2 Editor"
```

### Status / Vad som finns nu

- **MIDI In/Out** val + logg
- **Load/Save** av `.syx` (första SysEx-blocket i filen)
- **Send loaded SysEx** (skickar filens SysEx rakt av)
- **Roland RQ1/DT1 builder** (redigerbara Device/Model ID samt Address/Size)
- En **placeholder parameterlista** (32 st 0..127) som kan skickas som DT1 (för att validera flödet)

### Viktigt

Alpha Juno-2 har en specifik SysEx/parameter-map. I den här versionen är den **inte implementerad** ännu (appens UI och transporten är på plats).

## BlackAlpha (SwiftUI, macOS)

Det finns även en macOS-app byggd i **Swift/SwiftUI + CoreMIDI** i `BlackAlphaJunoEditor/`.

### Köra / Systemtest (macOS)

Öppna `BlackAlphaJunoEditor/Package.swift` i Xcode och kör target `BlackAlphaJunoEditor`.

Manuell GUI-checklista (snabb “systemtest”):

- **Connection Wizard**
  - Öppnas automatiskt om ingen MIDI Out är vald
  - Välj MIDI Out/In, Merge, Channel
  - Klicka **Test SysEx (IPR)** → status/logg visar att SysEx skickats
- **Editor**
  - Verifiera att det finns **36 parametrar** (0x00–0x23) i sektioner
  - Ändra ett värde → **Dirty: N** ökar
  - **SEND → Send Changed** skickar bara dirty och minskar dirty-count
  - **SEND → Send All** skickar 36 (progress + Cancel syns)
- **A/B**
  - Byt slot A/B → värden byts utan att sända
  - Copy/Swap/Revert fungerar och påverkar Dirty korrekt per slot
- **Librarian**
  - Load `.syx` → lista 64 tones + rename + export
  - Drag & drop `.syx/.fxb/.db` fungerar
  - Favoriter/tags sparas lokalt och filter fungerar

Automatiska tester körs i GitHub Actions på macOS:
- `swift test` + `swift build -c release`