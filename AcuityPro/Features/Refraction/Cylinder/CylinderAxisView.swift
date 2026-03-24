import SwiftUI

/// Presents the fan chart for axis identification.
struct CylinderAxisView: View {
    @ObservedObject var viewModel: CylinderTestViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(viewModel.eye.displayName) Eye")
                    .font(.headline)
                Spacer()
                Text("Cylinder Axis")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            Spacer()

            FanChartView { degrees in
                viewModel.selectAxis(degrees)
            }

            Spacer()
        }
    }
}
