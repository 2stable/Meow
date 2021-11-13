import AppKit

class DismisableController: NSViewController {
    final override func cancelOperation(_ sender: Any?) {
        Coordinator.shared.dismiss()
    }
}
