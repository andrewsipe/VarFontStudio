import AppKit

/// Detects when the key window is editing text so menu Undo/Redo and global
/// key monitors can defer to the field editor instead of document history.
enum StudioTextEditingFocus {
    static var isActive: Bool {
        guard let responder = NSApp.keyWindow?.firstResponder else { return false }
        return isTextInput(responder)
    }

    /// Undo manager for the active field editor / text view, if any.
    static var undoManager: UndoManager? {
        guard let window = NSApp.keyWindow,
              let responder = window.firstResponder,
              isTextInput(responder) else {
            return nil
        }
        if let textView = responder as? NSTextView {
            return textView.undoManager
        }
        if let view = responder as? NSView {
            return view.enclosingTextView?.undoManager
                ?? view.undoManager
                ?? window.undoManager
        }
        return responder.undoManager ?? window.undoManager
    }

    static func isTextInput(_ responder: NSResponder) -> Bool {
        if responder is NSTextView || responder is NSTextField {
            return true
        }
        if let view = responder as? NSView {
            return view.enclosingTextView != nil || view.ancestorTextField != nil
        }
        return false
    }
}

extension NSView {
    var enclosingTextView: NSTextView? {
        var current: NSView? = self
        while let view = current {
            if let textView = view as? NSTextView { return textView }
            current = view.superview
        }
        return nil
    }

    var ancestorTextField: NSTextField? {
        var current: NSView? = self
        while let view = current {
            if let field = view as? NSTextField { return field }
            current = view.superview
        }
        return nil
    }
}
