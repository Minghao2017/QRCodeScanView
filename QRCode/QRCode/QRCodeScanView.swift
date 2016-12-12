//
//  QRCodeScanView.swift
//  QRCode
//
//  Created by Xue on 2016/12/12.
//  Copyright © 2016年 Xue. All rights reserved.
//

import UIKit
import AVFoundation

class QRCodeScanView: UIView {
    
    var interestRectScale: CGFloat = 0.8 {
        didSet {
            updateInterestRect()
        }
    }
    
    fileprivate var session = AVCaptureSession()
    fileprivate lazy var inputDevice: AVCaptureDeviceInput? = {
        let device = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)
        let input = try? AVCaptureDeviceInput(device: device)
        return input
    }()
    fileprivate var metadataOutput = AVCaptureMetadataOutput()
    fileprivate var previewLayer: CALayer?
    
    fileprivate var interestRectView: UIView!
    fileprivate var cornerViews = [UIView]()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }
}

private extension QRCodeScanView {
    func setup() {
        
        session.sessionPreset = AVCaptureSessionPresetHigh
        
        guard let inputDevice = inputDevice else {
            return
        }
        if session.canAddInput(inputDevice) {
            session.addInput(inputDevice)
        }
        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            metadataOutput.metadataObjectTypes = [AVMetadataObjectTypeQRCode, AVMetadataObjectTypeEAN13Code, AVMetadataObjectTypeEAN8Code, AVMetadataObjectTypeCode128Code]
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        }
        
        if let previewLayer = AVCaptureVideoPreviewLayer(session: session) {
            previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
            layer.addSublayer(previewLayer)
            self.previewLayer = previewLayer
        }
        updateInterestRect()
        addInteresetRectView()
    }
    
    func addInteresetRectView() {
        let width = bounds.width
        let height = bounds.height
        
        let interestRectSideLength = interestRectScale * width
        
        let interestRectView = UIView()
        addSubview(interestRectView)
        interestRectView.layer.borderColor = UIColor.white.cgColor
        interestRectView.layer.borderWidth = 3.0 / UIScreen.main.scale
        self.interestRectView = interestRectView
        
        for index in 0..<8 {
            let view = UIView()
            view.backgroundColor = UIColor.blue
            interestRectView.addSubview(<#T##view: UIView##UIView#>)
        }
        
        let luPoint = CGPoint(
            x: (width - interestRectSideLength) / 2,
            y: (height - interestRectSideLength) / 2)
        let ruPoint = CGPoint(
            x: luPoint.x + interestRectSideLength,
            y: luPoint.y)
        let llPoint = CGPoint(
            x: luPoint.x,
            y: luPoint.y + interestRectSideLength)
        let rlPoint = CGPoint(
            x: llPoint.x,
            y: ruPoint.y)

    }
    
    func updateInterestRect() {
        metadataOutput.rectOfInterest = CGRect(x: 0, y: 0, width: 1, height: 1)
    }
}

extension QRCodeScanView: AVCaptureMetadataOutputObjectsDelegate {
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputMetadataObjects metadataObjects: [Any]!, from connection: AVCaptureConnection!) {
        guard metadataObjects.count > 0 else {
            return
        }
        guard let firstMachineReadableObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject else {
            return
        }
        print(firstMachineReadableObject.stringValue)
    }
}
