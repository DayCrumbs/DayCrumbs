import SwiftUI

struct SelectionSlider<T: Hashable>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let title: String
    let items: [T]
    @Binding var selectedItem: T?

    let itemName: (T) -> String
    let onAddCustom: () -> Void
    var onSelectItem: ((T) -> Void)? = nil
    var itemImageName: ((T) -> String?)? = nil
    var itemImageNames: ((T) -> [String])? = nil

    @ScaledMetric(relativeTo: .title3) private var preferredTitleSize: CGFloat = 22
    @ScaledMetric(relativeTo: .headline) private var preferredOptionSize: CGFloat = 17

    var body: some View {
        VStack(spacing: dynamicTypeSize.isAccessibilitySize ? 14 : 20) {
            Text(title)
                .font(
                    .system(
                        size: min(30, max(18, preferredTitleSize)),
                        design: .rounded
                    )
                )
                .foregroundColor(AppColour.txtCoklat)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 24)
                .accessibilityAddTraits(.isHeader)

            GeometryReader { proxy in
                // Navigation transitions can briefly propose invalid or zero geometry.
                // Clamp it before deriving dimensions passed to CoreGraphics.
                let availableWidth = finitePositive(proxy.size.width)
                let horizontalPadding = availableWidth * 0.05
                let cardSpacing = availableWidth * 0.045
                let visibleCardCount: CGFloat =
                    dynamicTypeSize.isAccessibilitySize && availableWidth < 700
                        ? 2
                        : 4
                let cardWidth = max(
                    1,
                    (
                        availableWidth
                            - (horizontalPadding * 2)
                            - (cardSpacing * (visibleCardCount - 1))
                    )
                        / visibleCardCount
                )
                let cardHeight = cardWidth * 0.52

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: cardSpacing) {
                        ForEach(items, id: \.self) { item in
                            optionCard(for: item, width: cardWidth, height: cardHeight)
                        }

//                        DI COMMENT DULU SAJA SOALNYA BARU BAKAL DIBUAT AFTER MVP
//                        Button(action: onAddCustom) {
//                            VStack(spacing: 6) {
//                                RoundedRectangle(cornerRadius: 2)
//                                    .fill(AppColour.cardKuning)
//                                    .frame(width: cardWidth, height: cardHeight)
//                                    .overlay {
//                                        Image(systemName: "plus")
//                                            .font(.system(size: cardHeight * 0.28, weight: .bold))
//                                            .foregroundColor(AppColour.txtCoklat)
//                                    }
//
//                                Text("Add Custom")
//                                    .font(.system(.headline, design: .rounded).weight(.semibold))
//                                    .foregroundColor(AppColour.txtCoklat)
//                                    .lineLimit(1)
//                            }
//                            .frame(width: cardWidth)
//                        }
//                        .buttonStyle(.plain)
//                        .accessibilityLabel("Add custom option")
//                        .accessibilityHint("Creates a custom option for this selection.")
                    }
                    .padding(.horizontal, horizontalPadding)
                }
                .accessibilityElement(children: .contain)
            }
            .frame(maxHeight: .infinity)
        }
        .padding(.top, 18)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: 26,
                topTrailingRadius: 26
            )
                .fill(AppColour.bgPutih)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    @ViewBuilder
    private func optionCard(for item: T, width: CGFloat, height: CGFloat) -> some View {
        Button(action: {
            selectedItem = item
            onSelectItem?(item)
        }) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 30)
                        .fill(AppColour.cardKuning.opacity(selectedItem == item ? 1.0 : 0.72))

                    if let imageNames = itemImageNames?(item), !imageNames.isEmpty {
                        ZStack {
                            ForEach(
                                Array(imageNames.enumerated()),
                                id: \.offset
                            ) { _, imageName in
                                Image(imageName)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(
                                        width: width,
                                        height: height,
                                        alignment: .bottom
                                    )
                            }
                        }
                        .frame(width: width, height: height)
                        .clipShape(RoundedRectangle(cornerRadius: 30))
                        .accessibilityHidden(true)
                    } else if let imageName = itemImageName?(item), !imageName.isEmpty {
                        Image(imageName)
                            .resizable()
                            .scaledToFill()
                            .frame(width: width, height: height)
                            .clipShape(RoundedRectangle(cornerRadius: 30))
                            .accessibilityHidden(true)
                    }
                }
                .frame(width: width, height: height)

                Text(formatEnumText(itemName(item)))
                    .font(
                        .system(
                            size: min(24, max(16, preferredOptionSize)),
                            design: .rounded
                        )
                        .weight(.semibold)
                    )
                    .foregroundColor(AppColour.txtCoklat)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: width)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(formatEnumText(itemName(item)))
        .accessibilityHint(
            selectedItem == item
                ? "This option is selected."
                : "Selects this option and continues."
        )
        .accessibilityAddTraits(
            selectedItem == item ? .isSelected : []
        )
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

    private func finitePositive(_ value: CGFloat) -> CGFloat {
        guard value.isFinite, value > 0 else {
            return 1
        }
        return value
    }
}
