//
//  InvestorPitchView.swift
//  TrafficMasterClip
//
//  Created by Влад on 12/10/26.
//

import SwiftUI

struct InvestorPitchView: View {
    @State private var annualStudents: Double = 60_000
    private let pricePerStudent: Double = 24.0 // $24 average LTV subscription before GAI
    
    private var projectedRevenue: Double {
        annualStudents * pricePerStudent
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Pitch Header
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
        VStack(alignment: .leading, spacing: 12) {
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
            
            Text("Переосмысление подготовки к ПДД через когнитивную науку и AI")
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundColor(.primary)
                .lineSpacing(3)
            
            Text("Классические сервисы (ADrive, автошкольные тренажеры) заставляют зазубривать сухие формулировки. TrafficMaster формирует устойчивые нейронные связи через мнемоники и алгоритм SM-2.")
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
        VStack(alignment: .leading, spacing: 14) {
            Text("СРАВНИТЕЛЬНАЯ ЭФФЕКТИВНОСТЬ:")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(InvestorMetricsRepository.metrics) { metric in
                    VStack(alignment: .leading, spacing: 8) {
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
                        
                        Text("vs \(metric.classicValue) в классике")
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
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.accentColor)
                Text("СИМУЛЯТОР ВЫРУЧКИ (UNIT ECONOMICS):")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 8) {
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
                VStack(alignment: .leading, spacing: 4) {
                    Text("LTV на ученика")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("$\(Int(pricePerStudent))")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Прогноз ARR (Годовая выручка)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("$\(Int(projectedRevenue).formatted())")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundColor(.green)
                }
            }
            .padding(.top, 4)
        }
        .padding(18)
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(20)
    }
    
    // MARK: - Tech Moat Card
    
    private var techMoatCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "shield.lefthalf.filled")
                    .foregroundColor(.purple)
                Text("ТЕХНОЛОГИЧЕСКИЙ РОВ (MOAT):")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
            }
            
            moatItem(
                icon: "bolt.fill",
                color: .orange,
                title: "App Clip < 10 МБ",
                desc: "Мгновенный запуск по QR-коду за 0.8 сек без установки из App Store — идеальная конверсия на оффлайн-презентациях и в автошколах."
            )
            
            moatItem(
                icon: "brain.fill",
                color: .purple,
                title: "Кастомный SM-2 Scheduler",
                desc: "Динамический расчет коэффициента забывания (Ease Factor) под специфику ПДД с автоматической адаптацией под слабые темы."
            )
            
            moatItem(
                icon: "bubble.left.and.exclamationmark.bubble.right.fill",
                color: .blue,
                title: "Контекстный AI-Тьютор",
                desc: "Интегрированная языковая модель, отвечающая на вопросы 'почему' без галлюцинаций, строго на базе официальных ПДД."
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
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.15))
                        .frame(width: 50, height: 50)
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.accentColor)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Влад")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                    Text("Основатель TrafficMaster")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button {
                    // Open investor pitch link or email
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
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(20)
    }
}
