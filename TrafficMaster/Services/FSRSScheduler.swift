import Foundation

final class FSRSScheduler {
    struct ReviewResult: Sendable {
        let state: FSRSState
        let rating: ReviewRating
    }

    func review(state: FSRSState, rating: ReviewRating, now: Date = Date()) -> ReviewResult {
        var next = state
        let daysSinceLast = elapsedDays(since: state.lastReviewAt, until: now)
        let retrievability = state.stability > 0 ? exp(-daysSinceLast / max(state.stability, 0.01)) : 0.0

        switch rating {
        case .again:
            next.status = state.repetitions == 0 ? .learning : .relearning
            next.lapses += 1
            next.repetitions = 0
            next.difficulty = clamp(state.difficulty + 1.0, min: 1.0, max: 10.0)
            next.stability = max(0.25, max(state.stability, 0.6) * 0.35)
            next.dueAt = Calendar.current.date(byAdding: .minute, value: 10, to: now) ?? now

        case .hard:
            next.status = state.repetitions == 0 ? .learning : .review
            next.repetitions = max(1, state.repetitions + 1)
            next.difficulty = clamp(state.difficulty + 0.3, min: 1.0, max: 10.0)
            let base = max(state.stability, state.repetitions == 0 ? 1.0 : 0.8)
            next.stability = max(0.8, base * (1.2 + (1.0 - retrievability) * 0.2))
            let days = max(1, Int((next.stability * 0.55).rounded()))
            next.dueAt = Calendar.current.date(byAdding: .day, value: days, to: now) ?? now

        case .good:
            next.status = .review
            next.repetitions = max(1, state.repetitions + 1)
            next.difficulty = clamp(state.difficulty - 0.15, min: 1.0, max: 10.0)
            let base = max(state.stability, state.repetitions == 0 ? 2.2 : 1.0)
            next.stability = max(1.0, base * (1.8 + (1.0 - retrievability) * 0.6))
            let days = max(1, Int(next.stability.rounded()))
            next.dueAt = Calendar.current.date(byAdding: .day, value: days, to: now) ?? now

        case .easy:
            next.status = .review
            next.repetitions = max(1, state.repetitions + 1)
            next.difficulty = clamp(state.difficulty - 0.4, min: 1.0, max: 10.0)
            let base = max(state.stability, state.repetitions == 0 ? 3.5 : 1.5)
            next.stability = max(1.5, base * (2.4 + (1.0 - retrievability) * 0.8))
            let days = max(2, Int((next.stability * 1.3).rounded()))
            next.dueAt = Calendar.current.date(byAdding: .day, value: days, to: now) ?? now
        }

        next.lastReviewAt = now
        return ReviewResult(state: next, rating: rating)
    }

    private func elapsedDays(since start: Date?, until end: Date) -> Double {
        guard let start else { return 0 }
        return max(0, end.timeIntervalSince(start) / 86_400.0)
    }

    private func clamp(_ value: Double, min: Double, max: Double) -> Double {
        Swift.max(min, Swift.min(max, value))
    }
}
