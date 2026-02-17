import SwiftUI

struct NoteDropDelegate: DropDelegate {
    let destinationItem: ImageNote
    @Binding var notes: [ImageNote]
    @Binding var draggedItem: ImageNote?

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
                notes.move(fromOffsets: IndexSet(integer: fromIndex),
                           toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
            }
        }
    }
}
