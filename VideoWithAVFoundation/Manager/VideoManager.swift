//
//  VideoManager.swift
//  SwiftUIDemo3
//
//  Created by Itsuki on 2024/08/06.
//

import SwiftUI
import AVFoundation

class VideoManager {
    
    // MARK: For reading video
    private var videoAsset: AVAsset?
    private var videoTrack: AVAssetTrack?
    private var assetReader: AVAssetReader?
    private var videoAssetReaderOutput: AVAssetReaderTrackOutput?
    
    
    // MARK: For writing video
    private let writerQueue = DispatchQueue(label: "mediaInputQueue")

    
    // MARK: video properties
    // frames per second
    var frameRate: Float32?
    
    // Indicates the minimum duration of the track's frames
    var minFrameDuration: Float64? {
        if let cmMinFrameDuration = cmMinFrameDuration {
            return CMTimeGetSeconds(cmMinFrameDuration)
        }
        return nil
    }
    var cmMinFrameDuration: CMTime?
    
    // Provides access to an array of AVMetadataItems for all metadata identifiers for which a value is available
    var metadata: [AVMetadataItem]?
    
    // transform specified in the track's storage container as the preferred transformation of the visual media data for display purposes: Value returned is often but not always `.identity`
    var affineTransform: CGAffineTransform!
    
    var duration: Float64?
    
    var orientation: CGImagePropertyOrientation {
        if let affineTransform = self.affineTransform {
            let angleInDegrees = atan2(affineTransform.b, affineTransform.a) * CGFloat(180) / CGFloat.pi
            var orientation: UInt32 = 1
            switch angleInDegrees {
            case 0:
                orientation = 1 // Recording button is on the right
            case 180:
                orientation = 3 // abs(180) degree rotation recording button is on the right
            case -180:
                orientation = 3 // abs(180) degree rotation recording button is on the right
            case 90:
                orientation = 8 // 90 degree CW rotation recording button is on the top
            case -90:
                orientation = 6 // 90 degree CCW rotation recording button is on the bottom
            default:
                orientation = 1
            }
            
            return CGImagePropertyOrientation(rawValue: orientation)!
        }
        return CGImagePropertyOrientation.up
    }

    
    // MARK: Functions For reading video from URL
    func loadVideo(_ url: URL) async -> Bool {
        self.videoAsset = AVAsset(url: url)
        let tracks = try? await self.videoAsset?.loadTracks(withMediaType: AVMediaType.video)
        
        if let videoTrack = tracks?.first {
            self.videoTrack = videoTrack
            do {
                let (affineTransform, metadata, cmMinFrameDuration, frameRate) = try await self.videoTrack!.load(.preferredTransform, .metadata, .minFrameDuration, .nominalFrameRate)
                self.affineTransform = affineTransform
                self.metadata = metadata
                self.cmMinFrameDuration = cmMinFrameDuration
                self.frameRate = frameRate
                let duration = try await self.videoAsset!.load(.duration)
                self.duration = CMTimeGetSeconds(duration)
                
            } catch (let error) {
                
                print("error loading data: \(error.localizedDescription)")
                return false
                
            }

        } else {
            return false
        }
        
        return self.readAsset()
    }
    
    
    private func readAsset() -> Bool {
        guard self.videoAsset != nil, self.videoTrack != nil else {
            print("nil video reader output")
            return false
        }
        
        do {
            self.assetReader = try AVAssetReader(asset: videoAsset!)
        } catch {
            print("Failed to create AVAssetReader object: \(error)")
            return false
        }
        
        self.videoAssetReaderOutput = AVAssetReaderTrackOutput(track: videoTrack!, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange])
        guard self.videoAssetReaderOutput != nil else {
            print("nil video reader output")
            return false
        }

        self.videoAssetReaderOutput!.alwaysCopiesSampleData = true
        guard self.assetReader!.canAdd(videoAssetReaderOutput!) else {
            print("cannot add output")
            return false
        }
        
        self.assetReader!.add(videoAssetReaderOutput!)
        return self.assetReader!.startReading()
    }
    

    func getNextFrame() -> CGImage? {
        guard self.videoAssetReaderOutput != nil else { return nil }
        guard let sampleBuffer = self.videoAssetReaderOutput!.copyNextSampleBuffer(), let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return nil
        }
        return CIImage(cvImageBuffer: imageBuffer).transformed(by: self.affineTransform ?? .identity).cgImage
    }
    
    
    
    // MARK: Functions For creating video from image
    func createVideo(_ frames: [CGImage], at fileUrl: URL, completion: ((Bool)->Void)?) {
        guard let frameDuration = self.cmMinFrameDuration else {
            print("frame duration not defined")
            completion?(false)
            return
        }
        guard let width = frames.first?.width, let height = frames.first?.height else {
            print("width and height not found")
            completion?(false)
            return
        }
        
        let avOutputSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: NSNumber(value: Float(width)),
            AVVideoHeightKey: NSNumber(value: Float(height))
        ]

        guard let assetWriter = try? AVAssetWriter(outputURL: fileUrl, fileType: AVFileType.mp4) else {
            print("AVAssetWriter creation failed")
            completion?(false)
            return
        }

        guard assetWriter.canApply(outputSettings: avOutputSettings, forMediaType: AVMediaType.video) else {
            print("Cannot apply output setting.")
            completion?(false)
            return
        }
        
        let assetWriterInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: avOutputSettings)

        guard assetWriter.canAdd(assetWriterInput) else {
            print("cannot add writer input")
            completion?(false)
            return
        }
        assetWriter.add(assetWriterInput)
        
        // The pixel buffer adaptor must be created before writing
        let sourcePixelBufferAttributesDictionary = [
            kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange),
            kCVPixelBufferWidthKey as String: NSNumber(value: Float(width)),
            kCVPixelBufferHeightKey as String: NSNumber(value: Float(height))
        ]
        let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: assetWriterInput,
            sourcePixelBufferAttributes: sourcePixelBufferAttributesDictionary
        )
        
        Thread.sleep(forTimeInterval: 0.2)
        
        guard assetWriter.startWriting() else {
            print("cannot starting writing with error: \(assetWriter.error?.localizedDescription ?? "Unknown error")")
            completion?(false)
            return
        }
        
        // start writing session
        assetWriter.startSession(atSourceTime: CMTime.zero)
        
        var frameCount = 0
        var frameBuffers = frames.map { $0.cvPixelBuffer }
        
        // write buffer
        assetWriterInput.requestMediaDataWhenReady(on: writerQueue) {
            while !frameBuffers.isEmpty {
                if assetWriterInput.isReadyForMoreMediaData == false {
                    // break out of the loop.
                    // frameBuffers.isEmpty == false and the escaping block will be called again when ready
                    print("more buffers need to be written.")
                    break
                }
                
                guard let buffer = frameBuffers.removeFirst() else {
                    print("nil buffer on frame \(frameCount)")
                    continue
                }
                let presentationTime = CMTimeMultiply(frameDuration, multiplier: Int32(frameCount))
                let success = pixelBufferAdaptor.append(buffer, withPresentationTime: presentationTime)
                if !success {
                    print("fail to add image at frame count \(frameCount)")
                    continue
                }
                frameCount = frameCount + 1
            }
            
            // if frameBuffers.isEmpty == false, the escaping block will be called again when ready
            // else: processing finished
            if frameBuffers.isEmpty {
                assetWriterInput.markAsFinished()
                assetWriter.finishWriting() {
                    print("writing finished")
                    DispatchQueue.main.async {
                        completion?(true)
                        return
                    }
                }
            }
        }
        
        print("end")
    }
    
}
