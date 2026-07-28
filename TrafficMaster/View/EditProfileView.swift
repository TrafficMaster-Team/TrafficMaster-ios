//
//  EditProfileView.swift
//  TrafficMaster
//
//  Created by Влад on 18.02.26.
//

import PhotosUI
import SwiftUI

struct EditProfileView: View {
    private enum Field: Hashable {
        case firstName
        case lastName
        case username
    }

    @Environment(\.dismiss) private var dismiss
    @StateObject private var profileManager = ProfileManager.shared
    @FocusState private var focusedField: Field?

    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var username: String = ""
    @State private var showImagePicker = false
    @State private var avatarData: Data?
    @State private var showingDeleteAlert = false
    @State private var showingDeletionError = false
    @State private var deletionErrorMessage = ""
    @State private var isDeletingAccount = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Spacer()
                        Button(action: {
                            showImagePicker = true
                        }, label: {
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
                        })
                        .sheet(isPresented: $showImagePicker) {
                            ImagePicker(selectedImageData: $avatarData)
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }

                Section(header: Text("Личные данные")) {
                    TextField("Имя", text: $firstName)
                        .focused($focusedField, equals: .firstName)
                    TextField("Фамилия", text: $lastName)
                        .focused($focusedField, equals: .lastName)
                    TextField("Имя пользователя (ник)", text: $username)
                        .focused($focusedField, equals: .username)
                        .autocapitalization(.none)
                }

                Section {
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Удалить аккаунт")
                        }
                    }
                }
            }
            .alert("Удаление аккаунта", isPresented: $showingDeleteAlert) {
                Button("Отмена", role: .cancel) {}
                Button("Удалить", role: .destructive) {
                    Task {
                        await deleteAccount()
                    }
                }
            } message: {
                Text("Это действие необратимо. Учётная запись и связанные с ней серверные данные будут удалены.")
            }
            .alert("Не удалось удалить аккаунт", isPresented: $showingDeletionError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(deletionErrorMessage)
            }
            .listStyle(.insetGrouped)
            .disabled(isDeletingAccount)
            .overlay {
                if isDeletingAccount {
                    ProgressView("Удаление аккаунта…")
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
            .navigationTitle("Редактирование")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        focusedField = nil
                        Task { @MainActor in
                            await Task.yield()
                            saveProfile()
                        }
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

    @MainActor
    private func deleteAccount() async {
        isDeletingAccount = true
        defer { isDeletingAccount = false }

        do {
            try await APIClient.shared.deleteCurrentUser()
            profileManager.logout()
            dismiss()
        } catch {
            deletionErrorMessage = error.localizedDescription
            showingDeletionError = true
        }
    }

    private func saveProfile() {
        profileManager.firstName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        profileManager.lastName = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        profileManager.username = username.trimmingCharacters(in: .whitespacesAndNewlines)
        if let newAvatar = avatarData {
            profileManager.avatarData = newAvatar
        }
        dismiss()
    }
}
