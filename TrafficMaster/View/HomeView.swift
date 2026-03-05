//
//  HomeView.swift
//  TrafficMaster
//
//  Created by Влад on 18.02.26.
//

import SwiftUI
import SwiftData

// MARK: - Models for the Path
struct LearningSection: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let color: Color
    let nodes: [PathNode]
}

struct PathNode: Identifiable {
    let id = UUID()
    let chapterName: String
    let isLocked: Bool
    let isCurrent: Bool
    let isCompleted: Bool
    let questions: [Question] // Вопросы для конкретной главы
}

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Question.nextReviewDate) private var allQuestions: [Question]
    
    // Динамически вычисляем путь на основе вопросов
    var dynamicSections: [LearningSection] {
        // 1. Группируем вопросы по разделам и главам
        let sectionsDict = Dictionary(grouping: allQuestions, by: { $0.sectionTitle ?? "Раздел 1" })
        
        var sections: [LearningSection] = []
        let colors: [Color] = [.blue, .purple, .orange, .pink]
        
        var isCurrentAssigned = false
        
        // Сортируем разделы по названию
        for (secIndex, sectionTitle) in sectionsDict.keys.sorted().enumerated() {
            let sectionQs = sectionsDict[sectionTitle]!
            let chaptersDict = Dictionary(grouping: sectionQs, by: { $0.chapterTitle ?? "Глава 1" })
            
            var nodes: [PathNode] = []
            
            // Сортируем главы по названию
            for chapterTitle in chaptersDict.keys.sorted() {
                let chapterQs = chaptersDict[chapterTitle]!
                
                // Проверяем статус главы
                let isCompleted = chapterQs.allSatisfy { $0.repetitions > 0 }
                let isCurrent = !isCompleted && !isCurrentAssigned
                
                if isCurrent {
                    isCurrentAssigned = true
                }
                
                let isLocked = !isCompleted && !isCurrent
                
                nodes.append(PathNode(
                    chapterName: chapterTitle,
                    isLocked: isLocked,
                    isCurrent: isCurrent,
                    isCompleted: isCompleted,
                    questions: chapterQs
                ))
            }
            
            sections.append(LearningSection(
                title: sectionTitle,
                subtitle: "", // Можно добавить логику для подзаголовка
                color: colors[secIndex % colors.count],
                nodes: nodes
            ))
        }
        
        return sections
    }
    
    @State private var currentStreak: Int = 0
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Фон
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        // Верхний бар со статистикой (Огоньки)
                        TopGamificationBar(streak: currentStreak)
                            .padding(.top, 10)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                        
                        // Игровой путь
                        VStack(spacing: 0) {
                            ForEach(dynamicSections) { section in
                                SectionView(section: section)
                            }
                        }
                        .padding(.bottom, 100)
                    }
                }
            }
        }
        .onAppear {
            currentStreak = ProgressTracker.shared.calculateStreak()
        }
    }
}

// MARK: - Section View (Unit Header + Nodes)
struct SectionView: View {
    let section: LearningSection
    
    var body: some View {
        VStack(spacing: 30) {
            // Заголовок раздела
            VStack(alignment: .leading, spacing: 4) {
                Text(section.title)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundColor(.white)
                Text(section.subtitle)
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(section.color.opacity(0.8))
                    .shadow(color: section.color.opacity(0.3), radius: 10, x: 0, y: 5)
            )
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            // Узлы (станции)
            VStack(spacing: 40) {
                ForEach(Array(section.nodes.enumerated()), id: \.element.id) { index, node in
                    NodeView(node: node, sectionColor: section.color, index: index)
                }
            }
            .padding(.vertical, 20)
        }
    }
}

// MARK: - Node View (Station)
struct NodeView: View {
    let node: PathNode
    let sectionColor: Color
    let index: Int
    
    @State private var bounce = false
    @State private var floating = false
    @Environment(\.colorScheme) var colorScheme
    
    // Цвета для состояний (Apple HIG совместимые, темнеют в темной теме)
    var completedTop: Color { colorScheme == .dark ? Color(red: 0.15, green: 0.65, blue: 0.2) : Color.green }
    var completedBottom: Color { colorScheme == .dark ? Color(red: 0.05, green: 0.45, blue: 0.1) : Color(red: 0.1, green: 0.6, blue: 0.1) }
    
    var currentTop: Color { colorScheme == .dark ? Color(red: 0.85, green: 0.75, blue: 0.1) : Color.yellow }
    var currentBottom: Color { colorScheme == .dark ? Color(red: 0.8, green: 0.5, blue: 0.0) : Color.orange }
    
