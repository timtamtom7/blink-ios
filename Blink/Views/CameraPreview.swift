import SwiftUI
import AVFoundation

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> CameraPreviewView {
        let view = CameraPreviewView()
        view.session = session
        return view
    }

    func updateUIView(_ uiView: CameraPreviewView, context: Context) {}
}

final class CameraPreviewView: UIView {
    var session: AVCaptureSession? {
        didSet {
            guard let session = session else { return }
            if let previewLayer = layer as? AVCaptureVideoPreviewLayer {
                previewLayer.session = session
            }
        }
    }

    private var previewLayer: AVCaptureVideoPreviewLayer? {
        layer as? AVCaptureVideoPreviewLayer
    }

    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        previewLayer?.videoGravity = .resizeAspectFill
        backgroundColor = .black
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }
}
