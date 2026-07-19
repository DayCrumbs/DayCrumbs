//
//  SessionE.swift
//  DayCrumbs
//
//  Created by Ibnu Taufick Ahraza on 7/15/26.
//

//
//  Sessions+UI.swift
//  DayCrumbs
//

import SwiftUI

// MARK: - UI Helpers untuk Enum Sessions
extension Sessions {
    
    var title: String {
        self.rawValue.capitalized
    }
    
    var imageName: String {
        switch self {
        case .morning: return "Session_Morning"
        case .afternoon: return "Session_Afternoon"
        case .evening: return "Session_Evening"
        case .night: return "Session_Night"
        }
    }
}
