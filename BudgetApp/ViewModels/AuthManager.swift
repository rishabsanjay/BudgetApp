import Foundation
import Supabase

@MainActor
class AuthManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var user: User?
    
    private let supabase = SupabaseService.shared.client
    
    init() {
        checkAuthState()
        observeAuthChanges()
    }
    
    func checkAuthState() {
        Task {
            do {
                let session = try await supabase.auth.session
                self.isAuthenticated = session.user != nil
                self.user = session.user
            } catch {
                self.isAuthenticated = false
                self.user = nil
            }
        }
    }
    
    private func observeAuthChanges() {
        Task {
            for await state in supabase.auth.authStateChanges {
                switch state.event {
                case .signedIn:
                    self.isAuthenticated = true
                    self.user = state.session?.user
                case .signedOut:
                    self.isAuthenticated = false
                    self.user = nil
                default:
                    break
                }
            }
        }
    }
    
    func signUp(email: String, password: String) async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let response = try await supabase.auth.signUp(email: email, password: password)
            await MainActor.run {
                // With email confirmation disabled, user should be auto-signed in
                if let session = response.session {
                    isAuthenticated = true
                    self.user = response.user
                    print("Sign up successful and auto-signed in: \(email)")
                } else {
                    // This means email confirmation is still enabled
                    errorMessage = "Please check your email to verify your account"
                }
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
                print("Sign up failed: \(error.localizedDescription)")
            }
        }
    }
    
    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await supabase.auth.signIn(email: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func signOut() async {
        do {
            try await supabase.auth.signOut()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func resetPassword(email: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await supabase.auth.resetPasswordForEmail(email)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}