import SwiftUI
import NoblesKit

/// The spending-specific part of the design editor.
struct StoreSettingsSections: View {
    @Binding var configuration: StoreConfiguration

    @Environment(PreviewData.self) private var previewData
    @FocusState private var isEditingLimit: Bool

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
            .onChange(of: configuration.highlight) { _, highlight in
                // What's left needs a limit to count down from, so go straight to it. Deferred a
                // turn: focus set while the picker's menu is still closing can be dropped.
                if highlight == .remaining, configuration.limit == nil {
                    Task { @MainActor in isEditingLimit = true }
                }
            }
        } header: {
            Text("Highlight")
        } footer: {
            if configuration.highlight == .remaining, configuration.limit == nil {
                Label("Remaining needs a spending limit. Set one below; until then, widgets show the total spent.", systemImage: "exclamationmark.circle")
            } else {
                Text("The figure shown large on small and Lock Screen widgets.")
            }
        }

        Section {
            LimitField(limit: $configuration.limit, isFocused: $isEditingLimit)
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

    /// The stores on the connected account (or the sample's, when none is connected) as
    /// suggestions, then any chosen store that isn't among them.
    private var storeChoices: [String] {
        (previewData.spending.value ?? .sample).stores.merged(with: configuration.stores)
    }
}

/// A currency field for the optional spending limit: clearing it sets no limit. The "$" sits
/// right against the amount (or "None"), and tapping anywhere on the row starts editing.
private struct LimitField: View {
    @Binding var limit: Decimal?
    var isFocused: FocusState<Bool>.Binding
    @State private var text: String

    init(limit: Binding<Decimal?>, isFocused: FocusState<Bool>.Binding) {
        _limit = limit
        self.isFocused = isFocused
        _text = State(initialValue: limit.wrappedValue.map(Self.format) ?? "")
    }

    var body: some View {
        LabeledContent("Limit") {
            HStack(spacing: 2) {
                Text("$")
                    .foregroundStyle(.secondary)
                TextField("None", text: $text)
                    .keyboardType(.decimalPad)
                    .focused(isFocused)
                    .fixedSize()
                    .onChange(of: text) { _, newValue in
                        limit = Self.parse(newValue)
                    }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { isFocused.wrappedValue = true }
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
