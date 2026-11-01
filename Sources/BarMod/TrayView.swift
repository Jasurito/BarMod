import AppKit
import BarModCore
import Observation
import SwiftUI

@MainActor
@Observable
final class TrayModel {
    let settings: AppSettings
    var isTrusted = false
    var isLoading = false
    var hiddenItems: [TrayItem] = []

    init(settings: AppSettings) {
        self.settings = settings
    }

    var panelSize: CGSize {
        guard isTrusted else { return TrayGrid.size(for: TrayGrid.maxColumns) }
        switch settings.style {
        case .grid: return TrayGrid.size(for: hiddenItems.count)
        case .list: return TrayList.size(for: hiddenItems.count)
        }
    }

    var summary: String {
        if isLoading && hiddenItems.isEmpty { return "Looking for hidden icons…" }
        switch hiddenItems.count {
        case 0: return "No hidden icons"
        case 1: return "1 hidden icon"
        case let count: return "\(count) hidden icons"
        }
    }
}

struct TrayView: View {
    let model: TrayModel
    let onPress: (TrayItem) -> Void
    let onOpenAccessibilitySettings: () -> Void

    @State private var hoveredName: String?

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 12, style: .continuous) }

    var body: some View {
        let size = model.panelSize
        VStack(alignment: .leading, spacing: 0) {
            if !model.isTrusted {
                accessibilityPrompt
            } else if model.settings.style == .list {
                list
            } else {
                grid
                footer
            }
        }
        .padding(TrayGrid.padding)
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .background(.regularMaterial, in: shape)
        .overlay(shape.strokeBorder(.separator))
    }

    private var grid: some View {
        let columns = Array(
            repeating: GridItem(.fixed(TrayGrid.cell.width), spacing: 0),
            count: TrayGrid.columns(for: model.hiddenItems.count)
        )
        return LazyVGrid(columns: columns, alignment: .leading, spacing: 0) {
            ForEach(model.hiddenItems) { item in
                TrayIconButton(item: item) { onPress(item) }
                    .onHover { inside in
                        if inside {
                            hoveredName = item.displayName
                        } else if hoveredName == item.displayName {
                            hoveredName = nil
                        }
                    }
            }
        }
    }

    private var footer: some View {
        Text(hoveredName ?? model.summary)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(.horizontal, 6)
    }

    @ViewBuilder
    private var list: some View {
        if model.hiddenItems.isEmpty {
            Text(model.summary)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(model.hiddenItems) { item in
                        TrayRowButton(item: item, showsLogo: model.settings.showsLogos) { onPress(item) }
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private var accessibilityPrompt: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("BarMod needs Accessibility access to find hidden icons.")
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
            Button("Open Settings", action: onOpenAccessibilitySettings)
                .controlSize(.small)
        }
        .padding(6)
    }
}

private struct TrayIcon: View {
    let item: TrayItem
    let symbolSize: CGFloat

    var body: some View {
        if let symbol = item.systemSymbol {
            Image(systemName: symbol).font(.system(size: symbolSize)).foregroundStyle(.primary)
        } else if let appIcon = NSRunningApplication(processIdentifier: item.pid)?.icon {
            Image(nsImage: appIcon).resizable().scaledToFit()
        } else {
            Image(systemName: "questionmark.square.dashed").foregroundStyle(.secondary)
        }
    }
}

private struct TrayIconButton: View {
    let item: TrayItem
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            TrayIcon(item: item, symbolSize: 15)
                .padding(5)
                .frame(width: TrayGrid.cell.width - 4, height: TrayGrid.cell.height - 4)
                .background(isHovered ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear), in: RoundedRectangle(cornerRadius: 7))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(width: TrayGrid.cell.width, height: TrayGrid.cell.height)
        .onHover { isHovered = $0 }
        .accessibilityLabel(item.displayName)
    }
}

private struct TrayRowButton: View {
    let item: TrayItem
    let showsLogo: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if showsLogo {
                    TrayIcon(item: item, symbolSize: 13).frame(width: 20, height: 20)
                }
                Text(item.displayName)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .frame(height: TrayList.rowHeight)
            .background(isHovered ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear), in: RoundedRectangle(cornerRadius: 7))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityLabel(item.displayName)
    }
}
