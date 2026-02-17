import SwiftUI
#if os(iOS)
import UIKit
#endif

#if os(iOS)
struct MarkdownEditor: View {
    @Binding var text: String
    @State private var selectedRange: NSRange = NSRange(location: 0, length: 0)
    
    var body: some View {
        VStack(spacing: 8) {
            MarkdownTextView(text: $text, selectedRange: $selectedRange)
                .frame(minHeight: 160)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.secondary.opacity(0.12))
                )
        }
    }
    
}

final class MarkdownTextViewImpl: UITextView {
    var onBold: (() -> Void)?
    var onItalic: (() -> Void)?
    
    @objc func tapBoldMenu() { onBold?() }
    @objc func tapItalicMenu() { onItalic?() }
    
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(tapBoldMenu) || action == #selector(tapItalicMenu) {
            return selectedRange.length > 0
        }
        return super.canPerformAction(action, withSender: sender)
    }
}

struct MarkdownTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var selectedRange: NSRange
    
    func makeUIView(context: Context) -> UITextView {
        let tv = MarkdownTextViewImpl()
        tv.font = UIFont.preferredFont(forTextStyle: .body)
        tv.isScrollEnabled = true
        tv.delegate = context.coordinator
        tv.backgroundColor = UIColor.clear
        tv.layer.cornerRadius = 12
        tv.text = text
        let toolbar = UIToolbar()
        toolbar.items = [
            UIBarButtonItem(title: "Жирный", style: .plain, target: context.coordinator, action: #selector(Coordinator.tapBold)),
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(title: "Курсив", style: .plain, target: context.coordinator, action: #selector(Coordinator.tapItalic))
        ]
        toolbar.sizeToFit()
        tv.inputAccessoryView = toolbar
        if let impl = tv as? MarkdownTextViewImpl {
            impl.onBold = { context.coordinator.tapBold() }
            impl.onItalic = { context.coordinator.tapItalic() }
            UIMenuController.shared.menuItems = [
                UIMenuItem(title: "Жирный", action: #selector(MarkdownTextViewImpl.tapBoldMenu)),
                UIMenuItem(title: "Курсив", action: #selector(MarkdownTextViewImpl.tapItalicMenu))
            ]
        }
        return tv
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, selectedRange: $selectedRange)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var text: Binding<String>
        var selectedRange: Binding<NSRange>
        
        init(text: Binding<String>, selectedRange: Binding<NSRange>) {
            self.text = text
            self.selectedRange = selectedRange
        }
        
        func textViewDidChange(_ textView: UITextView) {
            text.wrappedValue = textView.text ?? ""
        }
        
        func textViewDidChangeSelection(_ textView: UITextView) {
            selectedRange.wrappedValue = textView.selectedRange
        }
        
        @objc func tapBold() {
            wrapSelection(start: "**", end: "**")
        }
        
        @objc func tapItalic() {
            wrapSelection(start: "*", end: "*")
        }
        
        private func wrapSelection(start: String, end: String) {
            let current = text.wrappedValue as NSString
            var sel = selectedRange.wrappedValue
            if sel.location > current.length { sel.location = current.length; sel.length = 0 }
            let selected = current.substring(with: NSRange(location: sel.location, length: min(sel.length, current.length - sel.location)))
            let replaced = "\(start)\(selected)\(end)"
            let newText = current.replacingCharacters(in: NSRange(location: sel.location, length: min(sel.length, current.length - sel.location)), with: replaced)
            text.wrappedValue = newText
            selectedRange.wrappedValue = NSRange(location: sel.location + replaced.count, length: 0)
        }
    }
}
#endif
