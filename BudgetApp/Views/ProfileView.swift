import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Profile Header
                VStack(spacing: 16) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 80, weight: .light))
                        .foregroundColor(.primary)
                    
                    VStack(spacing: 4) {
                        if let user = authManager.user {
                            Text(user.email ?? "No email")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.primary)
                        }
                        
                        Text("BudgetApp User")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 40)
                
                Spacer()
                
                // Sign Out Button
                Button {
                    Task {
                        await authManager.signOut()
                        dismiss()
                    }
                } label: {
                    Text("Sign Out")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.red)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}