//
//  SplashView.swift
//  TrafficMaster
//
//  Created by Влад on 18.02.26.
//

import SwiftUI

struct SplashView: View {
    @State private var size = 0.8
    @State private var opacity = 0.5
    
    var body: some View {
        ZStack {
            // Фон в стиле приложения
            MeshGradientBackground()
                .ignoresSafeArea()
            
            VStack {
                ZStack {
                    // Внешнее свечение
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 140, height: 140)
                        .blur(radius: 20)
                    
                    // Иконка/Логотип
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 100, height: 100)
                            .shadow(color: .blue.opacity(0.5), radius: 15, x: 0, y: 10)
                        
                        Image(systemName: "car.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                    }
                }
                .scaleEffect(size)
                .opacity(opacity)
                .onAppear {
                    withAnimation(.easeIn(duration: 1.2)) {
                        self.size = 1.0
                        self.opacity = 1.0
                    }
                }
                
                Text("TrafficMaster")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundColor(.primary)
                    .padding(.top, 20)
                    .opacity(opacity)
                
                Text("Учи ПДД играючи")
                    .font(.system(.headline, design: .rounded, weight: .medium))
                    .foregroundColor(.secondary)
                    .opacity(opacity)
            }
        }
    }
}

#Preview {
    SplashView()
}
