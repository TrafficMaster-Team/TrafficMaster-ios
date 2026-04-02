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
    
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var username: String = ""
    @State private var showImagePicker = false
    @State private var avatarData: Data?
    
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
                        }
                        .padding(.horizontal, 20)
                        
                        Spacer()
                        
                        // Action Button
                        Button(action: {
                            // Сохраняем профиль
                            profileManager.firstName = firstName
                            profileManager.lastName = lastName
                            profileManager.username = username
                            if let avatarData = avatarData {
                                profileManager.avatarData = avatarData
                            }
                            profileManager.isLoggedIn = true // Пропускаем дальше
                        }, label: {
                            Text("Начать обучение")
                                .font(.system(.headline, design: .rounded, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                        })
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                        .disabled(firstName.isEmpty)
                        .opacity(firstName.isEmpty ? 0.6 : 1.0)
                    }
                }
            }
        }
    }
}

// Кастомное текстовое поле
struct CustomTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 24)
            
            TextField(placeholder, text: $text)
                .font(.system(.body, design: .rounded))
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
