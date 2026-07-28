//
//  ProfileManager.swift
//  TrafficMaster
//
//  Created by Влад on 18.02.26.
//

import Combine
import SwiftUI

enum SubscriptionTier: String {
    case free
    case student

    var title: String {
        switch self {
        case .free:
            "Базовый"
        case .student:
            "Ученик"
        }
    }

    var isPremium: Bool {
        self == .student
    }
}

class ProfileManager: ObservableObject {
    static let shared = ProfileManager()

    @AppStorage("isLoggedIn") var isLoggedIn: Bool = false
    @AppStorage("firstName") var firstName: String = ""
    @AppStorage("lastName") var lastName: String = ""
    @AppStorage("username") var username: String = ""
    @AppStorage("subscriptionTier") private var subscriptionTierRawValue: String = SubscriptionTier.free.rawValue

    var subscriptionTier: SubscriptionTier {
        get { SubscriptionTier(rawValue: subscriptionTierRawValue) ?? .free }
        set { subscriptionTierRawValue = newValue.rawValue }
    }

    var hasStudentSubscription: Bool {
        subscriptionTier.isPremium || username == "demo_driver"
    }

    @Published var avatarData: Data? {
        didSet {
            saveAvatar(data: avatarData)
        }
    }

    init(defaults: UserDefaults = .standard) {
        _isLoggedIn = AppStorage(wrappedValue: false, "isLoggedIn", store: defaults)
        _firstName = AppStorage(wrappedValue: "", "firstName", store: defaults)
        _lastName = AppStorage(wrappedValue: "", "lastName", store: defaults)
        _username = AppStorage(wrappedValue: "", "username", store: defaults)
        _subscriptionTierRawValue = AppStorage(
            wrappedValue: SubscriptionTier.free.rawValue,
            "subscriptionTier",
            store: defaults
        )
        avatarData = loadAvatar()
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

    func logout() {
        isLoggedIn = false
        firstName = ""
        lastName = ""
        username = ""
        subscriptionTier = .free
        avatarData = nil
    }
}
