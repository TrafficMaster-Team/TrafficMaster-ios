//
//  LoginView.swift
//  TrafficMaster
//
//  Created by Влад on 18.02.26.
//

import PhotosUI
import SwiftUI

struct LoginView: View {
    @StateObject private var profileManager = ProfileManager.shared
    private let apiClient = APIClient.shared
    private let demoCredentials = (email: "demo@trafficmaster.local", password: "DemoPass123", name: "Демо Пользователь", username: "demo_driver")
    
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var username: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var showImagePicker = false
    @State private var avatarData: Data?
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var showErrorAlert = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                MeshGradientBackground()
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 30) {
                        // Header
                        VStack(spacing: 8) {
                            Text("Добро пожаловать!")
                                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                            
                            Text("Создайте свой профиль водителя")
                                .font(.system(.headline, design: .rounded, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 40)
                        
                        // Avatar Picker
                        Button(action: {
                            showImagePicker = true
                        }, label: {
                            ZStack {
                                if let avatarData = avatarData, let uiImage = UIImage(data: avatarData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 120, height: 120)
                                        .clipShape(Circle())
                                } else {
                                    Circle()
                                        .fill(Color(UIColor.secondarySystemFill))
                                        .frame(width: 120, height: 120)
                                    
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
                            )
                            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                        })
                        .sheet(isPresented: $showImagePicker) {
                            ImagePicker(selectedImageData: $avatarData)
                        }
                        
                        // Form Fields
                        VStack(spacing: 16) {
                            CustomTextField(icon: "person.fill", placeholder: "Имя", text: $firstName)
                            CustomTextField(icon: "person.fill", placeholder: "Фамилия", text: $lastName)
                            CustomTextField(icon: "at", placeholder: "Имя пользователя (ник)", text: $username)
                            CustomTextField(
                                icon: "envelope.fill",
                                placeholder: "Email",
                                text: $email,
                                keyboardType: .emailAddress,
                                textInputAutocapitalization: .never,
                                autocorrectionDisabled: true
                            )
                            CustomSecureField(icon: "lock.fill", placeholder: "Пароль (минимум 8 символов)", text: $password)

                            Button("Заполнить демо-данные") {
                                firstName = "Демо"
                                lastName = "Пользователь"
                                username = demoCredentials.username
                                email = demoCredentials.email
                                password = demoCredentials.password
                            }
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 20)
                        
                        Spacer()
                        
                        // Action Button
                        Button(action: {
                            Task {
                                await submitProfile()
                            }
                        }, label: {
                            Text("Начать обучение")
                                .font(.system(.headline, design: .rounded, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                        })
                        .disabled(isSubmitDisabled)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                        .opacity(isSubmitDisabled ? 0.6 : 1.0)
                    }
                }
            }
        }
        .alert("Не удалось создать пользователя", isPresented: $showErrorAlert, actions: {
            Button("OK") {
                errorMessage = nil
            }
        }, message: {
            Text(errorMessage ?? "Неизвестная ошибка")
        })
    }

    private var isSubmitDisabled: Bool {
        isSubmitting || firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        password.count < 8
    }

    @MainActor
    private func submitProfile() async {
        let cleanFirstName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanLastName = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard !cleanFirstName.isEmpty else { return }

        let displayName = [cleanFirstName, cleanLastName].filter { !$0.isEmpty }.joined(separator: " ")
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            _ = try await apiClient.signUp(payload: APISignUpRequest(email: cleanEmail, name: displayName, password: password))
            _ = try await apiClient.logIn(payload: APILoginRequest(email: cleanEmail, password: password))

            profileManager.firstName = cleanFirstName
            profileManager.lastName = cleanLastName
            profileManager.username = cleanUsername
            if let avatarData = avatarData {
                profileManager.avatarData = avatarData
            }
            profileManager.isLoggedIn = true
        } catch {
            if cleanEmail == demoCredentials.email && password == demoCredentials.password {
                profileManager.firstName = "Демо"
                profileManager.lastName = "Пользователь"
                profileManager.username = demoCredentials.username
                profileManager.isLoggedIn = true
                return
            }

            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }
}

// Кастомное текстовое поле
struct CustomTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var textInputAutocapitalization: TextInputAutocapitalization = .sentences
    var autocorrectionDisabled: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 24)
            
            TextField(placeholder, text: $text)
                .font(.system(.body, design: .rounded))
                .keyboardType(keyboardType)
                .textInputAutocapitalization(textInputAutocapitalization)
                .autocorrectionDisabled(autocorrectionDisabled)
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.3), lineWidth: 1)
        )
    }
}

struct CustomSecureField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 24)

            SecureField(placeholder, text: $text)
                .font(.system(.body, design: .rounded))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.3), lineWidth: 1)
        )
    }
}

#Preview {
    LoginView()
}
