//
//  SessionOptionView.swift
//  DayCrumbs
//
//  Created by Ibnu Taufick Ahraza on 7/15/26.
//

import SwiftUI

struct SessionOptionView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // 1. Grid Background 2x2
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    sessionCard(for: .morning)
                    sessionCard(for: .afternoon)
                }
                HStack(spacing: 0) {
                    sessionCard(for: .evening)
                    sessionCard(for: .night)
                }
            }
            .ignoresSafeArea()
            
            // 2. Tombol Back di Kiri Atas
            VStack {
                HStack {
                    CircularBackButton(style: .whiteBtn) {
                    dismiss()
                }
                    Spacer()
                }
                .padding(.top, 24)
                .padding(.leading, 32)
                
                Spacer()
            }
            
            // 3. Label "Choose Which Session" di Bawah Tengah
            VStack {
                Spacer()
                
                Text("Choose Which Session....")
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(.black)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(.regularMaterial)
                    .clipShape(Capsule())
                    .padding(.bottom, 40)
            }
        }
        .navigationBarBackButtonHidden(true)
    }
    
    // MARK: - Komponen Kuadran Grid
    @ViewBuilder
    private func sessionCard(for session: Sessions) -> some View {
        Button(action: {
            print("Sesi dipilih: \(session.title)")
        }) {
            ZStack {
                session.backgroundColour
                
//                Kalo sudah ada ilustrasinya hapus comment dan hapus session.backgroundColor di atas
//                Image(session.imageName)
//                    .resizable()
//                    .scaledToFill()
//                    .frame(maxWidth: .infinity, maxHeight: .infinity)
//                    .clipped()
                
                VStack {
                    HStack {
                        if session == .morning || session == .evening {
                            Spacer()
                        }
                        
                        HStack(spacing: 8) {
                            if session == .morning || session == .evening {
                                Text(session.title)
                                Image(systemName: session.iconName)
                            } else {
                                Image(systemName: session.iconName)
                                Text(session.title)
                            }
                        }
                        .font(.system(.title3, design: .rounded).weight(.medium))
                        .foregroundColor(session.textColour)
                        
                        if session == .afternoon || session == .night {
                            Spacer()
                        }
                    }
                    .padding(40)
                    
                    Spacer()
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    SessionOptionView()
}
