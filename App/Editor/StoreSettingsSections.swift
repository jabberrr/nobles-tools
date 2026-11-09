import SwiftUI
import NoblesKit

/// The spending-specific part of the design editor.
struct StoreSettingsSections: View {
    @Binding var configuration: StoreConfiguration

    var body: some View {
        Section {
            CheckmarkRow(title: "All Stores", systemImage: "bag", isSelected: configuration.stores.isEmpty) {
                configuration.stores = []
            }
            ForEach(storeChoices, id: \.self) { store in
                CheckmarkRow(title: store, isSelected: configuration.stores.containsIgnoringCase(store)) {
                    configuration.stores.toggle(store)
                }
            }
            AddNameRow(placeholder: "Add a store by name") { store in
                if !configuration.stores.containsIgnoringCase(store) {
                    configuration.stores.append(store)
                }
            }
        } header: {
            Text("Stores")
        } footer: {
            Text("Choose which stores to include, or All for every store.")
        }

        Section {
            Picker("Highlight", selection: $configuration.highlight) {
                ForEach(StoreHighlight.allCases) { highlight in
                    Text(highlight.displayName).tag(highlight)
                }
            }
        } header: {
            Text("Highlight")
        } footer: {
            Text("The figure shown large on small and Lock Screen widgets.")
        }

        Section {
            LimitField(limit: $configuration.limit)
        } header: {
            Text("Spending Limit")
        } footer: {
            Text("Shown as a progress bar. Entered here because the charges page doesn't include your limit.")
        }

        Section {
            Toggle("Show Recent Charges", isOn: $configuration.showsRecentCharges)
        } footer: {
            Text("Lists your latest purchases where there's room, on the medium and large sizes.")
        }
    }

    /// The common store names as suggestions, then any chosen store that isn't among them.
    private var storeChoices: [String] {
        StoreStatement.sample.stores.merged(with: configuration.stores)
    }
}

/// A currency field for the optional spending limit: clearing it sets no limit.
private struct LimitField: View {
    @Binding var limit: Decimal?
    @State private var text: String

    init(limit: Binding<Decimal?>) {
        _limit = limit
        _text = State(initialValue: limit.wrappedValue.map(Self.format) ?? "")
    }

    var body: some View {
        HStack {
            Text("Limit")
            Spacer()
            Text("$")
                .foregroundStyle(.secondary)
            TextField("None", text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 90)
                .onChange(of: text) { _, newValue in
                    limit = Self.parse(newValue)
                }
        }
    }

    /// A positive amount from loosely typed input, or `nil` for empty or non-positive input.
    private static func parse(_ string: String) -> Decimal? {
        let normalized = string
            .filter { $0.isNumber || $0 == "." || $0 == "," }
            .replacingOccurrences(of: ",", with: ".")
        guard let value = Decimal(string: normalized), value > 0 else { return nil }
        return value
    }

    private static func format(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).stringValue
    }
}
