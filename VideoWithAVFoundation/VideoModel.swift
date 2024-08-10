//
//  VideoModel.swift
//  SwiftUIDemo3
//
//  Created by Itsuki on 2024/08/07.
//

import SwiftUI

class VideoModel: ObservableObject {
    var videoManager: VideoManager = VideoManager()
    var photoManager: PhotoLibraryManager = PhotoLibraryManager()
    
    let defaultFrameDuration = 0.04

    @Published var frames: [CGImage] = []
    
    @Published var modifiedFrames: [CGImage] = []
    
    var fractionProcessed: Double {
        guard let totalDuration = videoManager.duration, let frameDuration = videoManager.minFrameDuration else {return 0}
        return min(frameDuration*Double(frames.count)/totalDuration, 1.0)
    }
    
    func cropSides() {
        var newCgImages: [CGImage] = []
        for cgImage in frames {
            let currentHeight = cgImage.height
            let currentWidth = cgImage.width
            let origin = CGPoint(x: currentWidth/4, y: currentHeight/4)
            let size = CGSize(width: currentWidth/2, height: currentHeight/2)
            guard let halvedImage = cgImage.cropping(to: CGRect(origin: origin, size: size)) else {continue}
            newCgImages.append(halvedImage)
        }

        self.modifiedFrames = newCgImages
    }


    func loadVideo(_ url: URL) async {
        DispatchQueue.main.async {
            self.frames = []
        }

        let success = await videoManager.loadVideo(url)
        print("load success: \(success)")
        print("video duration: \(videoManager.duration ?? 0)")

        if !success {
            return
        }

        while true {
            guard let frameImage = videoManager.getNextFrame() else {
                break
            }
            DispatchQueue.main.async {
                self.frames.append(frameImage)
            }
        }
        print("loading finishes: total frame: \(self.frames.count)")

    }
    
    func saveModifiedVideo() async {
        guard modifiedFrames.count > 0 else {
            print("nothing modified")
            return
        }
        
        guard
            let directoryPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        else {
            print("Cannot access local file domain")
            return
        }

        let fileName = "modified"
        let fileUrl = directoryPath
            .appendingPathComponent(fileName)
            .appendingPathExtension("mp4")
        
        if FileManager.default.fileExists(atPath: fileUrl.absoluteString) {
            try? FileManager.default.removeItem(at: fileUrl)
        }

        let success: Bool = await withCheckedContinuation { continuation in
            videoManager.createVideo(self.modifiedFrames, at: fileUrl) { success in
                continuation.resume(returning: success)
            }
        }
        
        if success {
            print("saving to photo library")
            await photoManager.saveVideo(fileUrl)
        }
        
        try? FileManager.default.removeItem(at: fileUrl)

    }
    
}
