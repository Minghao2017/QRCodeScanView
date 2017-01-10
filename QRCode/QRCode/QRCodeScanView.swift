//
//  QRCodeScanView.swift
//  QRCode
//
//  Created by Xue on 2016/12/12.
//  Copyright © 2016年 Xue. All rights reserved.
//

import UIKit
import AVFoundation
import PureLayout

@objc protocol QRCodeScanViewDelegate {
    optional func scanView(view: QRCodeScanView, failedToSetupCaptureSessionDueToAuthorization status: AVAuthorizationStatus)
    optional func scanView(view: QRCodeScanView, didCatchMachineReadable string: String)
}

class QRCodeScanView: UIView {
    
    weak var delegate: QRCodeScanViewDelegate?
    
    private var queue = dispatch_queue_create("com.utovr.QUCodeScan", DISPATCH_QUEUE_CONCURRENT)
    private var session = AVCaptureSession()
    private var device = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo)
    private var metadataOutput = AVCaptureMetadataOutput()
    private weak var previewLayer: AVCaptureVideoPreviewLayer?
    
    private var interestViewScale: CGFloat = 0.6
    private weak var interestRectView: UIView!
    private weak var interesetRectViewWidthConstraint: NSLayoutConstraint?
    private var cornerLengthConstraints = [NSLayoutConstraint]()
    private var cornerViews = [UIView]()
    private weak var loadingIndicator: UIActivityIndicatorView!
    private weak var scanningView: UIImageView!
    private var scanning = false
    
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

/// Public api
extension QRCodeScanView {
    func resume() {
        guard videoDeviceAvaliable() else {
            let alertVC = UIAlertController(title: "提示", message: "相机不可用", preferredStyle: .Alert)
            let confirmAction = UIAlertAction(title: "确定", style: .Default, handler: { (_) in
            })
            alertVC.addAction(confirmAction)
            UIApplication.sharedApplication().keyWindow?.topMostViewController?.presentViewController(alertVC, animated: true, completion: nil)
            return
        }
        if session.running {
            startScanning()
            return
        }
        checkAuthoriztion {[unowned self] (success) in
            if success {
                self.loadingIndicator.startAnimating()
                dispatch_async(self.queue, { [weak self] in
                    self?.configureSession()
                    self?.session.startRunning()
                    dispatch_async(dispatch_get_main_queue(), {[weak self] in
                        self?.loadingIndicator.stopAnimating()
                        self?.updateInterestRectViewSizeAnimated()
                    })
                })
            }
        }
    }
    
    func detectQRCode(image: UIImage, completion: (_ success: Bool, _ value: String?) -> Void) {
        detect(image, completion: completion)
    }
}

private extension QRCodeScanView {
    func setup() {
        addPreviewLayer()
        addInterestRectView()
        addLoadingView()
    }
    
    func addPreviewLayer() {
        
        guard videoDeviceAvaliable() else {
            return
        }
        
        if let previewLayer = AVCaptureVideoPreviewLayer(session: session) {
            previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
            layer.addSublayer(previewLayer)
            self.previewLayer = previewLayer
        }
    }
    
    func addLoadingView() {
        let loadingIndicator = UIActivityIndicatorView(activityIndicatorStyle: .WhiteLarge)
        addSubview(loadingIndicator)
        self.loadingIndicator = loadingIndicator
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint(item: loadingIndicator, attribute: .CenterX, relatedBy: .Equal, toItem: self, attribute: .CenterX, multiplier: 1.0, constant: 0).active = true
        NSLayoutConstraint(item: loadingIndicator, attribute: .CenterY, relatedBy: .Equal, toItem: self, attribute: .CenterY, multiplier: 1.0, constant: 0).active = true
        
        loadingIndicator.hidesWhenStopped = true
    }
    
