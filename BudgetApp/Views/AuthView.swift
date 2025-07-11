import SwiftUI

struct AuthView: View {
    @StateObject private var authManager = AuthManager()
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isSignUp = false
    @State private var showForgotPassword = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Logo and Header
                    VStack(spacing: 16) {
                        // App Logo (you can replace this with your dollar sign logo)
                        Image(systemName: "dollarsign.circle.fill")
                            .font(.system(size: 80, weight: .light))
                            .foregroundColor(.primary)
                        
                        VStack(spacing: 8) {
                            Text("BudgetApp")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.primary)
                            
                            Text(isSignUp ? "Create your account" : "Welcome back")
                                .font(.system(size: 18))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 40)
                    
                    // Auth Form
                    VStack(spacing: 20) {
                        // Email Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                            
                            TextField("Enter your email", text: $email)
                                .font(.system(size: 16))
                                .textInputAutocapitalization(.never)
                                .keyboardType(.emailAddress)
                                .autocorrectionDisabled()
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                        
                        // Password Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                            
                            SecureField("Enter your password", text: $password)
                                .font(.system(size: 16))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                        
                        // Confirm Password (Sign Up only)
                        if isSignUp {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Confirm Password")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.primary)
                                
                                SecureField("Confirm your password", text: $confirmPassword)
                                    .font(.system(size: 16))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                            }
                        }
                        
                        // Error Message
                        if let errorMessage = authManager.errorMessage {
                            Text(errorMessage)
                                .font(.system(size: 14))
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        
                        // Auth Button
                        Button {
                            Task {
                                if isSignUp {
                                    await authManager.signUp(email: email, password: password)
                                } else {
                                    await authManager.signIn(email: email, password: password)
                                }
                            }
                        } label: {
                            if authManager.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Text(isSignUp ? "Create Account" : "Sign In")
                                    .font(.system(size: 16, weight: .medium))
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(canSubmit ? Color.primary : Color.gray)
                        .cornerRadius(12)
                        .disabled(!canSubmit || authManager.isLoading)
                        
                        // Forgot Password (Sign In only)
                        if !isSignUp {
                            Button {
                                showForgotPassword = true
                            } label: {
                                Text("Forgot Password?")
                                    .font(.system(size: 14))
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                    .padding(.horizontal, 32)
                    
                    // Toggle Auth Mode
                    VStack(spacing: 16) {
                        HStack {
                            Rectangle()
                                .fill(Color(.systemGray4))
                                .frame(height: 1)
                            
                            Text("or")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 16)
                            
                            Rectangle()
                                .fill(Color(.systemGray4))
                                .frame(height: 1)
                        }
                        
                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isSignUp.toggle()
                                authManager.errorMessage = nil
                            }
                        } label: {
                            Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                        }
                    }
                    .padding(.horizontal, 32)
                    
                    Spacer(minLength: 40)
                }
            }
            .navigationBarHidden(true)
            .background(Color(.systemBackground))
        }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView(authManager: authManager)
        }
    }
    
    private var canSubmit: Bool {
        let emailValid = !email.trimmingCharacters(in: .whitespaces).isEmpty && email.contains("@")
        let passwordValid = password.count >= 6
        
        if isSignUp {
            return emailValid && passwordValid && password == confirmPassword
        } else {
            return emailValid && passwordValid
        }
    }
}

struct ForgotPasswordView: View {
    @ObservedObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var showSuccess = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Image(systemName: "lock.rotation")
                        .font(.system(size: 60, weight: .light))
                        .foregroundColor(.primary)
                    
                    VStack(spacing: 8) {
                        Text("Reset Password")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text("Enter your email address and we'll send you a link to reset your password")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.top, 40)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Email")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    
                    TextField("Enter your email", text: $email)
                        .font(.system(size: 16))
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
                .padding(.horizontal, 32)
                
                if let errorMessage = authManager.errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                
                if showSuccess {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.green)
                        
                        Text("Password reset email sent!")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.green)
                        
                        Text("Check your email for instructions")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 32)
                }
                
                Button {
                    Task {
                        await authManager.resetPassword(email: email)
                        if authManager.errorMessage == nil {
                            showSuccess = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                dismiss()
                            }
                        }
                    }
                } label: {
                    if authManager.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Text("Send Reset Email")
                            .font(.system(size: 16, weight: .medium))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(canSend ? Color.primary : Color.gray)
                .cornerRadius(12)
                .disabled(!canSend || authManager.isLoading)
                .padding(.horizontal, 32)
                
                Spacer()
            }
            .navigationTitle("Reset Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var canSend: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty && email.contains("@")
    }
}

#Preview {
    AuthView()
}