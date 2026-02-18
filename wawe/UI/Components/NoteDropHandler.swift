import SwiftUI

struct NoteDropHandler: DropDelegate {
    let destinationItem: ImageNote
    let notes: [ImageNote]
    @Binding var draggedItem: ImageNote?
    let onMove: (IndexSet, Int) -> Void

    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedItem = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let draggedItem,
              let fromIndex = notes.firstIndex(of: draggedItem),
              let toIndex = notes.firstIndex(of: destinationItem) else { return }

        if fromIndex != toIndex {
            withAnimation {
                onMove(IndexSet(integer: fromIndex),
                       toIndex > fromIndex ? toIndex + 1 : toIndex)
            }
        }
    }
}
