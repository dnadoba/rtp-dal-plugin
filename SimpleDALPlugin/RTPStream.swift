//
//  RTPStream.swift
//  SimpleDALPlugin
//
//  Created by David Nadoba on 20.05.20.
//  Copyright © 2020 com.seanchas116. All rights reserved.
//

import Foundation
import SwiftRTP
import RTPAVKit

protocol Stream: Object {
    func start()
    func stop()
    func copyBufferQueue(queueAlteredProc: CMIODeviceStreamQueueAlteredProc?, queueAlteredRefCon: UnsafeMutableRawPointer?) -> CMSimpleQueue?
}


class RTPStream: Stream {
    var objectID: CMIOObjectID = 0
    let name: String
    let width = 1920
    let height = 1080
    let frameRate = 30

    private var sequenceNumber: UInt64 = 0
    private var queueAlteredProc: CMIODeviceStreamQueueAlteredProc?
    private var queueAlteredRefCon: UnsafeMutableRawPointer?

    private var formatDescription: CMVideoFormatDescription?

    private lazy var clock: CFTypeRef? = {
        var clock: Unmanaged<CFTypeRef>? = nil

        let error = CMIOStreamClockCreate(
            kCFAllocatorDefault,
            "SimpleDALPlugin clock" as CFString,
            Unmanaged.passUnretained(self).toOpaque(),
            CMTimeMake(value: 1, timescale: 900),
            100, 0,
            &clock);
        guard error == noErr else {
            log("CMIOStreamClockCreate Error: \(error)")
            return nil
        }
        return clock?.takeUnretainedValue()
    }()

    private lazy var queue: CMSimpleQueue? = {
        var queue: CMSimpleQueue?
        let error = CMSimpleQueueCreate(
            allocator: kCFAllocatorDefault,
            capacity: 30,
            queueOut: &queue)
        guard error == noErr else {
            log("CMSimpleQueueCreate Error: \(error)")
            return nil
        }
        return queue
    }()
    
    var properties: [Int : Property] {
        var properties = [
            kCMIOObjectPropertyName: Property(name),
            kCMIOStreamPropertyDirection: Property(UInt32(0)),
            kCMIOStreamPropertyFrameRate: Property(Float64(frameRate)),
            kCMIOStreamPropertyFrameRates: Property(Float64(frameRate)),
            kCMIOStreamPropertyMinimumFrameRate: Property(Float64(frameRate)),
            kCMIOStreamPropertyFrameRateRanges: Property(AudioValueRange(mMinimum: Float64(frameRate), mMaximum: Float64(frameRate))),
            kCMIOStreamPropertyClock: Property(CFTypeRefWrapper(ref: clock!)),
        ]
        
        if let formatDescription = self.formatDescription {
            properties[kCMIOStreamPropertyFormatDescription] = Property(formatDescription)
            properties[kCMIOStreamPropertyFormatDescriptions] = Property([formatDescription] as CFArray)
        }
        
        return properties
    }
    
    init(name: String) {
        self.name = name
        self.formatDescription = {
            var formatDescription: CMVideoFormatDescription?
            let error = CMVideoFormatDescriptionCreate(
                allocator: kCFAllocatorDefault,
                codecType: kCVPixelFormatType_32ARGB,
                width: Int32(width), height: Int32(height),
                extensions: nil,
                formatDescriptionOut: &formatDescription)
            guard error == noErr else {
                log("CMVideoFormatDescriptionCreate Error: \(error)")
                return nil
            }
            return formatDescription
        }()
    }
    
    
    private var reciever: RTPH264Reciever?
    private var decoder: VideoDecoder?
    func start() {
        reciever = try? .init(host: "0.0.0.0", port: 1234, timebase: CMTimebase(masterClock: CMClockGetHostTimeClock()))
        reciever?.didRecieveFormatDescription = { [weak self] formatDescription in
            guard let self = self else { return }
            log("\(formatDescription)")
            self.formatDescription = formatDescription
            
            
//            do {
//                if let decoder = self.decoder {
//                    if !decoder.canAcceptFormatDescription(formatDescription) {
//                        self.decoder = try self.makeDecoder(formatDescription: formatDescription)
//                    }
//                } else {
//                    self.decoder = try self.makeDecoder(formatDescription: formatDescription)
//                }
//            } catch {
//                log(error)
//            }
            
            
            let changedAddresses = [
            CMIOObjectPropertyAddress(
                mSelector: UInt32(kCMIOStreamPropertyFormatDescription),
                mScope: UInt32(kCMIOObjectPropertyScopeGlobal),
                mElement: UInt32(kCMIOObjectPropertyElementMaster)),
            CMIOObjectPropertyAddress(
                mSelector: UInt32(kCMIOStreamPropertyFormatDescriptions),
                mScope: UInt32(kCMIOObjectPropertyScopeGlobal),
                mElement: UInt32(kCMIOObjectPropertyElementMaster)),
            ]
            CMIOObjectPropertiesChanged(pluginRef, self.objectID, UInt32(changedAddresses.count), changedAddresses)
        }
        reciever?.didRecieveSampleBuffer = { [weak self] sampleBuffer in
            guard let self = self else { return }
            let error = CMIOStreamClockPostTimingEvent(sampleBuffer.outputPresentationTimeStamp, mach_absolute_time(), true, self.clock)
            guard error == noErr else {
                log("CMIOStreamClockPostTimingEvent Error: \(error)")
                return
            }
            self.enqueueSampleBuffer(sampleBuffer)
//            do {
//                try self?.decoder?.decodeFrame(sampleBuffer: sampleBuffer, flags: [._1xRealTimePlayback, ._EnableAsynchronousDecompression])
//            } catch {
//                log(error)
//            }
        }
    }
    
    private func makeDecoder(formatDescription: CMVideoFormatDescription) throws -> VideoDecoder {
        let decoder = try VideoDecoder(formatDescription: formatDescription)
        decoder.callback = { [weak self] (frame, presentationTimeStamp, presentationDuraton) in
//            guard let frame = frame else { return }
//            var formatDescription: CMVideoFormatDescription?
//            let error = CMVideoFormatDescriptionCreate(
//                allocator: kCFAllocatorDefault,
//                codecType: CVPixelBufferGetPixelFormatType(frame),
//                width: Int32(frame.width), height: Int32(frame.height),
//                extensions: nil,
//                formatDescriptionOut: &formatDescription)
//            guard error == noErr else {
//                log("CMVideoFormatDescriptionCreate Error: \(error)")
//                return
//            }

        }
        return decoder
    }

    func stop() {
        reciever = nil
    }

    func copyBufferQueue(queueAlteredProc: CMIODeviceStreamQueueAlteredProc?, queueAlteredRefCon: UnsafeMutableRawPointer?) -> CMSimpleQueue? {
        self.queueAlteredProc = queueAlteredProc
        self.queueAlteredRefCon = queueAlteredRefCon
        return self.queue
    }

    private func enqueueSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard let queue = queue else {
            log("queue is nil")
            return
        }
        CMSimpleQueueEnqueue(queue, element: Unmanaged.passRetained(sampleBuffer).toOpaque())
        queueAlteredProc?(objectID, Unmanaged.passRetained(sampleBuffer).toOpaque(), queueAlteredRefCon)
    }
}
