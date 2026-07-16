//
//  TriggerAlertView.swift
//  DayCrumbs
//
//  Created by Ibnu Taufick Ahraza on 7/16/26.
//

import SwiftUI

// MARK: - Custom Trigger Alert View
struct TriggerAlertView: View {
    let detail: TriggerDetail
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            
            // 1. Judul
            Text(detail.title)
                .font(.system(.title2, design: .rounded).bold())
                .foregroundColor(AppColour.txtCoklat)
            
            // 2. Deskripsi LLM
            Text(detail.description)
                .font(.system(.body, design: .rounded))
                .foregroundColor(AppColour.txtCoklat)
                .multilineTextAlignment(.leading)
            
            // 3. Recommended Activities
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "lightbulb.fill")
                    Text("Recommended Activities")
                        .font(.system(.headline, design: .rounded).bold())
                }
                .foregroundColor(AppColour.txtCoklat)
                
                ForEach(detail.recommendedActivities, id: \.self) { activity in
                    Text("• \(activity)")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(AppColour.txtCoklat.opacity(0.8))
                }
            }
            
            // 4. What helps / prevents it
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "heart.circle") 
                    Text("What helps/prevents it")
                        .font(.system(.headline, design: .rounded).bold())
                }
                .foregroundColor(AppColour.txtCoklat)
                
                ForEach(detail.preventions, id: \.self) { prevention in
                    Text("• \(prevention)")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(AppColour.txtCoklat.opacity(0.8))
                }
            }
            
            // 5. Tombol Done
            Button(action: onDismiss) {
                Text("Done")
                    .font(.system(.headline, design: .rounded).bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppColour.btnKuning) // Menggunakan warna tema kita
                    .foregroundColor(AppColour.txtCoklat)
                    .clipShape(Capsule())
            }
            .padding(.top, 8)
        }
        .padding(24)
        .background(AppColour.bgPutih)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .frame(maxWidth: 400)
    }
}
