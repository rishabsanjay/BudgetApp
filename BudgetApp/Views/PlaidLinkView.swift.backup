import SwiftUI
import LinkKit

struct PlaidLinkView: UIViewControllerRepresentable {
    let linkToken: String
    let onSuccess: (String) -> Void
    let onExit: () -> Void
    
    func makeUIViewController(context: Context) -> PlaidLinkViewController {
        let controller = PlaidLinkViewController()
        controller.linkToken = linkToken
        controller.onSuccess = onSuccess
        controller.onExit = onExit
        return controller
    }
    
    func updateUIViewController(_ uiViewController: PlaidLinkViewController, context: Context) {}
}

class PlaidLinkViewController: UIViewController {
    var linkToken: String!
    var onSuccess: ((String) -> Void)!
    var onExit: (() -> Void)!
    private var handler: Handler?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        createHandler()
    }
    
    private func createHandler() {
        var linkConfiguration = LinkTokenConfiguration(token: linkToken) { [weak self] success in
            print("public-token: \(success.publicToken) metadata: \(success.metadata)")
            self?.onSuccess(success.publicToken)
        }
        
        linkConfiguration.onExit = { [weak self] exit in
            if let error = exit.error {
                print("exit with error \(error)\n\(exit.metadata)")
            } else {
                print("exit with \(exit.metadata)")
            }
            self?.onExit()
        }
        
        let result = Plaid.create(linkConfiguration)
        switch result {
        case .failure(let error):
            print("Unable to create Plaid handler: \(error)")
        case .success(let handler):
            self.handler = handler
            DispatchQueue.main.async {
                handler.open(presentUsing: .viewController(self))
            }
        }
    }
}
