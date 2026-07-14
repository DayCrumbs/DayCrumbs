import SwiftUI

struct ChildProfileSetupView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var childName: String = ""
    @State private var childAge: String = ""
    @State private var selectedGender: Gender? = nil
    
    enum Gender {
        case boy, girl
    }
    
    let bgColour = Color("PutihDayCrumbs")
    let btnColour = Color("KuningDayCrumbs")
    let txtColour = Color("CoklatDayCrumbs")
    let cardColour = Color("KuningDayCrumbs")
    let primaryBtnColour = Color("PutihDayCrumbs")

    
    var body: some View {
        ZStack {
            bgColour
                .ignoresSafeArea()
            
            VStack {
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(btnColour)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
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
                        .foregroundColor(txtColour)
                    
                    // Card Form
                    VStack(spacing: 24) {
                        
                        // Baris 1: Name
                        HStack {
                            Text("Name")
                                .font(.system(.title3, design: .rounded))
                                .foregroundColor(txtColour)
                                .frame(width: 80, alignment: .leading)
                            
                            TextField("Placeholder", text: $childName)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color.white.opacity(0.3))
                                .cornerRadius(16)
                                .foregroundColor(txtColour)
                        }
                        
                        // Baris 2: Age
                        HStack {
                            Text("Age")
                                .font(.system(.title3, design: .rounded))
                                .foregroundColor(txtColour)
                                .frame(width: 80, alignment: .leading)
                            
                            TextField("Placeholder", text: $childAge)
                                .keyboardType(.numberPad)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color.white.opacity(0.3))
                                .cornerRadius(16)
                                .foregroundColor(txtColour)
                        }
                        
                        // Baris 3: Gender
                        HStack {
                            Text("Gender")
                                .font(.system(.title3, design: .rounded))
                                .foregroundColor(txtColour)
                                .frame(width: 80, alignment: .leading)
                            
                            HStack(spacing: 16) {
                                genderButton(title: "Boy", type: .boy)
                                genderButton(title: "Girl", type: .girl)
                            }
                        }
                        
                        // Baris 4: Save Button
                        Button(action: {
                            print("Save ditekan: \(childName), \(childAge), Gender: \(String(describing: selectedGender))")
                            // TODO: Panggil fungsi ViewModel/Database di sini nantinya
                        }) {
                            Text("Save Profile")
                                .font(.system(.title3, design: .rounded).weight(.bold))
                                .foregroundColor(txtColour)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(primaryBtnColour)
                                .clipShape(Capsule())
                        }
                        .padding(.top, 8)
                        
                    }
                    .padding(32)
                    .background(cardColour)
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
    private func genderButton(title: String, type: Gender) -> some View {
        let isSelected = selectedGender == type
        
        Button(action: {
            selectedGender = type
        }) {
            Text(title)
                .font(.system(.body, design: .rounded))
                .foregroundColor(txtColour)
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
