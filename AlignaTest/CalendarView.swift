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
    var backgroundColor: UIColor = UIColor.systemBackground  // customize this as needed

    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = .clear // container view is transparent

        let picker = UIDatePicker()
        picker.datePickerMode = .date
        picker.preferredDatePickerStyle = .inline // or `.wheels`, `.compact`
//        picker.overrideUserInterfaceStyle = .light

        // 👉 Set background color for the picker itself
        picker.backgroundColor = backgroundColor
        picker.layer.cornerRadius = 12
        picker.clipsToBounds = true
        picker.maximumDate = Date()

        // Add picker to container
        picker.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(picker)

        NSLayoutConstraint.activate([
            picker.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            picker.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            picker.topAnchor.constraint(equalTo: containerView.topAnchor),
            picker.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])

        // Hook up delegate
        picker.addTarget(context.coordinator, action: #selector(Coordinator.dateChanged(_:)), for: .valueChanged)

        return containerView
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let picker = uiView.subviews.compactMap({ $0 as? UIDatePicker }).first {
            picker.date = selectedDate
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject {
        var parent: CalendarView

        init(_ parent: CalendarView) {
            self.parent = parent
        }

        @objc func dateChanged(_ sender: UIDatePicker) {
            parent.selectedDate = sender.date
        }
    }
}
