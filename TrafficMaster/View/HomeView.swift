//
//  HomeView.swift
//  TrafficMaster
//
//  Created by Влад on 18.02.26.
//

import SwiftUI

// MARK: - Models for the Path
struct LearningSection: Identifiable, Sendable {
    let id: UUID
    let title: String
    let subtitle: String
    let color: Color
    let nodes: [PathNode]
    
    init(id: UUID = UUID(), title: String, subtitle: String, color: Color, nodes: [PathNode]) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.color = color
        self.nodes = nodes
    }
}

struct PathNode: Identifiable, Sendable {
    let id: UUID
    let chapterName: String
    let isLocked: Bool
    let isCurrent: Bool
    let isCompleted: Bool
    let questions: [Question]
    
    init(id: UUID = UUID(), chapterName: String, isLocked: Bool, isCurrent: Bool, isCompleted: Bool, questions: [Question]) {
        self.id = id
        self.chapterName = chapterName
        self.isLocked = isLocked
        self.isCurrent = isCurrent
        self.isCompleted = isCompleted
        self.questions = questions
    }
}

struct HomeView: View {
    @State private var viewModel = QuestionViewModel()
    @State private var dynamicSections: [LearningSection] = []
    @State private var currentStreak: Int = 0
    @AppStorage("daily_new_limit") private var dailyNewLimit: Int = 34
    @State private var isLoading = true
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if isLoading && dynamicSections.isEmpty {
                    VStack {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Загрузка программы...")
                            .font(.system(.headline, design: .rounded))
                            .foregroundColor(.secondary)
                            .padding(.top, 10)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            TopGamificationBar(streak: currentStreak)
                                .padding(.top, 10)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 10)
                            
                            limitPicker
                            
                            DailyStudyButton(questions: viewModel.allQuestions, dailyLimit: dailyNewLimit)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 20)
                            
                            LazyVStack(spacing: 0) {
                                ForEach(dynamicSections) { section in
                                    SectionView(section: section)
                                }
                            }
                            .padding(.bottom, 100)
                        }
                    }
                }
            }
        }
        .onAppear {
            currentStreak = ProgressTracker.shared.calculateStreak()
            viewModel.loadQuestions(dailyNewLimit: dailyNewLimit)
            updateSections()
        }
        .onChange(of: viewModel.allQuestions) { _, _ in
            updateSections()
        }
    }
    
    private var limitPicker: some View {
        HStack {
            Text("Новых карточек в день:")
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundColor(.secondary)
            Spacer()
            Picker("Лимит", selection: $dailyNewLimit) {
                Text("10").tag(10)
                Text("20").tag(20)
                Text("30").tag(30)
                Text("34").tag(34)
                Text("50").tag(50)
                Text("80").tag(80)
                Text("100").tag(100)
            }
            .tint(.orange)
        }
        .padding(.horizontal, 30)
        .padding(.bottom, 10)
    }
    
    private func updateSections() {
        let questions = viewModel.allQuestions
        guard !questions.isEmpty else { return }
        
        self.dynamicSections = HomeView.calculateSectionsStatic(from: questions)
        self.isLoading = false
    }
    
    @MainActor
    private static func calculateSectionsStatic(from questions: [Question]) -> [LearningSection] {
        let sectionsDict = Dictionary(grouping: questions, by: { $0.sectionTitle ?? "Раздел 1" })
        
        var sections: [LearningSection] = []
        let colors: [Color] = [.blue, .purple, .orange, .pink]
        var isCurrentAssigned = false
        
        for (secIndex, sectionTitle) in sectionsDict.keys.sorted().enumerated() {
            let sectionQs = sectionsDict[sectionTitle]!
            let chaptersDict = Dictionary(grouping: sectionQs, by: { $0.chapterTitle ?? "Глава 1" })
            
            var nodes: [PathNode] = []
            for chapterTitle in chaptersDict.keys.sorted() {
                let chapterQs = chaptersDict[chapterTitle]!
                let isCompleted = chapterQs.allSatisfy { $0.repetitions > 0 }
                let isCurrent = !isCompleted && !isCurrentAssigned
                
                if isCurrent { isCurrentAssigned = true }
                
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
                subtitle: "",
                color: colors[secIndex % colors.count],
                nodes: nodes
            ))
        }
        return sections
    }
}

// MARK: - Section View (Unit Header + Nodes)
struct SectionView: View {
    let section: LearningSection
    