    var lockedTop: Color { colorScheme == .dark ? Color(red: 0.6, green: 0.2, blue: 0.2) : Color(red: 0.85, green: 0.3, blue: 0.3) }
    var lockedBottom: Color { colorScheme == .dark ? Color(red: 0.4, green: 0.1, blue: 0.1) : Color(red: 0.6, green: 0.1, blue: 0.1) }
    
    var body: some View {
        // Вычисляем смещение влево/вправо для извилистого пути
        let xOffset = sin(Double(index) * 1.5) * 60
        
        ZStack {
            if node.isLocked {
                // Заблокированная станция (Бордовые оттенки, без прозрачности)
                ZStack {
                    // Нижний слой (3D объем)
                    Circle()
                        .fill(lockedBottom)
                        .frame(width: 70, height: 70)
                        .offset(y: 8)
                    
                    // Верхний слой
                    Circle()
                        .fill(lockedTop)
                        .frame(width: 70, height: 70)
                        .overlay(
                            Image(systemName: "lock.fill")
                                .foregroundColor(.white.opacity(0.8))
                                .font(.title2)
                        )
                }
                .scaleEffect(y: 0.85) // Эффект перспективы (эллипс)
            } else if node.isCompleted {
                // Пройденная станция (Зеленая)
                NavigationLink(destination: QuestionView(questions: node.questions)) {
                    ZStack {
                        // Нижний слой (3D объем)
                        Circle()
                            .fill(completedBottom)
                            .frame(width: 70, height: 70)
                            .offset(y: 8)
                        
                        // Верхний слой
                        Circle()
                            .fill(completedTop)
                            .frame(width: 70, height: 70)
                            .overlay(
                                Image(systemName: "star.fill")
                                    .foregroundColor(.white)
                                    .font(.title)
                            )
                    }
                    .scaleEffect(y: 0.85)
                }
                .buttonStyle(SquishyNodeButtonStyle())
            } else if node.isCurrent {
                // Текущая станция (Желтая, Активная)
                NavigationLink(destination: QuestionView(questions: node.questions)) {
                    ZStack {
                        // Сама кнопка (Увеличена!)
                        ZStack {
                            // Пульсирующий фон (теперь внутри 3D кнопки, чтобы масштабироваться вместе с ней и исходить из центра)
                            Circle()
                                .stroke(currentTop.opacity(0.6), lineWidth: 6)
                                .frame(width: 100, height: 100) // Начинается от размера кнопки
                                .scaleEffect(bounce ? 1.4 : 1.0) // Увеличиваем радиус разлета
                                .opacity(bounce ? 0 : 1)
                            
                            // Нижний слой (3D объем, более высокий)
                            Circle()
                                .fill(currentBottom)
                                .frame(width: 100, height: 100)
                                .offset(y: 12)
                            
                            // Верхний слой
                            Circle()
                                .fill(currentTop)
                                .frame(width: 100, height: 100)
                                .overlay(
                                    Image(systemName: "play.fill")
                                        .foregroundColor(.white)
                                        .font(.title)
                                        .offset(x: 2)
                                )
                        }
                        .scaleEffect(y: 0.85)
                        
                        // Подсказка "START"
                        VStack {
                            Text("START")
                                .font(.system(.caption, design: .rounded, weight: .bold))
                                .foregroundColor(currentBottom)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color.white)
                                .clipShape(Capsule())
                                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                                .offset(y: floating ? -10 : -15)
                        }
                        .offset(y: -65)
                    }
                }
                .buttonStyle(SquishyNodeButtonStyle())
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                        bounce.toggle()
                    }
                    withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                        floating.toggle()
                    }
                }
            }
        }
        .offset(x: xOffset)
    }
}

// Кастомный стиль кнопки для 3D нажатия
struct SquishyNodeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            // При нажатии "вдавливаем" кнопку вниз
            .offset(y: configuration.isPressed ? 4 : 0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Top Gamification Bar
struct TopGamificationBar: View {
    let streak: Int
    
    var body: some View {
        HStack {
            // Флаг или Иконка
            Image(systemName: "flag.checkered.circle.fill")
                .foregroundColor(.orange)
                .font(.title2)
            
            Spacer()
            
            // Огонек (Стрик)
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .foregroundColor(.orange)
                Text("\(streak)")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundColor(.orange)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.orange.opacity(0.15))
            .clipShape(Capsule())
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.white.opacity(0.3), lineWidth: 1)
        )
    }
}

#Preview {
    HomeView()
}
