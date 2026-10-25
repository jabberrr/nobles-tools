import SwiftUI
import NoblesKit

/// The countdown-specific part of the design editor.
struct CountdownSettingsSection: View {
    @Binding var configuration: CountdownConfiguration

    var body: some View {
        Section {
            Picker("Count Down To", selection: $configuration.target) {
                ForEach(Term.Kind.allCases) { kind in
                    Text("End of \(kind.displayName)").tag(kind)
                }
            }
            Picker("Count", selection: $configuration.counting) {
                ForEach(DayCounting.allCases) { counting in
                    Text(counting.displayName).tag(counting)
                }
            }
            Picker("Style", selection: $configuration.style) {
                ForEach(CountdownStyle.allCases) { style in
                    Text(style.displayName).tag(style)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Text("Countdown")
        } footer: {
            Text("School days skip weekends and breaks. Dates come from the school calendar in Settings.")
        }
    }
}
