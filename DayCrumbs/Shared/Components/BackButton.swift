//
//  BackButton.swift
//  DayCrumbs
//
//  Created by Ibnu Taufick Ahraza on 7/15/26.
//

import SwiftUI

struct CircularBackButton: View {
    enum ButtonStyle {
        case yellowBtn
        case brownBtn
    }
    
    var style: ButtonStyle = .yellowBtn
    var action: () -> Void
    
    /// Keeps the shared button fill consistent across its visual styles.
    private var buttonColor: Color {
        switch style {
        case .yellowBtn:
            return AppColour.btnKuning
        case .brownBtn:
            return AppColour.btnCoklat .opacity(0.45)
        }
    }
    
    /// Keeps the decorative chevron legible against the selected fill.
    private var chevronColor: Color {
        switch style {
        case .yellowBtn:
            return AppColour.chevPutih
        case .brownBtn:
            return AppColour.chevPutih
        }
    }
    
    var body: some View {
        Button(action: {
            action()
        }) {
            Image(systemName: "chevron.left")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(chevronColor)
                .frame(width: 44, height: 44)
                .background(buttonColor)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                .accessibilityHidden(true)
        }
        .accessibilityLabel("Back")
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color.gray.opacity(0.2).ignoresSafeArea()
        
        VStack(spacing: 20) {            CircularBackButton(style: .yellowBtn, action: {
                print("Tombol kuning ditekan")
            })
            
            CircularBackButton(style: .brownBtn, action: {
                print("Tombol putih ditekan")
            })
        }
    }
}
