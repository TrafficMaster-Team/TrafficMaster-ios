//
//  SM2Scheduler.swift
//  TrafficMaster
//
//  Backend-compatible SM-2 scheduler.
//

import Foundation

enum SM2CardState: String, Codable, Sendable {
    case new
    case learning
    case review
    case relearning
}

struct BackendSM2Configuration: Codable, Equatable, Sendable {
    struct NewCards: Codable, Equatable, Sendable {
        var learningSteps: [Int]
        var graduatingInterval: Int
        var easyInterval: Int

        static let `default` = NewCards(
            learningSteps: [1, 10],
            graduatingInterval: 1,
            easyInterval: 4
        )
    }

    struct Lapses: Codable, Equatable, Sendable {
        var relearningSteps: [Int]
        var minInterval: Int

        static let `default` = Lapses(
            relearningSteps: [10],
            minInterval: 1
        )
    }

    struct Advanced: Codable, Equatable, Sendable {
        var maxInterval: Int
        var easeFactor: Double
        var easyFactor: Double
        var intervalModifier: Double
        var hardInterval: Double
        var newInterval: Double

        static let `default` = Advanced(
            maxInterval: 36_500,
            easeFactor: 2.5,
            easyFactor: 1.3,
            intervalModifier: 1.0,
            hardInterval: 1.2,
            newInterval: 0.0
        )
    }

    var newCards: NewCards
    var lapses: Lapses
    var advanced: Advanced

    static let `default` = BackendSM2Configuration(
        newCards: .default,
        lapses: .default,
        advanced: .default
    )
}

final class SM2Scheduler {
    private enum Constants {
        static let minimumEaseFactor = 1.3
        static let maximumEaseFactor = 5.0
        static let againPenalty = 0.2
        static let hardPenalty = 0.15
        static let easyBonus = 0.15
    }

    struct CardState: Sendable {
        var state: SM2CardState
        var easeFactor: Double
        var interval: Int
        var repetitions: Int
        var nextReviewAt: Date?
    }

    enum Grade: Int, Sendable {
        case again = 1
        case hard = 2
        case good = 3
        case easy = 4
    }

    struct ReviewResult: Sendable {
        var state: SM2CardState
        var easeFactor: Double
        var interval: Int
        var repetitions: Int
        var nextReviewAt: Date?
    }

    func reviewCard(
        cardState: CardState,
        grade: Grade,
        config: BackendSM2Configuration = .default,
        reviewTime: Date = Date()
    ) -> ReviewResult {
        var progress = cardState

        switch progress.state {
        case .new, .learning:
            applyLearningProcess(to: &progress, grade: grade, config: config.newCards, now: reviewTime)
        case .review:
            applyReviewProcess(to: &progress, grade: grade, config: config.advanced, now: reviewTime)
        case .relearning:
            applyRelearningProcess(to: &progress, grade: grade, config: config.lapses, now: reviewTime)
        }

        return ReviewResult(
            state: progress.state,
            easeFactor: progress.easeFactor,
            interval: progress.interval,
            repetitions: progress.repetitions,
            nextReviewAt: progress.nextReviewAt
        )
    }

    private func applyLearningProcess(
        to progress: inout CardState,
        grade: Grade,
        config: BackendSM2Configuration.NewCards,
        now: Date
    ) {
        let steps = normalizedSteps(config.learningSteps)
        progress.state = .learning

        switch grade {
        case .again:
            progress.repetitions = 0
            progress.nextReviewAt = addingMinutes(steps[0], to: now)
        case .hard:
            let stepIndex = min(progress.repetitions, steps.count - 1)
            progress.nextReviewAt = addingMinutes(steps[stepIndex], to: now)
        case .good:
            let nextStep = progress.repetitions + 1
            if nextStep >= steps.count {
                progress.state = .review
                progress.interval = max(1, config.graduatingInterval)
                progress.repetitions = 1
                progress.nextReviewAt = addingDays(progress.interval, to: now)
            } else {
                progress.repetitions = nextStep
                progress.nextReviewAt = addingMinutes(steps[nextStep], to: now)
            }
        case .easy:
            progress.state = .review
            progress.interval = max(1, config.easyInterval)
            progress.repetitions = 1
            progress.nextReviewAt = addingDays(progress.interval, to: now)
        }
    }

