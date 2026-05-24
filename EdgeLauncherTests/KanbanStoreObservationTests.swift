import XCTest
import Observation
@testable import EdgeLauncher

@MainActor
final class KanbanStoreObservationTests: XCTestCase {

    private func makeStore() -> KanbanStore {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("kanban-obs-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return KanbanStore(url: dir.appendingPathComponent("kanban.json"))
    }

    /// 같은 store 를 두 ViewModel 이 부착했을 때, 한쪽의 addCard 호출 후
    /// 다른 쪽의 activeBoard 가 변경된 카드를 보여주는지 확인.
    func test_storeChange_propagatesToSecondViewModel() {
        let store = makeStore()
        let vmA = KanbanViewModel(store: store)
        let vmB = KanbanViewModel(store: store)
        let col = vmA.activeBoard!.columns.first!
        store.addCard(KanbanCard(title: "Bridge?"), to: col.id)
        XCTAssertEqual(vmB.activeBoard!.columns.first!.cards.map(\.title), ["Bridge?"],
                       "store 변경이 다른 VM 에 즉시 반영되어야 한다 (자동 관찰 또는 bridge).")
    }

    /// withObservationTracking 으로 store.data 변경을 감지할 수 있는지.
    func test_observationTracking_seesStoreChange() {
        let store = makeStore()
        let counter = ObservationCounter()
        let col = store.activeBoard!.columns.first!
        withObservationTracking {
            _ = store.data
        } onChange: {
            counter.increment()
        }
        store.addCard(KanbanCard(title: "Track"), to: col.id)
        XCTAssertEqual(counter.value, 1, "store.data 가 observable 이라면 withObservationTracking 이 변경을 감지해야 한다.")
    }
}

/// withObservationTracking 의 onChange 가 @Sendable 클로저라서 var 캡쳐가 Swift 6 에서 에러.
/// 단순 카운터를 reference type 으로 감싼다.
private final class ObservationCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var _value = 0
    var value: Int { lock.lock(); defer { lock.unlock() }; return _value }
    func increment() { lock.lock(); _value += 1; lock.unlock() }
}
