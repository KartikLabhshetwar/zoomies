import SwiftUI
import ZoomiesCore

struct BehaviorPane: View {
    @ObservedObject private var settings = AppSettings.shared

    // Four columns keep the 22-creature grid compact without tiny cells.
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)

    var body: some View {
        Form {
            // MARK: Animal
            Section {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(AnimalLibrary.all) { animal in
                            AnimalCell(animal: animal,
                                       isSelected: animal.id == settings.animalID) {
                                settings.animalID = animal.id
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(height: 260)               // scrolls through all 22 creatures
            } header: {
                Text("Animal")
            } footer: {
                Text("The critter that lives in your menu bar.")
            }

            // MARK: Color
            let selected = AnimalLibrary.animal(withID: settings.animalID)
            if selected.colors.count > 1 {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(selected.colors) { color in
                                ColorSwatch(animal: selected, color: color,
                                            isSelected: color.id == settings.colorID) {
                                    settings.colorID = color.id
                                }
                            }
                        }
                        .padding(.vertical, 4)
                        .id(selected.id)   // rebuild swatches when the animal changes
                    }
                } header: {
                    Text("Color")
                } footer: {
                    Text("Coat for the \(selected.name.lowercased()).")
                }
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
        icon = FrameLoader.loadThumbnail(animal, colorID: animal.defaultColorID)
    }
}

// MARK: - Color swatch

private struct ColorSwatch: View {
    let animal: Animal
    let color: PetColor
    let isSelected: Bool
    let action: () -> Void

    @State private var icon: NSImage? = nil

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Group {
                    if let icon {
                        Image(nsImage: icon).interpolation(.none).resizable().scaledToFit()
                    } else {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color.secondary.opacity(0.15))
                    }
                }
                .frame(width: 34, height: 34)

                Text(color.displayName)
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            }
            .frame(width: 60)
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.15)
                                     : Color.secondary.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
            )
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .onAppear { if icon == nil { icon = FrameLoader.loadThumbnail(animal, colorID: color.id) } }
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
