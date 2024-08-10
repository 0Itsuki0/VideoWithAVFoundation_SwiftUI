//
//  SwiftUIDemo3App.swift
//  SwiftUIDemo3
//
//  Created by Itsuki on 2024/08/06.
//

import SwiftUI

@main
struct MediaReadingDemoApp: App {
    var body: some Scene {
        WindowGroup {
//            ProgressViewDemo()
            let videoUrl = Bundle.main.url(forResource: "pikachu", withExtension: "mp4")
            if let url = videoUrl {
                VideoDemoView(url: url)
            } else {
                VStack {
                    Text("Oops URL Not found!")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
    }
}
