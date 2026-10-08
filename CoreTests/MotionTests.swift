import Core
import Foundation
import SwiftUI
import Testing

/// The one motion system: speeds, night, the curve, stagger, Reduce Motion,
/// and Progress's once-a-day rise.
struct MotionTests {
    @Test func threeSpeedsAndNightIsSlower() {
        #expect(Motion.duration(.quick, night: false) == 0.2)
        #expect(Motion.duration(.standard, night: false) == 0.35)
        #expect(Motion.duration(.gentle, night: false) == 0.6)
        for speed in Motion.Speed.allCases {
            #expect(abs(Motion.duration(speed, night: true) - speed.seconds * 1.3) < 0.0001)
        }
    }

    @Test func nightFollowsTheClockAtTheEdges() {
        let calendar = TestTime.calendar
        #expect(NightMode.isActive(at: TestTime.date(26, 20, 0), calendar: calendar))
        #expect(NightMode.isActive(at: TestTime.date(27, 6, 59), calendar: calendar))
        #expect(!NightMode.isActive(at: TestTime.date(27, 7, 0), calendar: calendar))
        #expect(!NightMode.isActive(at: TestTime.date(26, 19, 59), calendar: calendar))
    }

    @Test func oneCurveWithNoOvershoot() {
        let c = Motion.curve
        #expect(c.x1 == 0.3 && c.y1 == 0 && c.x2 == 0.2 && c.y2 == 1)
        // Control points inside 0...1 can't overshoot.
        #expect([c.y1, c.y2].allSatisfy { (0...1).contains($0) })
    }

    @Test func arriveWaits60msEachAndAtMostSix() {
        #expect(Motion.delay(index: 0) == 0)
        #expect(abs(Motion.delay(index: 2) - 0.12) < 0.0001)
        #expect(Motion.delay(index: 20) == Motion.delay(index: 6))
        #expect(Motion.delay(index: -3) == 0)
    }

    @Test func reduceMotionKeepsTheMeaningWithoutMovement() {
        #expect(Motion.pressScale(reduceMotion: false) == 0.96)
        #expect(Motion.pressScale(reduceMotion: true) == 1)
        #expect(Motion.riseOffset(reduceMotion: false) == 8)
        #expect(Motion.riseOffset(reduceMotion: true) == 0)
    }

    @Test func progressRisesOnlyTheFirstTimeEachDay() {
        let calendar = TestTime.calendar
        let morning = TestTime.date(26, 9)
        #expect(Motion.shouldArrive(lastShown: nil, now: morning, calendar: calendar))
        let key = Motion.dayKey(morning, calendar: calendar)
        #expect(!Motion.shouldArrive(lastShown: key, now: TestTime.date(26, 21), calendar: calendar))
        #expect(Motion.shouldArrive(lastShown: key, now: TestTime.date(27, 8), calendar: calendar))
    }
}
