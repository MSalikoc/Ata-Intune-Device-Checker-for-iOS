//
//  ModernButton.swift
//  intunedevice
//
//  Created by cyberwise on 14.01.2025.
//


import SwiftUI

struct ModernButton: View {
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity)
                .padding()
                .background(color)
                .foregroundColor(.white)
                .cornerRadius(8)
        }
    }
}