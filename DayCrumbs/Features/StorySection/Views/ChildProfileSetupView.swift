import SwiftUI

struct ChildProfileSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = ChildProfileSetupViewModel()
    
    
    var body: some View {
        ZStack {
            AppColour.bgPutih
                .ignoresSafeArea()
            
            VStack {
                HStack {
                    CircularBackButton() {
                        dismiss()
                    }
                    Spacer()
                }
                .padding(.top, 24)
                .padding(.leading, 32)
                
                Spacer()
            }
            
            HStack(spacing: 200) {
                
                Image("IconAnakCewe")
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 500)
                
                
                
                // --- KANAN: FORM ---
                VStack(alignment: .leading, spacing: 24) {
                    
                    Text("Set Up Your Child's Profile")
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        .foregroundColor(AppColour.txtCoklat)
                    
                    // Card Form
                    VStack(spacing: 24) {
                        
                        // Baris 1: Name
                        HStack {
                            Text("Name")
                                .font(.system(.title3, design: .rounded))
                                .foregroundColor(AppColour.txtCoklat)
                                .frame(width: 80, alignment: .leading)
                            
                            TextField("Placeholder", text: $viewModel.childName)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color.white.opacity(0.3))
                                .cornerRadius(16)
                                .foregroundColor(AppColour.txtCoklat)
                        }
                        
                        // Baris 2: Age
                        HStack {
                            Text("Age")
                                .font(.system(.title3, design: .rounded))
                                .foregroundColor(AppColour.txtCoklat)
                                .frame(width: 80, alignment: .leading)
                            
                            TextField("Placeholder", text: $viewModel.childAge)
                                .keyboardType(.numberPad)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color.white.opacity(0.3))
                                .cornerRadius(16)
                                .foregroundColor(AppColour.txtCoklat)
                        }
                        
                        // Baris 3: Gender
                        HStack {
                            Text("Gender")
                                .font(.system(.title3, design: .rounded))
                                .foregroundColor(AppColour.txtCoklat)
                                .frame(width: 80, alignment: .leading)
                            
                            HStack(spacing: 16) {
                                ForEach(ChildGender.allCases, id: \.self) { gender in
                                    genderButton(for: gender)
                                }
                            }
                        }
                        
                        // Baris 4: Save Button
                        Button(action: {
                            viewModel.saveProfile()
                        }) {
                            Text("Save Profile")
                                .font(.system(.title3, design: .rounded).weight(.bold))
                                .foregroundColor(AppColour.txtCoklat)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(AppColour.btnPutih)
                                .clipShape(Capsule())
                        }
                        .padding(.top, 8)
                        
                    }
                    .padding(32)
                    .background(AppColour.cardKuning)
                    .cornerRadius(24)
                    
                }
                .frame(maxWidth: 500)
            }
            .padding(.horizontal, 40)
        }
        .navigationBarBackButtonHidden(true)
    }
    
    // MARK: - Komponen Bantuan
    @ViewBuilder
    private func genderButton(for gender: ChildGender) -> some View {
        let isSelected = viewModel.selectedGender == gender
        
        Button(action: {
            viewModel.selectedGender = gender
        }) {
            Text(gender.rawValue.capitalized)
                .font(.system(.body, design: .rounded))
                .foregroundColor(AppColour.txtCoklat)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isSelected ? Color.white.opacity(0.6) : Color.clear)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.white, lineWidth: 1.5)
                )
        }
    }
}

#Preview {
    ChildProfileSetupView()
}