    var body: some View {
        VStack(spacing: 30) {
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
    
    var completedTop: Color { colorScheme == .dark ? Color(red: 0.15, green: 0.65, blue: 0.2) : Color.green }
    var completedBottom: Color {
        colorScheme == .dark ? Color(red: 0.05, green: 0.45, blue: 0.1) : Color(red: 0.1, green: 0.6, blue: 0.1)
    }
    var currentTop: Color { colorScheme == .dark ? Color(red: 0.85, green: 0.75, blue: 0.1) : Color.yellow }
    var currentBottom: Color { colorScheme == .dark ? Color(red: 0.8, green: 0.5, blue: 0.0) : Color.orange }
    var lockedTop: Color {
        colorScheme == .dark ? Color(red: 0.6, green: 0.2, blue: 0.2) : Color(red: 0.85, green: 0.3, blue: 0.3)
    }
    var lockedBottom: Color {
        colorScheme == .dark ? Color(red: 0.4, green: 0.1, blue: 0.1) : Color(red: 0.6, green: 0.1, blue: 0.1)
    }
    
    var body: some View {
        let xOffset = sin(Double(index) * 1.5) * 60
        
        ZStack {
            if node.isLocked {
                lockedNode
            } else if node.isCompleted {
                completedNode
            } else if node.isCurrent {
                currentNode
            }
        }
        .offset(x: xOffset)
    }
    
    private var lockedNode: some View {
        ZStack {
            Circle().fill(lockedBottom).frame(width: 70, height: 70).offset(y: 8)
            Circle().fill(lockedTop).frame(width: 70, height: 70)
                .overlay(Image(systemName: "lock.fill").foregroundColor(.white.opacity(0.8)).font(.title2))
        }
        .scaleEffect(y: 0.85)
    }
    
    private var completedNode: some View {
        NavigationLink(destination: QuestionView(questions: node.questions)) {
            ZStack {
                Circle().fill(completedBottom).frame(width: 70, height: 70).offset(y: 8)
                Circle().fill(completedTop).frame(width: 70, height: 70)
                    .overlay(Image(systemName: "star.fill").foregroundColor(.white).font(.title))
            }
            .scaleEffect(y: 0.85)
        }
        .buttonStyle(SquishyNodeButtonStyle())
    }
    
    private var currentNode: some View {
        NavigationLink(destination: QuestionView(questions: node.questions)) {
            ZStack {
                ZStack {
                    Circle()
                        .stroke(currentTop.opacity(0.6), lineWidth: 6)
                        .frame(width: 100, height: 100)
                        .scaleEffect(bounce ? 1.4 : 1.0)
                        .opacity(bounce ? 0 : 1)
                    
                    Circle()
                        .fill(currentBottom)
                        .frame(width: 100, height: 100)
                        .offset(y: 12)
                    
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
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) { bounce.toggle() }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { floating.toggle() }
        }
    }
}

struct SquishyNodeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .offset(y: configuration.isPressed ? 4 : 0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct TopGamificationBar: View {
    let streak: Int
    var body: some View {
        HStack {
            Image(systemName: "flag.checkered.circle.fill")
                .foregroundColor(.orange)
                .font(.title2)
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: "flame.fill").foregroundColor(.orange)
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

struct DailyStudyButton: View {
    let questions: [Question]
    let dailyLimit: Int
    
    var body: some View {
        let questionCount = questions.count
        let destination = QuestionView(questions: questions, dailyLimit: dailyLimit)
        
        NavigationLink(destination: destination) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 50, height: 50)

                    Image(systemName: "timer")
                        .font(.title2)
                        .foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Продолжить обучение")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundColor(.primary)
                    
                    if questionCount > 0 {
                        Text("Сессия до 20 минут, новых: \(dailyLimit)")
                            .font(.system(.caption, design: .rounded, weight: .medium))
                            .foregroundColor(.secondary)
                    } else {
                        Text("Загрузка вопросов...")
                            .font(.system(.caption, design: .rounded, weight: .medium))
                            .foregroundColor(.orange)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.secondary)
                    .padding(.trailing, 8)
            }
            .padding(12)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(SquishyNodeButtonStyle())
        .disabled(questionCount == 0)
        .opacity(questionCount == 0 ? 0.5 : 1.0)
    }
}

#Preview {
    HomeView()
}
