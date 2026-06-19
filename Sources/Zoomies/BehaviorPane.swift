import SwiftUI
import ZoomiesCore

struct BehaviorPane: View {
    @ObservedObject private var settings = AppSettings.shared

    // Three columns give the six animals a balanced 2×3 grid (four left a lopsided 4+2).
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    var body: some View {
        Form {
            // MARK: Animal
            Section {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(AnimalLibrary.all) { animal in
                        AnimalCell(animal: animal,
                                   isSelected: animal.id == settings.animalID) {
                            settings.animalID = animal.id
                        }
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Animal")
            } footer: {
                Text("The critter that lives in your menu bar.")
            }

            // MARK: Reacts To
            Section {
                Picker("", selection: $settings.source) {
                    ForEach(LoadSource.allCases, id: \.self) { s in
                        Text(s.displayName).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            } header: {
                Text("Reacts To")
            } footer: {
                Text("Which system metric sets the pet's pace. “Busiest” follows whichever of CPU, GPU, or memory is highest.")
            }

            // MARK: Speed
            Section {
                HStack(spacing: 12) {
                    Slider(value: $settings.speed,
                           in: AppSettings.minSpeed...AppSettings.maxSpeed)
                    Text(String(format: "%.1f×", settings.speed))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 38, alignment: .trailing)
                }
            } header: {
                Text("Speed")
            } footer: {
                Text("Scales the whole curve — from a slow trot to an all-out sprint.")
            }

            // MARK: Menu Bar
            Section("Menu Bar") {
                Toggle("Show percentage", isOn: $settings.showPercentage)
            }

            // MARK: Startup
            Section("Startup") {
                LoginItemToggle()
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .contentMargins(.top, 8, for: .scrollContent)
    }
}

// MARK: - Animal cell

private struct AnimalCell: View {
    let animal: Animal
    let isSelected: Bool
    let action: () -> Void

    @State private var icon: NSImage? = nil

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Group {
                    if let icon {
                        Image(nsImage: icon)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                    } else {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color.secondary.opacity(0.15))
                    }
                }
                .frame(width: 40, height: 40)

                Text(animal.name)
                    .font(.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(isSelected ? Color.accentColor : .primary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 86)                     // uniform cell height across the grid
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.15)
                                     : Color.secondary.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
            )
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .onAppear(perform: loadIcon)
    }

    private func loadIcon() {
        guard icon == nil else { return }
        icon = FrameLoader.loadIdlePreview(animal)
    }
}

// MARK: - Login item toggle

private struct LoginItemToggle: View {
    @State private var enabled = LoginItem.isEnabled

    var body: some View {
        Toggle("Launch at Login", isOn: $enabled)
            .onChange(of: enabled) { _, v in LoginItem.set(v) }
    }
}