    func addInterestRectView() {
        let interestView = UIView()
        addSubview(interestView)
        self.interestRectView = interestView
        interestView.layer.borderColor = UIColor.whiteColor().CGColor
        interestView.layer.borderWidth = 3.0 / UIScreen.mainScreen().scale
        
        interestView.autoAlignAxisToSuperviewAxis(.Horizontal)
        interestView.autoAlignAxisToSuperviewAxis(.Vertical)
        NSLayoutConstraint.autoSetPriority(UILayoutPriorityDefaultLow) {
            interestView.autoSetDimension(.Width, toSize: 0)
        }
        interestView.autoMatchDimension(.Height, toDimension: .Width, ofView: interestView, withMultiplier: 1.0)
        
        let cornerBackgroundColor = UIColor(hex: "1caffc")
        let cornerWidth: CGFloat = 5 / UIScreen.mainScreen().scale
        
        let cornerConfiguration: [(ALEdge,ALEdge,ALDimension,ALDimension)] = [
            (.Leading,.Top,.Height,.Width),
            (.Leading,.Top,.Width,.Height),
            (.Trailing,.Top,.Height,.Width),
            (.Trailing,.Top,.Width,.Height),
            (.Leading,.Bottom,.Width,.Height),
            (.Leading,.Bottom,.Height,.Width),
            (.Trailing,.Bottom,.Height,.Width),
            (.Trailing,.Bottom,.Width,.Height),
            ]
        for (edgeFirst, edgeSecond, fixedDimension, flexibalseDimension) in cornerConfiguration {
            let corner = UIView()
            addSubview(corner)
            corner.backgroundColor = cornerBackgroundColor
            corner.autoPinEdge(edgeFirst, toEdge: edgeFirst, ofView: interestView)
            corner.autoPinEdge(edgeSecond, toEdge: edgeSecond, ofView: interestView)
            corner.autoSetDimension(fixedDimension, toSize: cornerWidth)
            cornerLengthConstraints.append(corner.autoSetDimension(flexibalseDimension, toSize: 0))
        }
        
        let backgroundConfiguration: [(ALEdge,ALEdge,ALEdge,ALEdge,ALEdge)] = [
            (.Leading,.Top,.Trailing,.Bottom,.Top),
            (.Trailing,.Top,.Bottom,.Leading,.Trailing),
            (.Trailing,.Bottom,.Leading,.Top,.Bottom),
            (.Leading,.Bottom,.Top,.Trailing,.Leading)
        ]
        for (firstSuperEdge,secondSuperEdge,sameEdge,differentEdge,interestViewDefferentEdge) in backgroundConfiguration {
            let bgView = UIView()
            addSubview(bgView)
            bgView.backgroundColor = UIColor(white: 0, alpha: 0.6)
            bgView.autoPinEdgeToSuperviewEdge(firstSuperEdge)
            bgView.autoPinEdgeToSuperviewEdge(secondSuperEdge)
            bgView.autoPinEdge(sameEdge, toEdge: sameEdge, ofView: interestView)
            bgView.autoPinEdge(differentEdge, toEdge: interestViewDefferentEdge, ofView: interestView)
        }
    }
    
    func addScanningView() {
        let image = UIImage(named: "qrScan_line")
        let iv = UIImageView(image: image)
        interestRectView.addSubview(iv)
        iv.hidden = true
        iv.autoPinEdgeToSuperviewEdge(.Top)
        iv.autoPinEdgeToSuperviewEdge(.Leading, withInset: 16)
        iv.autoPinEdgeToSuperviewEdge(.Trailing, withInset: 16)
        self.scanningView = iv
    }
    
    func updateInterestRectViewSizeAnimated() {
        if interesetRectViewWidthConstraint != nil {
            interestRectView.removeConstraint(interesetRectViewWidthConstraint!)
        }
        layoutIfNeeded()
        UIView.animateWithDuration(0.25, animations: {[weak self] in
            guard let weakSelf = self else {
                return
            }
            weakSelf.interesetRectViewWidthConstraint = weakSelf.interestRectView.autoMatchDimension(.Width, toDimension: .Width, ofView: weakSelf, withMultiplier: weakSelf.interestViewScale)
            let cornerLength: CGFloat = 36.0 / UIScreen.mainScreen().scale
            for constraint in weakSelf.cornerLengthConstraints {
                constraint.constant = cornerLength
            }
            weakSelf.layoutIfNeeded()
            }, completion: {[weak self] (finished) in
                self?.startScanning()
        })
    }
    
    func updateMedataInterestRect() {
        guard let previewLayer = previewLayer else {
            return
        }
        let width = CGRectGetWidth(bounds)
        let height = CGRectGetHeight(bounds)
        let x = width * (1 - interestViewScale) / 2
        let y = (height - width * interestViewScale) / 2
        let sideLength = width * interestViewScale
        let frame = CGRectMake(x, y, sideLength, sideLength)
        let metadataRect = previewLayer.metadataOutputRectOfInterestForRect(frame)
        metadataOutput.rectOfInterest = metadataRect
    }
    
