import Foundation
import Testing
@testable import TrafficMaster

struct FSRSSchedulerTests {
    @Test("Again schedules short relearning interval")
    func againRating() {
        let scheduler = FSRSScheduler()
        let now = Date()
        let state = FSRSState(
            status: .review,
            dueAt: now.addingTimeInterval(-86_400),
            stability: 5,
            difficulty: 4,
            repetitions: 6,
            lapses: 0,
            lastReviewAt: now.addingTimeInterval(-172_800)
        )

        let result = scheduler.review(state: state, rating: .again, now: now)

        #expect(result.state.status == .relearning)
        #expect(result.state.repetitions == 0)
        #expect(result.state.lapses == 1)
        #expect(result.state.dueAt > now)
        #expect(result.state.dueAt < now.addingTimeInterval(3_600))
    }

    @Test("Hard/Good/Easy increase interval monotonically")
    func increasingIntervals() {
        let scheduler = FSRSScheduler()
        let now = Date()
        let state = FSRSState(
            status: .review,
            dueAt: now.addingTimeInterval(-86_400),
            stability: 6,
            difficulty: 4,
            repetitions: 8,
            lapses: 1,
            lastReviewAt: now.addingTimeInterval(-86_400 * 3)
        )

        let hard = scheduler.review(state: state, rating: .hard, now: now).state
        let good = scheduler.review(state: state, rating: .good, now: now).state
        let easy = scheduler.review(state: state, rating: .easy, now: now).state

        #expect(hard.dueAt <= good.dueAt)
        #expect(good.dueAt <= easy.dueAt)
        #expect(hard.repetitions > state.repetitions)
        #expect(good.repetitions > state.repetitions)
        #expect(easy.repetitions > state.repetitions)
    }
}