    private func applyReviewProcess(
        to progress: inout CardState,
        grade: Grade,
        config: BackendSM2Configuration.Advanced,
        now: Date
    ) {
        let currentEase = progress.easeFactor
        let delay = max(0, dayDelay(from: progress.nextReviewAt, to: now))
        let currentInterval = max(1, progress.interval + delay)

        switch grade {
        case .again:
            let newEase = max(Constants.minimumEaseFactor, currentEase - Constants.againPenalty)
            let newInterval = max(1, Int((Double(currentInterval) * config.newInterval).rounded()))
            progress.easeFactor = newEase
            progress.interval = newInterval
            progress.repetitions = 0
            progress.state = .relearning
            progress.nextReviewAt = addingDays(newInterval, to: now)
        case .hard:
            let newEase = max(Constants.minimumEaseFactor, currentEase - Constants.hardPenalty)
            let candidate = Int((Double(currentInterval) * config.hardInterval * config.intervalModifier).rounded())
            let newInterval = min(max(currentInterval + 1, candidate), config.maxInterval)
            progress.easeFactor = newEase
            progress.interval = newInterval
            progress.repetitions += 1
            progress.nextReviewAt = addingDays(newInterval, to: now)
        case .good:
            let candidate = Int((Double(currentInterval) * currentEase * config.intervalModifier).rounded())
            let newInterval = min(max(currentInterval + 1, candidate), config.maxInterval)
            progress.interval = newInterval
            progress.repetitions += 1
            progress.nextReviewAt = addingDays(newInterval, to: now)
        case .easy:
            let newEase = min(Constants.maximumEaseFactor, currentEase + Constants.easyBonus)
            let candidate = Int((Double(currentInterval) * newEase * config.intervalModifier * config.easyFactor).rounded())
            let newInterval = min(max(currentInterval + 1, candidate), config.maxInterval)
            progress.easeFactor = newEase
            progress.interval = newInterval
            progress.repetitions += 1
            progress.nextReviewAt = addingDays(newInterval, to: now)
        }
    }

    private func applyRelearningProcess(
        to progress: inout CardState,
        grade: Grade,
        config: BackendSM2Configuration.Lapses,
        now: Date
    ) {
        let steps = normalizedSteps(config.relearningSteps)

        switch grade {
        case .again:
            progress.repetitions = 0
            progress.nextReviewAt = addingMinutes(steps[0], to: now)
        case .hard:
            let stepIndex = min(progress.repetitions, steps.count - 1)
            progress.nextReviewAt = addingMinutes(steps[stepIndex], to: now)
        case .good:
            let nextStep = progress.repetitions + 1
            if nextStep >= steps.count {
                progress.state = .review
                progress.interval = max(config.minInterval, progress.interval)
                progress.repetitions = 1
                progress.nextReviewAt = addingDays(progress.interval, to: now)
            } else {
                progress.repetitions = nextStep
                progress.nextReviewAt = addingMinutes(steps[nextStep], to: now)
            }
        case .easy:
            progress.state = .review
            progress.interval = max(config.minInterval, progress.interval)
            progress.repetitions = 1
            progress.nextReviewAt = addingDays(progress.interval, to: now)
        }
    }

    private func normalizedSteps(_ steps: [Int]) -> [Int] {
        let validSteps = steps.map { max(1, $0) }
        return validSteps.isEmpty ? [1] : validSteps
    }

    private func addingMinutes(_ minutes: Int, to date: Date) -> Date {
        Calendar.current.date(byAdding: .minute, value: minutes, to: date) ?? date
    }

    private func addingDays(_ days: Int, to date: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: date) ?? date
    }

    private func dayDelay(from dueDate: Date?, to now: Date) -> Int {
        guard let dueDate else { return 0 }
        return Calendar.current.dateComponents([.day], from: dueDate, to: now).day ?? 0
    }
}
