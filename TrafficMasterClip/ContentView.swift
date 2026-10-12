//
//  ContentView.swift
//  TrafficMasterClip
//
//  Created by Влад on 12/10/26.
//

import SwiftUI
import StoreKit

struct ContentView: View {
    @State private var selectedMode: AppClipMode = .battle
    @State private var showingAppStoreSheet: Bool = false
    @State private var showingStoreOverlay: Bool = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Top Pitch Bar
                topPitchBar
                
                // Mode Segmented Picker
                Picker("Режим", selection: $selectedMode) {
                    ForEach(AppClipMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                
                // Main Content View
                TabView(selection: $selectedMode) {
                    BattleView()
                        .tag(AppClipMode.battle)
                    
                    InteractiveQuizView()
                        .tag(AppClipMode.interactiveQuiz)
                    
                    InvestorPitchView()
                        .tag(AppClipMode.investorPitch)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 6) {
                        Image(systemName: "bolt.badge.checkmark.fill")
                            .foregroundColor(.accentColor)
                        Text("TrafficMaster")
                            .font(.system(.headline, design: .rounded, weight: .bold))
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAppStoreSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Text("Полная версия")
                                .font(.system(.caption, design: .rounded, weight: .bold))
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.caption)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.accentColor.opacity(0.15))
                        .foregroundColor(.accentColor)
                        .clipShape(Capsule())
                    }
                }
            }
            .sheet(isPresented: $showingAppStoreSheet) {
                AppStorePromoteSheet()
            }
        }
    }
    
    // MARK: - Subviews
    
    private var topPitchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "qrcode.viewfinder")
                .foregroundColor(.accentColor)
                .font(.caption)
            Text("App Clip Live Demo • Отсканировано с презентации")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color(uiColor: .tertiarySystemFill))
    }
}

#Preview {
    ContentView()
}
