//
//  BehaviorPane.swift
//  Zoomies
//
//  Behavior settings: source, speed, menu-bar text, and launch-at-login.
//

import SwiftUI
import ZoomiesCore

struct BehaviorPane: View {
    @ObservedObject private var settings = AppSettings.shared
    @State private var launchAtLogin = LoginItem.isEnabled

    var body: some View {
        Form {
            Section {
                Picker("Reacts To", selection: $settings.source) {
                    ForEach(LoadSource.allCases, id: \.self) { source in
                        Text(source.displayName).tag(source)
                    }
                }
                .pickerStyle(.segmented)

                Text("What the animal's speed responds to.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Reacts To")
            }

            Section {
                LabeledContent("Speed") {
                    HStack(spacing: 12) {
                        Slider(
                            value: $settings.sensitivity,
                            in: AppSettings.minSensitivity...AppSettings.maxSensitivity
                        )
                        .frame(minWidth: 140)

                        Text(String(format: "%.1f×", settings.sensitivity))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 40, alignment: .trailing)
                    }
                }

                Text("How eagerly the animal speeds up.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Speed")
            }

            Section("Menu Bar") {
                Toggle("Show percentage", isOn: $settings.showPercentage)
                    .toggleStyle(.switch)
            }

            Section {
                Toggle(isOn: $launchAtLogin) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Launch at Login")
                        Text("Unsigned dev builds may need approval in System Settings › General › Login Items.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
                .onChange(of: launchAtLogin) { _, newValue in
                    LoginItem.set(newValue)
                }
            } header: {
                Text("Startup")
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .contentMargins(.top, 8, for: .scrollContent)
    }
}
