import SwiftUI

struct SelectionSlider<T: Hashable>: View {
    let title: String
    let items: [T]
    @Binding var selectedItem: T?

    let itemName: (T) -> String
    let onAddCustom: () -> Void
    var itemImageName: ((T) -> String?)? = nil

    var body: some View {
        VStack(spacing: 20) {
            Text(title)
                .font(.system(size: 22, design: .rounded))
                .foregroundColor(AppColour.txtCoklat)

            GeometryReader { proxy in
                let horizontalPadding = proxy.size.width * 0.05
                let cardSpacing = proxy.size.width * 0.045
                let cardWidth = (proxy.size.width - (horizontalPadding * 2) - (cardSpacing * 3)) / 4
                let cardHeight = cardWidth * 0.52

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: cardSpacing) {
                        ForEach(items, id: \.self) { item in
                            optionCard(for: item, width: cardWidth, height: cardHeight)
                        }

                        Button(action: onAddCustom) {
                            VStack(spacing: 6) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(AppColour.cardKuning)
                                    .frame(width: cardWidth, height: cardHeight)
                                    .overlay {
                                        Image(systemName: "plus")
                                            .font(.system(size: cardHeight * 0.28, weight: .bold))
                                            .foregroundColor(AppColour.txtCoklat)
                                    }

                                Text("Add Custom")
                                    .font(.system(.headline, design: .rounded).weight(.semibold))
                                    .foregroundColor(AppColour.txtCoklat)
                                    .lineLimit(1)
                            }
                            .frame(width: cardWidth)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, horizontalPadding)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .padding(.top, 18)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity)
        .background(
            CustomRoundedCorner(radius: 26, corners: [.topLeft, .topRight])
                .fill(AppColour.bgPutih)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    @ViewBuilder
    private func optionCard(for item: T, width: CGFloat, height: CGFloat) -> some View {
        Button(action: {
            selectedItem = item
        }) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(AppColour.cardKuning.opacity(selectedItem == item ? 1.0 : 0.72))

                    if let imageName = itemImageName?(item), !imageName.isEmpty {
                        Image(imageName)
                            .resizable()
                            .scaledToFill()
                            .frame(width: width, height: height)
                            .clipped()
                    }

                    RoundedRectangle(cornerRadius: 2)
                        .stroke(
                            AppColour.txtCoklat,
                            lineWidth: selectedItem == item ? 2.5 : 0
                        )
                }
                .frame(width: width, height: height)

                Text(formatEnumText(itemName(item)))
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .foregroundColor(AppColour.txtCoklat)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(width: width)
        }
        .buttonStyle(.plain)
    }

    private func formatEnumText(_ text: String) -> String {
        let spacedString = text.replacingOccurrences(
            of: "([A-Z])",
            with: " $1",
            options: .regularExpression,
            range: text.range(of: text)
        )
        return spacedString.capitalized
    }
}

struct CustomRoundedCorner: Shape {
    var radius: CGFloat
    var corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
