//
//  ProfileManager.swift
//  TrafficMaster
//
//  Created by Влад on 18.02.26.
//

import SwiftUI
import Combine

class ProfileManager: ObservableObject {
    static let shared = ProfileManager()
    
    @AppStorage("isLoggedIn") var isLoggedIn: Bool = false
    @AppStorage("firstName") var firstName: String = ""
    @AppStorage("lastName") var lastName: String = ""
    @AppStorage("username") var username: String = ""
    
    @Published var avatarData: Data? {
        didSet {
            saveAvatar(data: avatarData)
        }
    }
    
    init() {
        self.avatarData = loadAvatar()
    }
    
    var fullName: String {
        let name = [firstName, lastName].filter { !$0.isEmpty }.joined(separator: " ")
        return name.isEmpty ? "Студент" : name
    }
    
    // MARK: - Avatar Storage
    
    private let avatarFileName = "profile_avatar.png"
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private func saveAvatar(data: Data?) {
        let fileURL = getDocumentsDirectory().appendingPathComponent(avatarFileName)
        if let data = data {
            try? data.write(to: fileURL)
        } else {
            try? FileManager.default.removeItem(at: fileURL)
        }
    }
    
    private func loadAvatar() -> Data? {
        let fileURL = getDocumentsDirectory().appendingPathComponent(avatarFileName)
        return try? Data(contentsOf: fileURL)
    }
}
