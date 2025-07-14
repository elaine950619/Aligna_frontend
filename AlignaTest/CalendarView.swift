//
//  CalendarView.swift
//  
//
//  Created by Elaine Hsieh on 6/29/25.
//
import SwiftUI
import UIKit

struct CalendarView: UIViewRepresentable {
    @Binding var selectedDate: Date
    
    /// Accent for the selected day circle + chevrons
    var accentColor: UIColor = .systemPurple
    
    /// Card colour; secondarySystemBackground ≈ the screenshot’s light grey-white
    var cardColor: UIColor = .secondarySystemBackground
    
    func makeUIView(context: Context) -> UIView {
        // 1. Card container
        let card = UIView()
        card.backgroundColor = cardColor
        card.layer.cornerRadius = 20
        card.layer.shadowColor = UIColor.black.cgColor       // ◄ subtle “lift”
        card.layer.shadowOpacity = 0.08
        card.layer.shadowOffset = .init(width: 0, height: 3)
        card.layer.shadowRadius = 6
        
        // 2. UIDatePicker
        let picker = UIDatePicker()
        picker.datePickerMode = .date
        picker.preferredDatePickerStyle = .inline
        picker.maximumDate = Date()
        picker.tintColor = accentColor                       // ◄ purple selection
        picker.backgroundColor = .clear                      // let card show through
        
        picker.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(picker)
        NSLayoutConstraint.activate([
            picker.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 8),
            picker.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -8),
            picker.topAnchor.constraint(equalTo: card.topAnchor, constant: 8),
            picker.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -8)
        ])
        
        picker.addTarget(context.coordinator,
                         action: #selector(Coordinator.dateChanged(_:)),
                         for: .valueChanged)
        
        return card
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let picker = uiView.subviews.compactMap({ $0 as? UIDatePicker }).first {
            picker.date = selectedDate
        }
    }
    
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    
    class Coordinator: NSObject {
        var parent: CalendarView
        init(_ parent: CalendarView) { self.parent = parent }
        @objc func dateChanged(_ sender: UIDatePicker) {
            parent.selectedDate = sender.date
        }
    }
}
