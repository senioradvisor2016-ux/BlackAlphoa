import SwiftUI
import AlphaJunoCore

struct EditorView: View
{
    @ObservedObject var appModel: AppViewModel

    var body: some View
    {
        ScrollView
        {
            VStack(alignment: .leading, spacing: 14)
            {
                ForEach(groupSections()) { section in
                    GroupBox(section.title)
                    {
                        let params = PG300Parameters.all
                            .filter { $0.group == section.group }
                            .sorted { $0.id < $1.id }
                        ParamGrid(params: params, appModel: appModel)
                            .padding(.top, 6)
                    }
                }
            }
            .padding(12)
        }
    }
}

private struct ParamSection: Identifiable
{
    let id = UUID()
    let group: PGParameter.Group
    let title: String
}

private func groupSections() -> [ParamSection]
{
    let order: [PGParameter.Group] = [.dco, .vcf, .hpf, .vca, .lfo, .env, .chorus, .bender]
    return order.map { g in
        ParamSection(group: g, title: g.rawValue)
    }
}

private struct ParamGrid: View
{
    let params: [PGParameter]
    @ObservedObject var appModel: AppViewModel

    private let columns: [GridItem] =
    [
        .init(.adaptive(minimum: 280), spacing: 12)
    ]

    var body: some View
    {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 12)
        {
            ForEach(params, id: \.id) { p in
                ParamControl(parameter: p, value: Binding(get: {
                    Int(appModel.paramValues[p.id] ?? 0)
                }, set: { newV in
                    appModel.setParamValue(UInt8(clamping: newV), for: p.id)
                }))
            }
        }
    }
}

private struct ParamControl: View
{
    let parameter: PGParameter
    @Binding var value: Int

    var body: some View
    {
        VStack(alignment: .leading, spacing: 6)
        {
            HStack
            {
                Text(parameter.name)
                    .font(.subheadline)
                Spacer()
                Text("\(value)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            switch parameter.range
            {
            case let .continuous(min, max):
                Slider(
                    value: Binding(get: { Double(value) }, set: { value = Int($0.rounded()) }),
                    in: Double(min)...Double(max),
                    step: 1
                )

            case let .discrete(min, max, labels):
                if let labels, labels.count == Int(max - min + 1), labels.count <= 4
                {
                    Picker("", selection: $value)
                    {
                        ForEach(0..<labels.count, id: \.self) { i in
                            Text(labels[i]).tag(Int(min) + i)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                else
                {
                    HStack
                    {
                        Stepper("", value: $value, in: Int(min)...Int(max))
                        Spacer()
                        if let labels, labels.count == Int(max - min + 1)
                        {
                            Text(labels[value - Int(min)])
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding(10)
        .background(.thinMaterial)
        .cornerRadius(10)
    }
}

