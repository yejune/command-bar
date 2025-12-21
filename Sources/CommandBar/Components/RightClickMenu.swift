import SwiftUI
import AppKit

struct RightClickMenu: NSViewRepresentable {
    let onSelect: () -> Void
    let onRun: () -> Void
    let onToggleFavorite: () -> Void
    let cmd: Command
    let onEdit: () -> Void
    let onCopy: () -> Void
    let onDelete: () -> Void
    let groups: [Group]
    let currentGroupId: UUID?
    let onMoveToGroup: (UUID) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = RightClickMenuView()
        view.onSelect = onSelect
        view.onRun = onRun
        view.onToggleFavorite = onToggleFavorite
        view.cmd = cmd
        view.onEdit = onEdit
        view.onCopy = onCopy
        view.onDelete = onDelete
        view.groups = groups
        view.currentGroupId = currentGroupId
        view.onMoveToGroup = onMoveToGroup
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let view = nsView as? RightClickMenuView else { return }
        view.onSelect = onSelect
        view.onRun = onRun
        view.onToggleFavorite = onToggleFavorite
        view.cmd = cmd
        view.onEdit = onEdit
        view.onCopy = onCopy
        view.onDelete = onDelete
        view.groups = groups
        view.currentGroupId = currentGroupId
        view.onMoveToGroup = onMoveToGroup
    }

    class RightClickMenuView: NSView {
        var onSelect: (() -> Void)?
        var onRun: (() -> Void)?
        var onToggleFavorite: (() -> Void)?
        var cmd: Command?
        var onEdit: (() -> Void)?
        var onCopy: (() -> Void)?
        var onDelete: (() -> Void)?
        var groups: [Group] = []
        var currentGroupId: UUID?
        var onMoveToGroup: ((UUID) -> Void)?

        override func rightMouseDown(with event: NSEvent) {
            showMenu(with: event)
        }

        override func mouseDown(with event: NSEvent) {
            if event.modifierFlags.contains(.control) {
                showMenu(with: event)
            }
            // 왼쪽 클릭은 SwiftUI로 전달
        }

        override func hitTest(_ point: NSPoint) -> NSView? {
            // 우클릭만 이 뷰에서 처리
            if NSEvent.pressedMouseButtons & 0x2 != 0 {
                return super.hitTest(point)
            }
            // Control 키가 눌린 상태면 처리
            if NSEvent.modifierFlags.contains(.control) && NSEvent.pressedMouseButtons & 0x1 != 0 {
                return super.hitTest(point)
            }
            return nil
        }

        func showMenu(with event: NSEvent) {
            onSelect?()

            let menu = NSMenu()

            let runItem = NSMenuItem(title: L.contextMenuRun, action: #selector(runAction), keyEquivalent: "")
            runItem.target = self
            menu.addItem(runItem)

            let favoriteTitle = cmd?.isFavorite == true ? L.favoriteRemove : L.favoriteAdd
            let favoriteIcon = cmd?.isFavorite == true ? "star.slash" : "star"
            let favoriteItem = NSMenuItem(title: favoriteTitle, action: #selector(toggleFavoriteAction), keyEquivalent: "")
            favoriteItem.target = self
            if let iconImage = NSImage(systemSymbolName: favoriteIcon, accessibilityDescription: nil) {
                favoriteItem.image = iconImage
            }
            menu.addItem(favoriteItem)

            let editItem = NSMenuItem(title: L.contextMenuEdit, action: #selector(editAction), keyEquivalent: "")
            editItem.target = self
            menu.addItem(editItem)

            let copyItem = NSMenuItem(title: L.contextMenuCopy, action: #selector(copyAction), keyEquivalent: "")
            copyItem.target = self
            menu.addItem(copyItem)

            menu.addItem(NSMenuItem.separator())

            // Move to Group submenu
            let moveToGroupItem = NSMenuItem(title: L.moveToGroup, action: nil, keyEquivalent: "")
            let submenu = NSMenu()

            for group in groups {
                let groupItem = NSMenuItem(title: group.name, action: #selector(moveToGroupAction(_:)), keyEquivalent: "")
                groupItem.target = self
                groupItem.representedObject = group.id

                // Add color indicator as attributed string
                let attributedTitle = NSMutableAttributedString()
                let colorCircle = NSTextAttachment()
                let circleImage = NSImage(size: NSSize(width: 8, height: 8), flipped: false) { [self] rect in
                    self.colorFor(group.color).setFill()
                    let circlePath = NSBezierPath(ovalIn: rect)
                    circlePath.fill()
                    return true
                }
                colorCircle.image = circleImage
                attributedTitle.append(NSAttributedString(attachment: colorCircle))
                attributedTitle.append(NSAttributedString(string: "  " + group.name))
                groupItem.attributedTitle = attributedTitle

                // Disable if already in this group
                if currentGroupId == group.id {
                    groupItem.isEnabled = false
                }

                submenu.addItem(groupItem)
            }

            moveToGroupItem.submenu = submenu
            menu.addItem(moveToGroupItem)

            menu.addItem(NSMenuItem.separator())

            let deleteItem = NSMenuItem(title: L.buttonDelete, action: #selector(deleteAction), keyEquivalent: "")
            deleteItem.target = self
            menu.addItem(deleteItem)

            NSMenu.popUpContextMenu(menu, with: event, for: self)
        }

        func colorFor(_ name: String) -> NSColor {
            switch name {
            case "blue": return .systemBlue
            case "red": return .systemRed
            case "green": return .systemGreen
            case "orange": return .systemOrange
            case "purple": return .systemPurple
            case "gray": return .systemGray
            default: return .systemGray
            }
        }

        @objc func runAction() { onRun?() }
        @objc func toggleFavoriteAction() { onToggleFavorite?() }
        @objc func editAction() { onEdit?() }
        @objc func copyAction() { onCopy?() }
        @objc func deleteAction() { onDelete?() }
        @objc func moveToGroupAction(_ sender: NSMenuItem) {
            if let groupId = sender.representedObject as? UUID {
                onMoveToGroup?(groupId)
            }
        }
    }
}
