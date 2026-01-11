import SwiftUI
import UniformTypeIdentifiers
import AlphaJunoCore

struct LibrarianView: View
{
    @ObservedObject var model: LibrarianViewModel
    @State private var searchText: String = ""
    @State private var isDropping: Bool = false
    @State private var favoritesOnly: Bool = false
    @State private var tagFilter: String = ""
    @State private var newTag: String = ""

    @EnvironmentObject private var toneMeta: ToneMetaStore

    var body: some View
    {
        VStack(alignment: .leading, spacing: 10)
        {
            HStack
            {
                Text("Librarian")
                    .font(.headline)
                Spacer()
                Button("Load .SYX") { model.showImporter = true }
                Button("Import .FXB") { model.showFXBImporter = true }
                Button("Import .DB") { model.showDBImporter = true }
                Button("Export .SYX") { model.prepareExport() }
                    .disabled(model.bank == nil)
                Button("Export .FXB") { model.prepareFXBExport() }
                    .disabled(model.blackAlphaPrograms.isEmpty)
                Button("Export .DB") { model.prepareDBExport() }
                    .disabled(model.blackAlphaDBPrograms.isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            HStack(spacing: 10)
            {
                TextField("Search tones…", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                if !searchText.isEmpty
                {
                    Button("Clear") { searchText = "" }
                }

                Toggle("Favorites", isOn: $favoritesOnly)
                    .toggleStyle(.switch)
            }
            .padding(.horizontal, 12)

            Divider()

            HSplitView
            {
                List(selection: $model.selectedToneIndex)
                {
                    ForEach(filteredTones(), id: \.index) { t in
                        HStack
                        {
                            Text(String(format: "%02d", t.index + 1))
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 34, alignment: .trailing)
                            Text(t.name)
                                .lineLimit(1)
                            Spacer()

                            if let bankId = model.currentBankId
                            {
                                let fav = toneMeta.isFavorite(bankId: bankId, toneIndex: t.index)
                                Image(systemName: fav ? "star.fill" : "star")
                                    .font(.caption)
                                    .foregroundStyle(fav ? .yellow : .secondary)
                            }
                        }
                        .tag(Optional(t.index))
                    }
                }
                .frame(minWidth: 240)
                .onChange(of: model.selectedToneIndex) { _, newValue in
                    guard let newValue else { return }
                    if let row = model.tones.first(where: { $0.index == newValue })
                    {
                        model.editName = row.name
                    }
                }

                VStack(alignment: .leading, spacing: 10)
                {
                    if let bankId = model.currentBankId, let idx = model.selectedToneIndex
                    {
                        HStack
                        {
                            Toggle("Favorite", isOn: Binding(get: {
                                toneMeta.isFavorite(bankId: bankId, toneIndex: idx)
                            }, set: { v in
                                toneMeta.setFavorite(bankId: bankId, toneIndex: idx, v)
                            }))
                            .toggleStyle(.switch)

                            Spacer()

                            Menu("Tag filter")
                            {
                                Button("None") { tagFilter = "" }
                                ForEach(allTags().sorted(), id: \.self) { t in
                                    Button(t) { tagFilter = t }
                                }
                            }
                        }

                        let tags = toneMeta.tags(bankId: bankId, toneIndex: idx)
                        if !tags.isEmpty
                        {
                            HStack(spacing: 6)
                            {
                                Text("Tags:")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                ForEach(tags, id: \.self) { t in
                                    Button(t)
                                    {
                                        toneMeta.removeTag(bankId: bankId, toneIndex: idx, tag: t)
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }
                        }

                        HStack(spacing: 8)
                        {
                            TextField("Add tag…", text: $newTag)
                                .textFieldStyle(.roundedBorder)
                            Button("Add")
                            {
                                toneMeta.addTag(bankId: bankId, toneIndex: idx, tag: newTag)
                                newTag = ""
                            }
                            .disabled(newTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }

                        Divider()
                    }

                    if !model.blackAlphaPrograms.isEmpty
                    {
                        Text("Imported .FXB (names only)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        ScrollView
                        {
                            VStack(alignment: .leading, spacing: 4)
                            {
                                ForEach(model.blackAlphaPrograms, id: \.index) { p in
                                    Text("\(p.index + 1). \(p.name)")
                                        .font(.system(.caption, design: .monospaced))
                                        .lineLimit(1)
                                }
                            }
                        }
                        .frame(maxHeight: 140)
                        Divider()
                    }

                    if !model.blackAlphaDBPrograms.isEmpty
                    {
                        Text("Imported .DB (Programs)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("Count: \(model.blackAlphaDBPrograms.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Divider()
                    }

                    Text("Tone Name (max 10 chars)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    TextField("Tone name", text: $model.editName)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: model.editName) { _, newValue in
                            if newValue.count > 10 { model.editName = String(newValue.prefix(10)) }
                            model.validateToneName()
                        }

                    HStack
                    {
                        Text("\(model.editName.count)/10")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Write name into bank")
                        {
                            model.applyRename()
                        }
                        .disabled(model.selectedToneIndex == nil || model.bank == nil || !model.isToneNameValid)
                    }

                    if let err = model.error
                    {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    Spacer()
                }
                .padding(12)
            }
        }
        .overlay
        {
            if isDropping
            {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(.blue, style: StrokeStyle(lineWidth: 3, dash: [8, 6]))
                    .padding(12)
                    .overlay(
                        Text("Drop .syx / .fxb / .db")
                            .font(.headline)
                            .padding(12)
                            .background(.ultraThinMaterial)
                            .cornerRadius(10)
                    )
            }
        }
        .onDrop(of: [UTType.fileURL], isTargeted: $isDropping) { providers in
            model.handleDrop(providers: providers)
        }
        .fileImporter(
            isPresented: $model.showImporter,
            allowedContentTypes: [UTType(filenameExtension: "syx") ?? .data],
            allowsMultipleSelection: false
        ) { result in
            model.handleImportResult(result)
        }
        .fileImporter(
            isPresented: $model.showFXBImporter,
            allowedContentTypes: [UTType(filenameExtension: "fxb") ?? .data],
            allowsMultipleSelection: false
        ) { result in
            model.handleFXBImportResult(result)
        }
        .fileImporter(
            isPresented: $model.showDBImporter,
            allowedContentTypes: [UTType(filenameExtension: "db") ?? .data],
            allowsMultipleSelection: false
        ) { result in
            model.handleDBImportResult(result)
        }
        .fileExporter(
            isPresented: $model.showExporter,
            document: model.exportDocument,
            contentType: UTType(filenameExtension: "syx") ?? .data,
            defaultFilename: model.exportFilename
        ) { result in
            model.handleExportResult(result)
        }
        .fileExporter(
            isPresented: $model.showFXBExporter,
            document: model.exportFXBDocument,
            contentType: UTType(filenameExtension: "fxb") ?? .data,
            defaultFilename: model.exportFXBFilename
        ) { result in
            model.handleFXBExportResult(result)
        }
        .fileExporter(
            isPresented: $model.showDBExporter,
            document: model.exportDBDocument,
            contentType: UTType(filenameExtension: "db") ?? .data,
            defaultFilename: model.exportDBFilename
        ) { result in
            model.handleDBExportResult(result)
        }
    }

    private func filteredTones() -> [LibrarianViewModel.ToneRow]
    {
        let base = model.filteredTones(search: searchText)
        guard let bankId = model.currentBankId else { return base }

        var out = base
        if favoritesOnly
        {
            out = out.filter { toneMeta.isFavorite(bankId: bankId, toneIndex: $0.index) }
        }
        if !tagFilter.isEmpty
        {
            out = out.filter { toneMeta.tags(bankId: bankId, toneIndex: $0.index).contains(tagFilter) }
        }
        return out
    }

    private func allTags() -> Set<String>
    {
        guard let bankId = model.currentBankId else { return [] }
        var s: Set<String> = []
        for t in model.tones
        {
            s.formUnion(toneMeta.tags(bankId: bankId, toneIndex: t.index))
        }
        return s
    }
}

@MainActor
final class LibrarianViewModel: ObservableObject
{
    struct ToneRow
    {
        let index: Int
        let name: String
    }

    struct BlackAlphaProgramRow
    {
        let index: Int
        let name: String
        let data: String
    }

    struct BlackAlphaDBProgramRow
    {
        let id: Int
        let name: String
        let category: String?
        let author: String?
        let rating: Int?
        let favorite: Bool
        let notes: String?
        let programDataLength: Int
    }

    @Published var bank: SyxBank?
    @Published var tones: [ToneRow] = []
    @Published var blackAlphaPrograms: [BlackAlphaProgramRow] = []
    @Published var blackAlphaDBPrograms: [BlackAlphaDBProgramRow] = []
    private var blackAlphaDBFullPrograms: [BlackAlphaProgramsDB.Program] = []
    @Published var currentBankId: String?

    @Published var selectedToneIndex: Int?
    @Published var editName: String = ""
    @Published var error: String?
    @Published var isToneNameValid: Bool = true

    @Published var showImporter: Bool = false
    @Published var showFXBImporter: Bool = false
    @Published var showDBImporter: Bool = false
    @Published var showExporter: Bool = false
    @Published var showFXBExporter: Bool = false
    @Published var showDBExporter: Bool = false

    var exportDocument: SyxDocument?
    var exportFilename: String = "BANK.SYX"

    var exportFXBDocument: SyxDocument?
    var exportFXBFilename: String = "VST-AU Alpha JUNO Editor.fxb"

    var exportDBDocument: SyxDocument?
    var exportDBFilename: String = "VST-AU Alpha JUNO Editor.db"

    func filteredTones(search: String) -> [ToneRow]
    {
        let s = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return tones }
        return tones.filter { $0.name.localizedCaseInsensitiveContains(s) }
    }

    func validateToneName()
    {
        do
        {
            _ = try ToneNameCodec.encode(name: editName)
            isToneNameValid = true
        }
        catch
        {
            isToneNameValid = false
            // Don't override a more important error if one is already shown.
            if error == nil
            {
                self.error = "Tone Name contains unsupported characters (allowed: A–Z a–z 0–9 space '-')."
            }
        }

        if isToneNameValid, error?.contains("unsupported characters") == true
        {
            error = nil
        }
    }

    func handleDrop(providers: [NSItemProvider]) -> Bool
    {
        for p in providers
        {
            p.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                DispatchQueue.main.async { [weak self] in
                    self?.importFile(url: url)
                }
            }
        }
        return true
    }

    private func importFile(url: URL)
    {
        let ext = url.pathExtension.lowercased()
        switch ext
        {
        case "syx":
            handleImportURL(url)
        case "fxb":
            handleFXBImportURL(url)
        case "db":
            handleDBImportURL(url)
        default:
            error = "Unsupported drop file type: .\(ext)"
        }
    }

    func handleImportResult(_ result: Result<[URL], Error>)
    {
        do
        {
            let urls = try result.get()
            guard let url = urls.first else { return }
            handleImportURL(url)
        }
        catch
        {
            self.error = String(describing: error)
        }
    }

    private func handleImportURL(_ url: URL)
    {
        do
        {
            let data = try Data(contentsOf: url)
            self.currentBankId = BankIdentifier.id(for: data)
            let bank = try SyxBank.parseBankFileBytes(Array(data))
            self.bank = bank
            self.tones = bank.tones.map { ToneRow(index: $0.index, name: $0.name) }
            self.selectedToneIndex = 0
            self.editName = bank.tones.first?.name ?? ""
            self.error = nil
            validateToneName()
        }
        catch
        {
            self.error = String(describing: error)
        }
    }

    func handleFXBImportResult(_ result: Result<[URL], Error>)
    {
        do
        {
            let urls = try result.get()
            guard let url = urls.first else { return }
            handleFXBImportURL(url)
        }
        catch
        {
            self.error = String(describing: error)
        }
    }

    private func handleFXBImportURL(_ url: URL)
    {
        do
        {
            let data = try Data(contentsOf: url)
            let programs = try BlackAlphaFXB.parsePrograms(fromVC2Bytes: Array(data))
            self.blackAlphaPrograms = programs.map { BlackAlphaProgramRow(index: $0.index, name: $0.name, data: $0.data) }
            self.error = nil
        }
        catch
        {
            self.error = String(describing: error)
        }
    }

    func handleDBImportResult(_ result: Result<[URL], Error>)
    {
        do
        {
            let urls = try result.get()
            guard let url = urls.first else { return }
            handleDBImportURL(url)
        }
        catch
        {
            self.error = String(describing: error)
        }
    }

    private func handleDBImportURL(_ url: URL)
    {
        do
        {
            let programs = try BlackAlphaProgramsDB.load(url: url)
            self.blackAlphaDBFullPrograms = programs
            self.blackAlphaDBPrograms = programs.map {
                BlackAlphaDBProgramRow(
                    id: $0.id,
                    name: $0.name,
                    category: $0.category,
                    author: $0.author,
                    rating: $0.rating,
                    favorite: $0.favorite,
                    notes: $0.notes,
                    programDataLength: $0.programData.count
                )
            }
            self.error = nil
        }
        catch
        {
            self.error = String(describing: error)
        }
    }

    func applyRename()
    {
        guard var bank else { return }
        guard let idx = selectedToneIndex else { return }
        do
        {
            guard let tonePos = bank.tones.firstIndex(where: { $0.index == idx }) else { return }
            var tone = bank.tones[tonePos]
            try tone.setName(editName)
            bank.tones[tonePos] = tone
            self.bank = bank
            self.tones = bank.tones.map { ToneRow(index: $0.index, name: $0.name) }
            self.error = nil
            validateToneName()
        }
        catch
        {
            self.error = String(describing: error)
        }
    }

    func prepareExport()
    {
        guard let bank else { return }
        do
        {
            let bytes = try bank.encodeBankFileBytes()
            exportDocument = SyxDocument(data: Data(bytes))
            showExporter = true
            error = nil
        }
        catch
        {
            self.error = String(describing: error)
        }
    }

    func prepareFXBExport()
    {
        do
        {
            let programs = blackAlphaPrograms.map { BlackAlphaFXB.Program(index: $0.index, name: $0.name, data: $0.data) }
            let bank = BlackAlphaFXBWriter.Bank(bankName: "Bank.0", programs: programs)
            let bytes = try BlackAlphaFXBWriter.buildFXBBytes(from: bank)
            exportFXBDocument = SyxDocument(data: Data(bytes))
            showFXBExporter = true
            error = nil
        }
        catch
        {
            self.error = String(describing: error)
        }
    }

    func prepareDBExport()
    {
        do
        {
            guard !blackAlphaDBFullPrograms.isEmpty else
            {
                self.error = "No DB programs loaded."
                return
            }

            // Create a temp file, then wrap bytes into a FileDocument for export.
            let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("db")
            try BlackAlphaProgramsDB.save(url: tmp, programs: blackAlphaDBFullPrograms)
            let data = try Data(contentsOf: tmp)
            exportDBDocument = SyxDocument(data: data)
            showDBExporter = true
            error = nil
        }
        catch
        {
            self.error = String(describing: error)
        }
    }

    func handleExportResult(_ result: Result<URL, Error>)
    {
        switch result
        {
        case .success:
            break
        case .failure(let err):
            self.error = String(describing: err)
        }
    }

    func handleFXBExportResult(_ result: Result<URL, Error>)
    {
        switch result
        {
        case .success:
            break
        case .failure(let err):
            self.error = String(describing: err)
        }
    }

    func handleDBExportResult(_ result: Result<URL, Error>)
    {
        switch result
        {
        case .success:
            break
        case .failure(let err):
            self.error = String(describing: err)
        }
    }
}

struct SyxDocument: FileDocument
{
    static var readableContentTypes: [UTType] { [UTType(filenameExtension: "syx") ?? .data] }

    var data: Data

    init(data: Data = Data())
    {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws
    {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper
    {
        FileWrapper(regularFileWithContents: data)
    }
}

