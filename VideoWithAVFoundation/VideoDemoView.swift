//
//  VideoDemoView.swift
//  SwiftUIDemo3
//
//  Created by Itsuki on 2024/08/06.
//

import SwiftUI
import Combine

struct VideoDemoView: View {
    @State private var videoUrl: URL
    @StateObject private var videoModel: VideoModel = VideoModel()
    @State private var isLoading: Bool = false
    @State private var isSaving: Bool = false

    // controls
    @State private var isPlayingForward: Bool = false
    @State private var isPlayingBackward: Bool = false
    
    @State private var frameIndex: Double = 0.0
    @State private var timerPublisher = Timer.publish(every: .infinity, on: .main, in: .common)
    @State private var cancellable: (any Cancellable)? = nil
    
    var body: some View {
        VStack(spacing: 40) {
            
            if isLoading {
                videoModel.frames.last?.image?
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)

                Text("loading")
                ProgressView(value: videoModel.fractionProcessed, total: 1.0, label: {
                    Text("Loading...")
                }, currentValueLabel: {
                    Text("\(Int(videoModel.fractionProcessed * 100))%")
                })
                .progressViewStyle(.linear)

            } else {
                let frameCount = videoModel.frames.count
                if frameCount > 1 && Int(frameIndex) < frameCount  {
                    videoModel.frames[Int(frameIndex)].image?
                        .renderingMode(.original)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                    
                    if videoModel.modifiedFrames.count > 1 {
                        VStack {
                            Text("cropped")
                            videoModel.modifiedFrames[Int(frameIndex)].image?
                                .renderingMode(.original)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 100)
                        }
                    }
                    
                    VStack {
                        Slider(
                            value: $frameIndex,
                            in: 0...Double(frameCount-1),
                            step: 1.0)
                        
                        Text("frame: \(Int(frameIndex + 1))")
                    }
                    
                    HStack {
                        Button(action: {
                            if isPlayingBackward {
                                return
                            } else {
                                isPlayingBackward = true
                                fastPlay()
                            }
                        }, label: {
                            Image(systemName: "backward.fill")
                        })
                        .padding(.all, 16)
                        .foregroundStyle(.white)
                        .background(Circle().fill(.black))
                        
                        
                        
                        Button(action: {
                            if isPlayingBackward {
                                return
                            } else {
                                isPlayingBackward = true
                                play()
                            }
                        }, label: {
                            Image(systemName: "play.fill")
                                .scaleEffect(x: -1)
                        })
                        .padding(.all, 16)
                        .foregroundStyle(.white)
                        .background(Circle().fill(.black))
                        
                        
                        Button(action: {
                            if isPlayingForward || isPlayingBackward {
                                stopPlaying()
                            } else {
                                frameIndex = 0
                            }
                        }, label: {
                            Image(systemName: (isPlayingBackward||isPlayingForward) ? "pause.fill" : "arrow.counterclockwise")
                        })
                        .padding(.all, 16)
                        .foregroundStyle(.white)
                        .background(Circle().fill(.black))
                        

                        Button(action: {
                            if isPlayingForward {
                                return
                            } else {
                                isPlayingForward = true
                                play()
                            }
                        }, label: {
                            Image(systemName: "play.fill")
                        })
                        .padding(.all, 16)
                        .foregroundStyle(.white)
                        .background(Circle().fill(.black))
                        
                        Button(action: {
                            if isPlayingForward {
                                return
                            } else {
                                isPlayingForward = true
                                fastPlay()
                            }
                        }, label: {
                            Image(systemName: "forward.fill")
                        })
                        .padding(.all, 16)
                        .foregroundStyle(.white)
                        .background(Circle().fill(.black))
                        
                    }
                    
                    HStack {
                        Button(action: {
                            videoModel.cropSides()
                        }, label: {
                            Text(Image(systemName: "crop"))
                            + Text(" Crop Sides")
                        })
                        .padding(.all, 16)
                        .foregroundStyle(.white)
                        .background(RoundedRectangle(cornerRadius: 8).fill(.black))
                        

                        Button(action: {
                            isSaving = true
                            Task {
                                await videoModel.saveModifiedVideo()
                                DispatchQueue.main.async {
                                    isSaving = false
                                }
                            }
                        }, label: {
                            Text(Image(systemName: "arrow.down.to.line.compact"))
                            + Text(" Save")
                        })
                        .disabled(isSaving)
                        .padding(.all, 16)
                        .foregroundStyle(.white)
                        .background(RoundedRectangle(cornerRadius: 8).fill(isSaving ? .gray.opacity(0.8) : .black))


                    }
                }
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 64)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .task {
            isLoading = true
            await videoModel.loadVideo(videoUrl)
            isLoading = false
        }
        .onReceive(timerPublisher) { _ in
            updateIndex()
        }
        
    }
    
    
    private func play() {
        let interval = videoModel.videoManager.minFrameDuration ?? videoModel.defaultFrameDuration
        timerPublisher = Timer.publish(every: TimeInterval(interval), on: .main, in: .common)
        cancellable = timerPublisher.connect()
    }
    
    
    private func stopPlaying() {
        isPlayingForward = false
        isPlayingBackward = false
        cancellable?.cancel()
    }
    
    private func fastPlay() {
        let interval = (videoModel.videoManager.minFrameDuration ?? videoModel.defaultFrameDuration)/2
        timerPublisher = Timer.publish(every: TimeInterval(interval), on: .main, in: .common)
        cancellable = timerPublisher.connect()
    }

    private func updateIndex() {
        if isPlayingForward {
            guard Int(frameIndex) < videoModel.frames.count - 1 else {
                stopPlaying()
                return
            }
            frameIndex = frameIndex + 1
        }
        if isPlayingBackward {
            guard Int(frameIndex) > 0 else {
                stopPlaying()
                return
            }
            frameIndex = frameIndex - 1
        }
    }
    
}

extension VideoDemoView {
    init(url: URL) {
        self.videoUrl = url
    }
}

#Preview {
    let videoUrl = Bundle.main.url(forResource: "pikachu", withExtension: "mp4")
    if let url = videoUrl {
        return VideoDemoView(url: url)
    } else {
        return Color.red
    }
}
