import SwiftUI
import UniformTypeIdentifiers
import AlphaJunoCore

struct LibrarianView: View
{
    @ObservedObject var model: LibrarianViewModel

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
                Button("Export .SYX") { model.prepareExport() }
                    .disabled(model.bank == nil)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            Divider()

            HSplitView
            {
                List(selection: $model.selectedToneIndex)
                {
                    ForEach(model.tones, id: \.index) { t in
                        HStack
                        {
                            Text(String(format: "%02d", t.index + 1))
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 34, alignment: .trailing)
                            Text(t.name)
                                .lineLimit(1)
                            Spacer()
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
                    if !model.rekonPrograms.isEmpty
                    {
                        Text("Imported .FXB (names only)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        ScrollView
                        {
                            VStack(alignment: .leading, spacing: 4)
                            {
                                ForEach(model.rekonPrograms, id: \.index) { p in
                                    Text("\(p.index + 1). \(p.name)")
                                        .font(.system(.caption, design: .monospaced))
                                        .lineLimit(1)
                                }
                            }
                        }
                        .frame(maxHeight: 140)
                        Divider()
                    }

                    Text("Tone Name (max 10 chars)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    TextField("Tone name", text: $model.editName)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: model.editName) { _, newValue in
                            if newValue.count > 10 { model.editName = String(newValue.prefix(10)) }
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
                        .disabled(model.selectedToneIndex == nil || model.bank == nil)
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
        .fileExporter(
            isPresented: $model.showExporter,
            document: model.exportDocument,
            contentType: UTType(filenameExtension: "syx") ?? .data,
            defaultFilename: model.exportFilename
        ) { result in
            model.handleExportResult(result)
        }
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

    struct RekonProgramRow
    {
        let index: Int
        let name: String
        let data: String
    }

    @Published var bank: SyxBank?
    @Published var tones: [ToneRow] = []
    @Published var rekonPrograms: [RekonProgramRow] = []

    @Published var selectedToneIndex: Int?
    @Published var editName: String = ""
    @Published var error: String?

    @Published var showImporter: Bool = false
    @Published var showFXBImporter: Bool = false
    @Published var showExporter: Bool = false

    var exportDocument: SyxDocument?
    var exportFilename: String = "BANK.SYX"

    func handleImportResult(_ result: Result<[URL], Error>)
    {
        do
        {
            let urls = try result.get()
            guard let url = urls.first else { return }
            let data = try Data(contentsOf: url)
            let bank = try SyxBank.parseBankFileBytes(Array(data))
            self.bank = bank
            self.tones = bank.tones.map { ToneRow(index: $0.index, name: $0.name) }
            self.selectedToneIndex = 0
            self.editName = bank.tones.first?.name ?? ""
            self.error = nil
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
            let data = try Data(contentsOf: url)
            let programs = try ReKonFXB.parsePrograms(fromVC2Bytes: Array(data))
            self.rekonPrograms = programs.map { RekonProgramRow(index: $0.index, name: $0.name, data: $0.data) }
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