    func checkAuthoriztion(completion: Bool -> Void) {
        let status = AVCaptureDevice.authorizationStatusForMediaType(AVMediaTypeVideo)
        switch status {
        case .Authorized:
            completion(true)
        case .Denied:
            let alertVC = UIAlertController(title: "访问被拒绝", message: "必须启用访问相机权限以访问你的相机，您可到：iPhone设置>隐私>相机中开启UtoVR的访问权限", preferredStyle: .Alert)
            let confirmAction = UIAlertAction(title: "确定", style: .Default, handler: {[weak self] (_) in
                guard let weakSelf = self else {
                    return
                }
                weakSelf.delegate?.scanView?(weakSelf, failedToSetupCaptureSessionDueToAuthorization: .Denied)
            })
            alertVC.addAction(confirmAction)
            UIApplication.sharedApplication().keyWindow?.topMostViewController?.presentViewController(alertVC, animated: true, completion: nil)
            completion(false)
        case .NotDetermined:
            AVCaptureDevice.requestAccessForMediaType(AVMediaTypeVideo) {(success) in
                dispatch_async(dispatch_get_main_queue(), { [weak self] in
                    if success {
                        completion(true)
                    } else {
                        guard let weakSelf = self else {
                            return
                        }
                        weakSelf.delegate?.scanView?(weakSelf, failedToSetupCaptureSessionDueToAuthorization: .NotDetermined)
                        completion(false)
                    }
                })
                
            }
        case .Restricted:
            completion(false)
        }
    }
    
    func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = AVCaptureSessionPresetHigh
        
        guard videoDeviceAvaliable() else {
            return
        }
        
        guard let deviceInput = try? AVCaptureDeviceInput(device: device) else {
            return
        }
        if session.canAddInput(deviceInput) {
            session.addInput(deviceInput)
        }
        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            metadataOutput.metadataObjectTypes = [AVMetadataObjectTypeQRCode, AVMetadataObjectTypeEAN13Code, AVMetadataObjectTypeEAN8Code, AVMetadataObjectTypeCode128Code]
            metadataOutput.setMetadataObjectsDelegate(self, queue: dispatch_get_main_queue())
            updateMedataInterestRect()
        }
        session.commitConfiguration()
    }
    
    func videoDeviceAvaliable() -> Bool {
        return device != nil
    }
    
    func startScanning() {
        if scanning {
            return
        }
        if scanningView == nil {
            addScanningView()
        }
        scanning = true
        scanningView.hidden = false
        self.scanningView.layer.addAnimation(animationForScanningView(), forKey: "scanningView-position")
    }
    
    func stopScanning() {
        if !scanning {
            return
        }
        scanning = false
        scanningView.hidden = true
        self.scanningView.layer.removeAllAnimations()
    }
    
    func animationForScanningView() -> CAAnimation {
        
        let height = CGRectGetHeight(interestRectView.bounds)
        let width = CGRectGetWidth(interestRectView.bounds)
        
        let animation = CABasicAnimation(keyPath: "position")
        animation.fromValue = NSValue(CGPoint: CGPointMake(width / 2, 4))
        animation.toValue = NSValue(CGPoint: CGPointMake(width / 2, height - 4))
        animation.duration = 1.6
        animation.repeatCount = Float.infinity
        animation.removedOnCompletion = false
        return animation
    }
    
    func detect(image: UIImage, completion: (_ success: Bool, _ value: String?) -> Void) {
        let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
        
        guard let ciImage = CIImage(image: image) else {
            completion(success: false, value: nil)
            return
        }
        guard let features = detector?.featuresInImage(ciImage) else {
            completion(success: false, value: nil)
            return
        }
        
        var ret = ""
        for feature in features {
            if let QRFeature = feature as? CIQRCodeFeature {
                ret += (QRFeature.messageString ?? "")
            }
        }
        if ret.characters.count > 0 {
            completion(success: true, value: ret)
        } else {
            completion(success: false, value: nil)
        }
    }
}

extension QRCodeScanView: AVCaptureMetadataOutputObjectsDelegate {
    func captureOutput(captureOutput: AVCaptureOutput!, didOutputMetadataObjects metadataObjects: [AnyObject]!, fromConnection connection: AVCaptureConnection!) {
        guard scanning else {
            return
        }
        
        guard metadataObjects.count > 0 else {
            return
        }
        guard let firstMachineReadableObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject else {
            return
        }
        stopScanning()
        let value = firstMachineReadableObject.stringValue
        delegate?.scanView?(self, didCatchMachineReadable: value)
    }
}
