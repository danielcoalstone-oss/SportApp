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
                    Text("Турниры по мини-футболу")
                        .font(.title.bold())
                        .multilineTextAlignment(.center)

                    Text(isRegisterMode ? "Создайте аккаунт" : "Войдите, чтобы управлять бронированиями")
                        .foregroundStyle(.secondary)

                    VStack(spacing: 12) {
                        if isRegisterMode {
                            TextField("Полное имя", text: $name)
                                .textContentType(.name)
                                .textFieldStyle(.roundedBorder)

                            TextField("Город", text: $city)
                                .textFieldStyle(.roundedBorder)

                            TextField("Основная позиция", text: $favoritePosition)
                                .textFieldStyle(.roundedBorder)
                        }

                        TextField("Эл. почта", text: $email)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textFieldStyle(.roundedBorder)

                        SecureField("Пароль", text: $password)
                            .textFieldStyle(.roundedBorder)
                    }

                    if let error = appViewModel.authErrorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    Button(action: submit) {
                        Text(isRegisterMode ? "Регистрация" : "Войти")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)

                    Button(isRegisterMode ? "Уже есть аккаунт? Войти" : "Нет аккаунта? Зарегистрироваться") {
                        appViewModel.authErrorMessage = nil
                        isRegisterMode.toggle()
                    }
                    .font(.footnote)
                }
                .padding()
            }
            .navigationTitle("Добро пожаловать")
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
