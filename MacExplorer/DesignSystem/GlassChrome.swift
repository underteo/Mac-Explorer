import SwiftUI

struct ExplorerEmptyState: View {
    let title: String
    let systemImage: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?
    /// When true, the primary action uses a prominent button (e.g. open System Settings).
    var actionProminent: Bool = false
    var secondaryActionTitle: String?
    var secondaryAction: (() -> Void)?

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(message)
                .multilineTextAlignment(.center)
        } actions: {
            if let actionTitle, let action {
                if actionProminent {
                    Button(actionTitle, action: action)
                        .buttonStyle(.borderedProminent)
                } else {
                    Button(actionTitle, action: action)
                }
            }
            if let secondaryActionTitle, let secondaryAction {
                Button(secondaryActionTitle, action: secondaryAction)
            }
        }
    }
}
