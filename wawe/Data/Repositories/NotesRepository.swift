import Foundation
import Combine
import SwiftUI

protocol NotesRepository {
    // MARK: - Image Notes
    var imageNotesPublisher: AnyPublisher<[ImageNote], Never> { get }
    func addImageNote(title: String, imageURL: String, descriptionMarkdown: String)
    func updateImageNote(_ note: ImageNote, title: String?, imageURL: String?, descriptionMarkdown: String?)
    func removeImageNote(_ note: ImageNote)
    func moveImageNotes(from source: IndexSet, to destination: Int)
    func clearImageNotes()

    // MARK: - Flex Tables
    var notesPublisher: AnyPublisher<[FlexNoteTable], Never> { get }
    func addTable(title: String, headers: [String], footer: [String])
    func updateCell(table: FlexNoteTable, row: Int, column: Int, value: String)
    func addRow(table: FlexNoteTable)
    func addColumn(table: FlexNoteTable, header: String)
    func removeColumn(table: FlexNoteTable, at index: Int)
    func updateHeader(table: FlexNoteTable, at index: Int, value: String)
    func updateFooter(table: FlexNoteTable, footer: [String])
    func removeTable(_ table: FlexNoteTable)
}

final class NotesRepositoryStoreAdapter: NotesRepository {
    private let store: WordStore
    private var cancellables = Set<AnyCancellable>()
    private let tablesSubject = CurrentValueSubject<[FlexNoteTable], Never>([])
    private let imageNotesSubject = CurrentValueSubject<[ImageNote], Never>([])
    
    init(store: WordStore) {
        self.store = store
        
        store.$notesTables
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.tablesSubject.send($0) }
            .store(in: &cancellables)
            
        store.$imageNotes
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.imageNotesSubject.send($0) }
            .store(in: &cancellables)
    }
    
    // MARK: - Image Notes Implementation
    var imageNotesPublisher: AnyPublisher<[ImageNote], Never> { imageNotesSubject.eraseToAnyPublisher() }
    
    func addImageNote(title: String, imageURL: String, descriptionMarkdown: String) {
        store.addImageNote(title: title, imageURL: imageURL, descriptionMarkdown: descriptionMarkdown)
    }
    
    func updateImageNote(_ note: ImageNote, title: String?, imageURL: String?, descriptionMarkdown: String?) {
        store.updateImageNote(note, title: title, imageURL: imageURL, descriptionMarkdown: descriptionMarkdown)
    }
    
    func removeImageNote(_ note: ImageNote) {
        store.removeImageNote(note)
    }
    
    func moveImageNotes(from source: IndexSet, to destination: Int) {
        store.imageNotes.move(fromOffsets: source, toOffset: destination)
    }
    
    func clearImageNotes() {
        store.clearImageNotes()
    }
    
    // MARK: - Flex Tables Implementation
    var notesPublisher: AnyPublisher<[FlexNoteTable], Never> { tablesSubject.eraseToAnyPublisher() }
    
    func addTable(title: String, headers: [String], footer: [String]) { store.addNoteTable(title: title, headers: headers, footer: footer) }
    func updateCell(table: FlexNoteTable, row: Int, column: Int, value: String) { store.updateNoteCell(in: table, row: row, column: column, value: value) }
    func addRow(table: FlexNoteTable) { store.addNoteRow(to: table) }
    func addColumn(table: FlexNoteTable, header: String) { store.addNoteColumn(to: table, header: header) }
    func removeColumn(table: FlexNoteTable, at index: Int) { store.removeNoteColumn(from: table, at: index) }
    func updateHeader(table: FlexNoteTable, at index: Int, value: String) { store.updateNoteHeader(in: table, at: index, value: value) }
    func updateFooter(table: FlexNoteTable, footer: [String]) { store.updateNoteFooter(for: table, footer: footer) }
    func removeTable(_ table: FlexNoteTable) { store.removeNoteTable(table) }
}
