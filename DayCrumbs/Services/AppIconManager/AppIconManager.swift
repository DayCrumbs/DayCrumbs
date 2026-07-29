//
//  AppIconManager.swift
//  DayCrumbs
//
//  Created by Ibnu Taufick Ahraza on 7/29/26.
//

import UIKit

@MainActor
enum AppIconManager {

    static func updateIcon(isBoy: Bool) {
        guard UIApplication.shared.supportsAlternateIcons else {
            print("Alternate app icon tidak didukung.")
            return
        }

        // nil = icon default, yaitu IconBoy
        let iconName: String? = isBoy ? nil : "IconGirl"

        guard UIApplication.shared.alternateIconName != iconName else {
            return
        }

        UIApplication.shared.setAlternateIconName(iconName) { error in
            if let error {
                print("Gagal mengganti app icon: \(error.localizedDescription)")
            } else {
                print("App icon berhasil diganti.")
            }
        }
    }
}
