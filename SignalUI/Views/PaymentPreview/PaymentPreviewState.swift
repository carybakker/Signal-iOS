//
//  Copyright (c) 2021 Open Whisper Systems. All rights reserved.
//

import YYImage

@objc
public enum PaymentPreviewImageState: Int {
    case none
    case loading
    case loaded
    case invalid
}

// MARK: -

@objc
public protocol PaymentPreviewState {
    func isLoaded() -> Bool
    func urlString() -> String?
    func displayDomain() -> String?
    func title() -> String?
    func previewDescription() -> String?
    func date() -> Date?
    var isGroupInviteLink: Bool { get }
    var activityIndicatorStyle: UIActivityIndicatorView.Style { get }
    var conversationStyle: ConversationStyle? { get }
}

// MARK: -

@objc
public enum PaymentPreviewLinkType: UInt {
    case preview
    case incomingMessage
    case outgoingMessage
    case incomingMessageGroupInviteLink
    case outgoingMessageGroupInviteLink
}

// MARK: -

@objc
public class PaymentPreviewLoading: NSObject, PaymentPreviewState {

    public let linkType: PaymentPreviewLinkType

    @objc
    required init(linkType: PaymentPreviewLinkType) {
        self.linkType = linkType
    }

    public func isLoaded() -> Bool {
        return false
    }

    public func urlString() -> String? {
        return nil
    }

    public func displayDomain() -> String? {
        return nil
    }

    public func title() -> String? {
        return nil
    }

    public func imageState() -> PaymentPreviewImageState {
        return .none
    }

    public func imageAsync(thumbnailQuality: AttachmentThumbnailQuality,
                           completion: @escaping (UIImage) -> Void) {
        owsFailDebug("Should not be called.")
    }

    public func imageCacheKey(thumbnailQuality: AttachmentThumbnailQuality) -> String? {
        owsFailDebug("Should not be called.")
        return nil
    }

    public let imagePixelSize: CGSize = .zero

    public func previewDescription() -> String? {
        return nil
    }

    public func date() -> Date? {
        return nil
    }

    public var isGroupInviteLink: Bool {
        switch linkType {
        case .incomingMessageGroupInviteLink,
             .outgoingMessageGroupInviteLink:
            return true
        default:
            return false
        }
    }

    public var activityIndicatorStyle: UIActivityIndicatorView.Style {
        switch linkType {
        case .incomingMessageGroupInviteLink:
            return .gray
        case .outgoingMessageGroupInviteLink:
            return .white
        default:
            return PaymentPreviewView.defaultActivityIndicatorStyle
        }
    }

    public let conversationStyle: ConversationStyle? = nil
}

// MARK: -

@objc
public class PaymentPreviewDraft: NSObject, PaymentPreviewState {
    let paymentPreviewDraft: OWSPaymentPreviewDraft

    @objc
    public required init(paymentPreviewDraft: OWSPaymentPreviewDraft) {
        self.paymentPreviewDraft = paymentPreviewDraft
    }

    public func isLoaded() -> Bool {
        return true
    }

    public func urlString() -> String? {
        return paymentPreviewDraft.urlString
    }

    public func displayDomain() -> String? {
        guard let displayDomain = paymentPreviewDraft.displayDomain() else {
            owsFailDebug("Missing display domain")
            return nil
        }
        return displayDomain
    }

    public func title() -> String? {
        guard let value = paymentPreviewDraft.title,
            value.count > 0 else {
                return nil
        }
        return value
    }

    public func imageState() -> PaymentPreviewImageState {
        if paymentPreviewDraft.imageData != nil {
            return .loaded
        } else {
            return .none
        }
    }

    public func imageAsync(thumbnailQuality: AttachmentThumbnailQuality,
                           completion: @escaping (UIImage) -> Void) {
        owsAssertDebug(imageState() == .loaded)
        guard let imageData = paymentPreviewDraft.imageData else {
            owsFailDebug("Missing imageData.")
            return
        }
        DispatchQueue.global().async {
            guard let image = UIImage(data: imageData) else {
                owsFailDebug("Could not load image: \(imageData.count)")
                return
            }
            completion(image)
        }
    }

    public func imageCacheKey(thumbnailQuality: AttachmentThumbnailQuality) -> String? {
        guard let urlString = self.urlString() else {
            owsFailDebug("Missing urlString.")
            return nil
        }
        return "\(urlString).\(NSStringForAttachmentThumbnailQuality(thumbnailQuality))"
    }

    private let imagePixelSizeCache = AtomicOptional<CGSize>(nil)

    @objc
    public var imagePixelSize: CGSize {
        if let cachedValue = imagePixelSizeCache.get() {
            return cachedValue
        }
        owsAssertDebug(imageState() == .loaded)
        guard let imageData = paymentPreviewDraft.imageData else {
            owsFailDebug("Missing imageData.")
            return .zero
        }
        let imageMetadata = (imageData as NSData).imageMetadata(withPath: nil, mimeType: nil)
        guard imageMetadata.isValid else {
            owsFailDebug("Invalid image.")
            return .zero
        }
        let imagePixelSize = imageMetadata.pixelSize
        guard imagePixelSize.width > 0,
              imagePixelSize.height > 0 else {
            owsFailDebug("Invalid image size.")
            return .zero
        }
        let result = imagePixelSize
        imagePixelSizeCache.set(result)
        return result
    }

    public func previewDescription() -> String? {
        paymentPreviewDraft.previewDescription
    }

    public func date() -> Date? {
        paymentPreviewDraft.date
    }

    public let isGroupInviteLink = false

    public var activityIndicatorStyle: UIActivityIndicatorView.Style {
        PaymentPreviewView.defaultActivityIndicatorStyle
    }

    public let conversationStyle: ConversationStyle? = nil
}

// MARK: -

@objc
public class PaymentPreviewSent: NSObject, PaymentPreviewState {
    private let paymentPreview: OWSPaymentPreview

    private let _conversationStyle: ConversationStyle
    public var conversationStyle: ConversationStyle? {
        _conversationStyle
    }

    @objc
    public required init(paymentPreview: OWSPaymentPreview,
                  conversationStyle: ConversationStyle) {
        self.paymentPreview = paymentPreview
        _conversationStyle = conversationStyle
    }

    public func isLoaded() -> Bool {
        return true
    }

    public func urlString() -> String? {
        guard let urlString = paymentPreview.urlString else {
            owsFailDebug("Missing url")
            return nil
        }
        return urlString
    }

    public func displayDomain() -> String? {
        guard let displayDomain = paymentPreview.displayDomain() else {
            Logger.error("Missing display domain")
            return nil
        }
        return displayDomain
    }

    public func title() -> String? {
        guard let value = paymentPreview.title?.filterForDisplay,
            value.count > 0 else {
                return nil
        }
        return value
    }

    public func previewDescription() -> String? {
        paymentPreview.previewDescription
    }

    public func date() -> Date? {
        paymentPreview.date
    }

    public let isGroupInviteLink = false

    public var activityIndicatorStyle: UIActivityIndicatorView.Style {
        PaymentPreviewView.defaultActivityIndicatorStyle
    }
}
