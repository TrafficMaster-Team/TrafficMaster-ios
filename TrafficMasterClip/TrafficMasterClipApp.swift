//
//  TrafficMasterClipApp.swift
//  TrafficMasterClip
//
//  Created by Влад on 12/10/26.
//

import SwiftUI

@main
struct TrafficMasterClipApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
                    guard let incomingURL = userActivity.webpageURL else { return }
                    handleIncomingURL(incomingURL)
                }
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
        }
    }
    
    private func handleIncomingURL(_ url: URL) {
        // Handle deep link / App Clip QR code invocation
        // e.g. https://trafficmaster.app/clip
        #if DEBUG
        print("TrafficMaster App Clip opened with URL: \(url.absoluteString)")
        #endif
    }
}
