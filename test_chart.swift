import SwiftUI
import Charts
@available(iOS 17.0, *)
struct TestView: View {
    @State private var sel: String?
    var body: some View {
        Chart {
            BarMark(x: .value("A", "Test"), y: .value("B", 1))
        }
        .chartXSelection(value: $sel)
    }
}
