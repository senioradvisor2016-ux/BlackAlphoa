# BlackAlphoa

## Alpha Juno-2 Editor (JUCE)

Det här repot innehåller en **standalone JUCE-app** som är tänkt som en startpunkt för en Alpha Juno-2 editor/librarian via **MIDI SysEx**.

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