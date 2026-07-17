//
//  PickMoodView.swift
//  DayCrumbs
//
//  Created by Ibnu Taufick Ahraza on 7/17/26.
//

import SwiftUI

struct PickMoodView: View {
    @Environment(\.dismiss) private var dismiss

    let selectedPlace: Place.BuiltInPlace
    let selectedActivity: Activity.BuiltInActivity
    @State private var selectedMood: Moods?

    private let moodOptions: [MoodOption] = [
        MoodOption(mood: .disgust, imageName: "ExpressionDisgustFace_Girl"),
        MoodOption(mood: .sad, imageName: "ExpressionSadFace_Girl"),
        MoodOption(mood: .angry, imageName: "ExpressionAngryFace_Girl"),
        MoodOption(mood: .surprise, imageName: "ExpressionSurpriseFace_Girl"),
        MoodOption(mood: .fear, imageName: "ExpressionFearFace_Girl"),
        MoodOption(mood: .happy, imageName: "ExpressionHappyFace_Girl")
    ]

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                Color.white
                    .ignoresSafeArea()

                HStack(spacing: 0) {
                    CharacterMoodHero()
                        .frame(width: proxy.size.width * 0.46)

                    VStack(spacing: 0) {
                        moodHeader
                            .padding(.top, proxy.size.height * 0.10)
                            .padding(.trailing, proxy.size.width * 0.03)

                        Spacer(minLength: proxy.size.height * 0.05)

                        moodGrid
                            .padding(.trailing, proxy.size.width * 0.05)

                        Text("Hold any emotion to learn more about it")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundColor(AppColour.txtCoklat.opacity(0.9))
                            .padding(.top, 30)
                            .padding(.bottom, 24)
                    }
                    .frame(width: proxy.size.width * 0.54, height: proxy.size.height)
                }

                CircularBackButton(style: .yellowBtn) {
                    dismiss()
                }
                .padding(.top, 24)
                .padding(.leading, 32)
            }
        }
        .navigationBarBackButtonHidden(true)
    }

    private var moodHeader: some View {
        ZStack {
            BubbleMessage(
                title: "How did you feel when you \(activityPastTense(selectedActivity))?",
                subtitle: "Pick a face that looks like how you felt."
            )
        }
    }

    private var moodGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 18),
                GridItem(.flexible(), spacing: 18),
                GridItem(.flexible(), spacing: 18)
            ],
            spacing: 22
        ) {
            ForEach(moodOptions) { option in
                Button {
                    selectedMood = option.mood
                } label: {
                    VStack(spacing: 10) {
                        Image(option.imageName)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 78)

                        Text(option.mood.rawValue.capitalized)
                            .font(.system(.headline, design: .rounded).weight(.semibold))
                            .foregroundColor(AppColour.txtCoklat)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
    }

    private func activityPastTense(_ activity: Activity.BuiltInActivity) -> String {
        switch activity {
        case .play:
            return "played"
        case .sleep:
            return "slept"
        case .study:
            return "studied"
        case .eat:
            return "ate"
        case .getReady:
            return "got ready"
        case .wakeUp:
            return "woke up"
        }
    }
}

private struct CharacterMoodHero: View {
    var body: some View {
        GeometryReader { proxy in
            Image("PickMood_Girl")
                .resizable()
                .scaledToFit()
                .frame(width: proxy.size.width * 1.18)
                .offset(x: -proxy.size.width * 0.08, y: proxy.size.height * 0.03)
        }
    }
}

private struct BubbleMessage: View {
    let title: String
    let subtitle: String

    var body: some View {
        Image("BubbleAsset")
            .resizable()
            .scaledToFit()
            .overlay(alignment: .center) {
                VStack(spacing: 10) {
                    Text(title)
                        .font(.system(size: 32, design: .rounded).weight(.bold))
                        .foregroundColor(AppColour.txtCoklat)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.65)
                        .lineLimit(2)

                    Text(subtitle)
                        .font(.system(size: 20, design: .rounded))
                        .foregroundColor(AppColour.txtCoklat)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.7)
                        .lineLimit(2)
                }
                .padding(.horizontal, 44)
                .padding(.vertical, 18)
                .offset(y: -6)
            }
            .frame(maxWidth: .infinity)
            .padding(.trailing, 12)
    }
}

private struct MoodOption: Identifiable {
    let id = UUID()
    let mood: Moods
    let imageName: String
}

#Preview {
    PickMoodView(selectedPlace: .house, selectedActivity: .study)
}
