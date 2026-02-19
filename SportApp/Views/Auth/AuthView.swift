import SwiftUI

struct AuthView: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    @State private var isRegisterMode = false
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var city = ""
    @State private var favoritePosition = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text("Mini Football Tournaments")
                        .font(.title.bold())
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)

                    Text(isRegisterMode ? "Create your account" : "Sign in to manage bookings")
                        .foregroundStyle(.white.opacity(0.8))

                    VStack(spacing: 12) {
                        if isRegisterMode {
                            TextField("Full name", text: $name)
                                .textContentType(.name)
                                .textFieldStyle(.roundedBorder)

                            TextField("City", text: $city)
                                .textFieldStyle(.roundedBorder)

                            TextField("Favorite position", text: $favoritePosition)
                                .textFieldStyle(.roundedBorder)
                        }

                        TextField("Email", text: $email)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textFieldStyle(.roundedBorder)

                        SecureField("Password", text: $password)
                            .textFieldStyle(.roundedBorder)
                    }

                    if let error = appViewModel.authErrorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(AppTheme.accent)
                    }

                    Button(action: submit) {
                        Text(isRegisterMode ? "Register" : "Sign In")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)

                    Button(isRegisterMode ? "Already have an account? Sign In" : "Need an account? Register") {
                        appViewModel.authErrorMessage = nil
                        isRegisterMode.toggle()
                    }
                    .font(.footnote)
                }
                .padding()
            }
            .appScreenBackground()
            .navigationTitle("Welcome")
        }
    }

    private func submit() {
        if isRegisterMode {
            appViewModel.register(
                name: name,
                email: email,
                city: city,
                favoritePosition: favoritePosition,
                password: password
            )
        } else {
            appViewModel.signIn(email: email, password: password)
        }
    }
}
