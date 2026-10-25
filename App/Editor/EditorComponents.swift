import SwiftUI

/// A tappable list row with a checkmark when selected, for multi-select lists in a `Form`.
struct CheckmarkRow: View {
    let title: String
    var systemImage: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                if let systemImage {
                    Label(title, systemImage: systemImage)
                } else {
                    Text(title)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .fontWeight(.semibold)
                        .foregroundStyle(.tint)
                }
            }
            .foregroundStyle(.primary)
            .contentShape(Rectangle())
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// A text field with an Add button, for adding a name a list doesn't offer.
struct AddNameRow: View {
    let placeholder: String
    let onAdd: (String) -> Void

    @State private var text = ""

    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        HStack {
            TextField(placeholder, text: $text)
                .submitLabel(.done)
                .onSubmit(add)
            Button("Add", action: add)
                .buttonStyle(.borderless)
                .disabled(trimmed.isEmpty)
        }
    }

    private func add() {
        guard !trimmed.isEmpty else { return }
        onAdd(trimmed)
        text = ""
    }
}

extension Array where Element == String {
    /// Whether the list has `name`, ignoring case.
    func containsIgnoringCase(_ name: String) -> Bool {
        contains { $0.caseInsensitiveCompare(name) == .orderedSame }
    }

    /// Adds `name` if it's missing, or removes it (ignoring case) if it's there.
    mutating func toggle(_ name: String) {
        if containsIgnoringCase(name) {
            removeAll { $0.caseInsensitiveCompare(name) == .orderedSame }
        } else {
            append(name)
        }
    }

    /// `self` followed by the names in `others` it doesn't already have, ignoring case.
    func merged(with others: [String]) -> [String] {
        self + others.filter { !containsIgnoringCase($0) }
    }
}
