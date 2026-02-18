import SwiftUI
import Combine

final class VerbsTestViewModel: ObservableObject {
    @Published var currentVerb: IrregularVerb?
    @Published var currentStep = 1 // 1: infinitive, 2: past simple, 3: past participle
    @Published var answer = ""
    @Published var feedback: String?
    @Published var isCorrect = false
    
    var totalSteps: Int { 3 }
    
    private let repo: IrregularVerbsRepository
    private var allVerbs: [IrregularVerb] = []
    private var cancellables = Set<AnyCancellable>()
    
    init(repo: IrregularVerbsRepository) {
        self.repo = repo
        bind()
    }
    
    private func bind() {
        repo.verbsPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] verbs in
                self?.allVerbs = verbs
                if self?.currentVerb == nil {
                    self?.startNewVerb()
                }
            }
            .store(in: &cancellables)
    }
    
    var currentPrompt: String {
        guard let verb = currentVerb else { return "" }
        switch currentStep {
        case 1: return "Введите инфинитив для: \(verb.translation)"
        case 2: return "Введите Past Simple для: \(verb.infinitive)"
        case 3: return "Введите Past Participle для: \(verb.infinitive)"
        default: return ""
        }
    }
    
    var correctAnswer: String {
        guard let verb = currentVerb else { return "" }
        switch currentStep {
        case 1: return verb.infinitive
        case 2: return verb.pastSimple
        case 3: return verb.pastParticiple
        default: return ""
        }
    }
    
    func checkAnswer() {
        let userAnswer = answer.normalizedCompareKey
        let correct = correctAnswer.normalizedCompareKey
        
        if userAnswer == correct {
            isCorrect = true
            feedback = nil
            if currentStep < totalSteps {
                currentStep += 1
                answer = ""
                isCorrect = false
            } else {
                // Completed all steps for this verb
                if let verb = currentVerb {
                    repo.markCorrect(verb)
                }
                // Transition to next verb
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.startNewVerb()
                }
            }
        } else {
            isCorrect = false
            feedback = "Правильно: \(correctAnswer)"
        }
    }
    
    func skipStep() {
        isCorrect = false
        feedback = "Правильно: \(correctAnswer)"
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.startNewVerb()
        }
    }
    
    func startNewVerb() {
        guard !allVerbs.isEmpty else {
            currentVerb = nil
            return
        }
        currentVerb = allVerbs.randomElement()
        currentStep = 1
        answer = ""
        feedback = nil
        isCorrect = false
    }
}
