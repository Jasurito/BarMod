import AppKit
import BarModCore
import Observation
import SwiftUI

@MainActor
@Observable
final class TrayModel {
    var isTrusted = false
    var isLoading = false
    var hiddenItems: [TrayItem] = []

    /// Item count the panel must fit, counting the single message row.
    var layoutCount: Int { isTrusted ? hiddenItems.count : TrayGrid.maxColumns }
}

struct TrayView: View {
    let model: TrayModel
    let onPress: (TrayItem) -> Void
    let onOpenAccessibilitySettings: () -> Void

    @State private var hoveredName: String?

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 12, style: .continuous) }

    var body: some View {
        let size = TrayGrid.size(for: model.layoutCount)
        VStack(alignment: .leading, spacing: 0) {
            if model.isTrusted {
                grid
                footer
            } else {
                accessibilityPrompt
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
        Text(hoveredName ?? summary)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(.horizontal, 6)
    }

    private var summary: String {
        if model.isLoading && model.hiddenItems.isEmpty { return "Looking for hidden icons…" }
        switch model.hiddenItems.count {
        case 0: return "No hidden icons"
        case 1: return "1 hidden icon"
        case let count: return "\(count) hidden icons"
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

private struct TrayIconButton: View {
    let item: TrayItem
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            icon
                .frame(width: TrayGrid.cell.width - 4, height: TrayGrid.cell.height - 4)
                .background(isHovered ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear), in: RoundedRectangle(cornerRadius: 7))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(width: TrayGrid.cell.width, height: TrayGrid.cell.height)
        .onHover { isHovered = $0 }
        .accessibilityLabel(item.displayName)
    }

    @ViewBuilder
    private var icon: some View {
        if let symbol = item.systemSymbol {
            Image(systemName: symbol).font(.system(size: 15)).foregroundStyle(.primary)
        } else if let appIcon = NSRunningApplication(processIdentifier: item.pid)?.icon {
            Image(nsImage: appIcon).resizable().scaledToFit().padding(5)
        } else {
            Image(systemName: "questionmark.square.dashed").foregroundStyle(.secondary)
        }
    }
}
