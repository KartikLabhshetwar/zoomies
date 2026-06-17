//
//  AnimalsPane.swift
//  Zoomies
//
//  Gallery of all AnimalLibrary animals in a 3-column LazyVGrid.
//  Tapping a cell sets AppSettings.shared.selectedAnimalID.
//

import AppKit
import SwiftUI
import ZoomiesCore

struct AnimalsPane: View {
    @ObservedObject private var settings = AppSettings.shared

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        Form {
            Section("Choose Your Animal") {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(AnimalLibrary.all) { animal in
                        AnimalCell(
                            animal: animal,
                            isSelected: settings.selectedAnimalID == animal.id
                        )
                        .onTapGesture {
                            settings.selectedAnimalID = animal.id
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .contentMargins(.top, 8, for: .scrollContent)
    }
}

// MARK: - Animal Cell

private struct AnimalCell: View {
    let animal: Animal
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 6) {
            spriteImage
                .frame(width: 52, height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
                )

            Text(animal.name)
                .font(.caption)
                .foregroundStyle(isSelected ? Color.accentColor : .primary)
                .fontWeight(isSelected ? .semibold : .regular)
                .lineLimit(1)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(
                            isSelected ? Color.accentColor : Color.clear,
                            lineWidth: 2
                        )
                )
        )
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var spriteImage: some View {
        if let nsImage = NSImage(named: animal.frameName(0)) {
            let templateImage: NSImage = {
                let copy = nsImage.copy() as! NSImage
                copy.isTemplate = true
                return copy
            }()
            Image(nsImage: templateImage)
                .renderingMode(.template)
                .interpolation(.none)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(isSelected ? Color.accentColor : .primary)
        } else {
            Image(systemName: "pawprint")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
        }
    }
}
