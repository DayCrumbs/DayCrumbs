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
        case whiteBtn
    }
    
    var style: ButtonStyle = .yellowBtn
    var action: () -> Void
    
    // 3. Computed property untuk warna background
    private var btnColour: Color {
        switch style {
        case .yellowBtn:
            return AppColour.btnKuning
        case .whiteBtn:
            return AppColour.btnPutih
        }
    }
    
    // 4. Computed property untuk warna chevron (ikon)
    private var chevronColor: Color {
        switch style {
        case .yellowBtn:
            return AppColour.chevPutih
        case .whiteBtn:
            return AppColour.chevKuning
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
                .background(btnColour)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color.gray.opacity(0.2).ignoresSafeArea()
        
        VStack(spacing: 20) {            CircularBackButton(style: .yellowBtn, action: {
                print("Tombol kuning ditekan")
            })
            
            CircularBackButton(style: .whiteBtn, action: {
                print("Tombol putih ditekan")
            })
        }
    }
}
