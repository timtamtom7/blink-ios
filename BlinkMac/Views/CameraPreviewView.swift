import SwiftUI
import AppKit
import AVFoundation

struct CameraPreviewView: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> CameraPreviewNSView {
        let view = CameraPreviewNSView()
        view.configure(with: session)
        return view
    }

    func updateNSView(_ nsView: CameraPreviewNSView, context: Context) {}
}

class CameraPreviewNSView: NSView {
    private var _previewLayer: AVCaptureVideoPreviewLayer?

    override var wantsUpdateLayer: Bool { true }

    override func layout() {
        super.layout()
        _previewLayer?.frame = bounds
    }

    func configure(with session: AVCaptureSession) {
        wantsLayer = true
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.backgroundColor = NSColor(Color(hex: "0A0A0A")).cgColor
        previewLayer.videoGravity = .resizeAspectFill
        self._previewLayer = previewLayer
        layer?.addSublayer(previewLayer)
        previewLayer.frame = bounds
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
