//
//  EditProfileView.swift
//  TrafficMaster
//
//  Created by Влад on 18.02.26.
//

import SwiftUI
import PhotosUI

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var profileManager = ProfileManager.shared
    
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var username: String = ""
    @State private var showImagePicker = false
    @State private var avatarData: Data? = nil
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Spacer()
                        Button(action: { showImagePicker = true }) {
                            ZStack {
                                if let avatarData = avatarData, let uiImage = UIImage(data: avatarData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 100, height: 100)
                                        .clipShape(Circle())
                                } else {
                                    Circle()
                                        .fill(Color(UIColor.secondarySystemFill))
                                        .frame(width: 100, height: 100)
                                    
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 30))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .overlay(
                                Circle()
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .sheet(isPresented: $showImagePicker) {
                            ImagePicker(selectedImageData: $avatarData)
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
                
                Section(header: Text("Личные данные")) {
                    TextField("Имя", text: $firstName)
                    TextField("Фамилия", text: $lastName)
                    TextField("Имя пользователя (ник)", text: $username)
                        .autocapitalization(.none)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Редактирование")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        profileManager.firstName = firstName
                        profileManager.lastName = lastName
                        profileManager.username = username
                        if let newAvatar = avatarData {
                            profileManager.avatarData = newAvatar
                        }
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
        .onAppear {
            firstName = profileManager.firstName
            lastName = profileManager.lastName
            username = profileManager.username
            avatarData = profileManager.avatarData
        }
    }
}
