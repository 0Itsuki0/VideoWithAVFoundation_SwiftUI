//
//  PhotoLibraryManager.swift
//  MediaReadingDemo
//
//  Created by Itsuki on 2024/08/09.
//

import Foundation
import Photos

class PhotoLibraryManager {
    
    private func checkAuthorization() async -> Bool {
        switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
        case .authorized:
            print("Photo library access authorized.")
            return true
        case .notDetermined:
            print("Photo library access not determined.")
            return await PHPhotoLibrary.requestAuthorization(for: .readWrite) == .authorized
        case .denied:
            print("Photo library access denied.")
            return false
        case .limited:
            print("Photo library access limited.")
            return false
        case .restricted:
            print("Photo library access restricted.")
            return false
        @unknown default:
            return false
        }
    }
    
    func saveVideo(_ fileUrl: URL) async {
        let isAuthorized = await checkAuthorization()
        if (!isAuthorized) {
            return
        }
        
        do {
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .video, fileURL: fileUrl, options: nil)
            }
            print("file saved!")
        } catch (let error) {
            print("Failed to create asset: \(error.localizedDescription)")
        }
    }
}
