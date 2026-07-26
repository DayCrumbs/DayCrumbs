//
//  TriggerAlertView.swift
//  DayCrumbs
//
//  Created by Ibnu Taufick Ahraza on 7/16/26.
//

import SwiftUI

struct TriggerAlertView: View {
    let detail: TriggerDetail
    let onDismiss: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AccessibilityFocusState.Binding private var accessibilityFocus:
        DashboardAccessibilityFocus?

    init(
        detail: TriggerDetail,
        accessibilityFocus: AccessibilityFocusState<
            DashboardAccessibilityFocus?
        >.Binding,
        onDismiss: @escaping () -> Void
    ) {
        self.detail = detail
        self._accessibilityFocus = accessibilityFocus
        self.onDismiss = onDismiss
    }

    var body: some View {
            // VStack utama pembungkus keseluruhan alert
            VStack(spacing: 0) {
                
                // 1. Bagian konten yang bisa di-scroll
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text(detail.title)
                            .font(.system(.title2, design: .rounded).bold())
                            .foregroundColor(AppColour.txtCoklat)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityFocused(
                                $accessibilityFocus,
                                equals: .triggerDialogTitle
                            )

                        Text(detail.explanation)
                            .font(.system(.body, design: .rounded))
                            .foregroundColor(AppColour.txtCoklat)
                            .multilineTextAlignment(.leading)

                        if !detail.evidence.isEmpty {
                            evidenceSection
                        }

                        recommendationSection
                        whatMayHelpSection
                        sourceSection
                    }
                    .padding(24) // Padding untuk konten teks
                }

                // 2. Tombol Done di luar ScrollView agar sticky di bawah
                VStack {
                    Button(action: onDismiss) {
                        Text("Done")
                            .font(.system(.headline, design: .rounded).bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                AppColour.btnKuning
                                    .accessibilityHidden(true)
                            )
                            .foregroundColor(AppColour.txtCoklat)
                            .clipShape(Capsule())
                    }
                    .accessibilityLabel("Done")
                    .accessibilityHint("Closes trigger details.")
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .padding(.top, 8)
                // Latar belakang area tombol dibuat sama dengan background modal
                .background(AppColour.bgPutih)
            }
            // Modifier untuk bentuk modal dipindah ke VStack terluar
            .background(AppColour.bgPutih.accessibilityHidden(true))
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .frame(
                maxWidth: dynamicTypeSize.isAccessibilitySize ? 680 : 440,
                maxHeight: dynamicTypeSize.isAccessibilitySize ? .infinity : 680
            )
            .padding(dynamicTypeSize.isAccessibilitySize ? 24 : 0)
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
        }

    private var evidenceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(
                title: detail.sectionLabels.evidence,
                systemImage: "list.bullet.clipboard"
            )

            ForEach(detail.evidence.indices, id: \.self) { index in
                let evidence = detail.evidence[index]

                VStack(alignment: .leading, spacing: 4) {
                    Text(evidence.title)
                        .font(.system(.subheadline, design: .rounded).bold())
                    Text(evidence.explanation)
                        .font(.system(.subheadline, design: .rounded))

                    if !evidence.contextTags.isEmpty {
                        Text(evidence.contextTags.joined(separator: " • "))
                            .font(.system(.caption, design: .rounded))
                            .foregroundColor(AppColour.txtCoklat.opacity(0.65))
                    }
                }
                .foregroundColor(AppColour.txtCoklat.opacity(0.8))
            }
        }
    }

    private var recommendationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(
                title: detail.sectionLabels.recommendedActivities,
                systemImage: "lightbulb.fill"
            )

            Text(detail.recommendationTitle)
                .font(.system(.subheadline, design: .rounded).bold())
                .foregroundColor(AppColour.txtCoklat)

            ForEach(detail.recommendedActivities, id: \.self) { activity in
                bullet(activity)
            }
        }
    }

    private var whatMayHelpSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(
                title: detail.sectionLabels.whatMayHelp,
                systemImage: "heart.circle"
            )

            ForEach(detail.whatMayHelp, id: \.self) { suggestion in
                bullet(suggestion)
            }
        }
    }

    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(detail.sectionLabels.curatedSources)
                .font(.system(.caption, design: .rounded).bold())
                .foregroundColor(AppColour.txtCoklat.opacity(0.7))
                .accessibilityAddTraits(.isHeader)

            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 8) {
                        sourceLabels
                    }
                } else {
                    HStack(spacing: 8) {
                        sourceLabels
                    }
                }
            }
            .foregroundColor(AppColour.txtCoklat)
        }
    }

    @ViewBuilder
    private var sourceLabels: some View {
                ForEach(detail.sourceLabels, id: \.self) { source in
                    Text(source.rawValue)
                        .font(.system(.caption, design: .rounded).bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            AppColour.btnKuning
                                .opacity(0.25)
                                .accessibilityHidden(true)
                        )
                        .clipShape(Capsule())
                        .accessibilityLabel(source.rawValue)
                }
    }

    private func sectionHeader(title: String, systemImage: String) -> some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: systemImage)
                .accessibilityHidden(true)
        }
            .font(.system(.headline, design: .rounded).bold())
            .foregroundColor(AppColour.txtCoklat)
            .accessibilityLabel(title)
            .accessibilityAddTraits(.isHeader)
    }

    private func bullet(_ text: String) -> some View {
        Text("• \(text)")
            .font(.system(.subheadline, design: .rounded))
            .foregroundColor(AppColour.txtCoklat.opacity(0.8))
    }
}
