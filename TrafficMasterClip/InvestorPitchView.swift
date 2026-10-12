//
//  InvestorPitchView.swift
//  TrafficMasterClip
//
//  Created by Влад on 12/10/26.
//

import SwiftUI

struct InvestorPitchView: View {
    @State private var annualStudents: Double = 60_000
    private let pricePerStudent: Double = 24.0 // $24 average LTV
    
    private var projectedRevenue: Double {
        annualStudents * pricePerStudent
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Pitch Hero
                pitchHeroCard
                
                // Key Traction Metrics Grid
                tractionMetricsGrid
                
                // Interactive Unit Economics Calculator
                unitEconomicsCalculator
                
                // Tech Moat Card
                techMoatCard
                
                // Founder Contact Card
                founderContactCard
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
    
    // MARK: - Hero Card
    
    private var pitchHeroCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("INVESTOR DECK SNAPSHOT")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundColor(.accentColor)
                Spacer()
                Text("Pre-Seed / Seed")
                    .font(.caption2.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.15))
                    .foregroundColor(.green)
                    .clipShape(Capsule())
            }
            
            Text("Когнитивный EdTech для сдачи ПДД с 1-й попытки")
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundColor(.primary)
                .lineSpacing(2)
            
            Text("Вместо заучивания 400 страниц казуистики — мнемоники, адаптивный SM-2 алгоритм и персональный AI-тьютор.")
                .font(.system(.subheadline, design: .rounded))
                .foregroundColor(.secondary)
                .lineSpacing(2)
        }
        .padding(18)
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(20)
    }
    
    // MARK: - Traction Grid
    
    private var tractionMetricsGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("МЕТРИКИ ЭФФЕКТИВНОСТИ:")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(InvestorMetricsRepository.metrics) { metric in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: metric.icon)
                                .foregroundColor(.accentColor)
                                .font(.subheadline)
                            Spacer()
                            Text(metric.delta)
                                .font(.caption2.bold())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.15))
                                .foregroundColor(.green)
                                .clipShape(Capsule())
                        }
                        
                        Text(metric.tmValue)
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text("vs \(metric.classicValue) в тестах")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        
                        Text(metric.title)
                            .font(.system(.caption2, design: .rounded, weight: .medium))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    .padding(14)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .cornerRadius(16)
                }
            }
        }
    }
    
    // MARK: - Unit Economics Simulator
    
    private var unitEconomicsCalculator: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.accentColor)
                Text("UNIT ECONOMICS & ARR:")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Курсантов в год:")
                        .font(.system(.subheadline, design: .rounded))
                    Spacer()
                    Text("\(Int(annualStudents).formatted()) чел.")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundColor(.accentColor)
                }
                
                Slider(value: $annualStudents, in: 10_000...200_000, step: 5_000)
                    .tint(.accentColor)
            }
            
            Divider()
            
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("LTV на ученика")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("$\(Int(pricePerStudent))")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Прогноз ARR")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("$\(Int(projectedRevenue).formatted())")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundColor(.green)
                }
            }
        }
        .padding(18)
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(20)
    }
    
    // MARK: - Tech Moat Card
    
    private var techMoatCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "shield.lefthalf.filled")
                    .foregroundColor(.purple)
                Text("ТЕХНОЛОГИЧЕСКИЙ РОВ:")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
            }
            
            moatItem(
                icon: "bolt.fill",
                color: .orange,
                title: "App Clip < 10 МБ",
                desc: "Запуск за 0.8с по QR-коду без App Store. Максимальная конверсия вживую."
            )
            
            moatItem(
                icon: "brain.fill",
                color: .purple,
                title: "Кастомный SM-2 Движок",
                desc: "Адаптивный расчет кривой забывания под когнитивный профиль ученика."
            )
            
            moatItem(
                icon: "bubble.left.and.sparkles.fill",
                color: .blue,
                title: "AI-Тьютор на базе ПДД",
                desc: "Мгновенные ответы на вопрос 'почему так' без галлюцинаций."
            )
        }
        .padding(18)
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(20)
    }
    
    private func moatItem(icon: String, color: Color, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(color)
                .frame(width: 24, height: 24)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundColor(.primary)
                Text(desc)
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.secondary)
                    .lineSpacing(2)
            }
        }
    }
    
    // MARK: - Founder Contact Card
    
    private var founderContactCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.accentColor)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Влад")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                Text("Founder • TrafficMaster")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button {
                if let url = URL(string: "https://t.me/vlad_trafficmaster") {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Связаться")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(20)
    }
}
