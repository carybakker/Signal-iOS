//
//  Copyright (c) 2022 Open Whisper Systems. All rights reserved.
//

import YYImage
import SignalMessaging

@objc
public protocol PaymentPreviewViewDraftDelegate {
    func paymentPreviewCanCancel() -> Bool
    func paymentPreviewDidCancel()
}

// MARK: -

@objc
public class PaymentPreviewView: ManualStackViewWithLayer {
    private weak var draftDelegate: PaymentPreviewViewDraftDelegate?

    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    @available(*, unavailable, message: "use other constructor instead.")
    required init(coder aDecoder: NSCoder) {
        notImplemented()
    }

    @available(*, unavailable, message: "use other constructor instead.")
    required init(name: String, arrangedSubviews: [UIView] = []) {
        notImplemented()
    }

    public var state: PaymentPreviewState?
    private var configurationSize: CGSize?
    private var shouldReconfigureForBounds = false

    fileprivate let rightStack = ManualStackView(name: "rightStack")
    fileprivate let textStack = ManualStackView(name: "textStack")
    fileprivate let titleStack = ManualStackView(name: "titleStack")

    fileprivate let titleLabel = CVLabel()
    fileprivate let descriptionLabel = CVLabel()
    fileprivate let displayDomainLabel = CVLabel()

    fileprivate let paymentPreviewImageView = PaymentPreviewImageView()

    fileprivate var cancelButton: UIView?

    @objc
    public init(draftDelegate: PaymentPreviewViewDraftDelegate?) {
        self.draftDelegate = draftDelegate

        super.init(name: "PaymentPreviewView")

        if let draftDelegate = draftDelegate,
           draftDelegate.paymentPreviewCanCancel() {
            self.isUserInteractionEnabled = true
            self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(wasTapped)))
        }
    }

    private var nonCvcLayoutConstraint: NSLayoutConstraint?

    // This view is used in a number of places to display "drafts"
    // of outgoing payment previews.  In these cases, the view will
    // be embedded within views using iOS auto layout and will need
    // to reconfigure its contents whenever the view size changes.
    @objc
    public func configureForNonCVC(state: PaymentPreviewState,
                                   isDraft: Bool,
                                   hasAsymmetricalRounding: Bool = false) {

        self.shouldDeactivateConstraints = false
        self.shouldReconfigureForBounds = true

        applyConfigurationForNonCVC(state: state,
                                    isDraft: isDraft,
                                    hasAsymmetricalRounding: hasAsymmetricalRounding)

        addLayoutBlock { view in
            guard let paymentPreviewView = view as? PaymentPreviewView else {
                owsFailDebug("Invalid view.")
                return
            }
            if let state = paymentPreviewView.state,
               paymentPreviewView.shouldReconfigureForBounds,
               paymentPreviewView.configurationSize != paymentPreviewView.bounds.size {
                paymentPreviewView.applyConfigurationForNonCVC(state: state,
                                                            isDraft: isDraft,
                                                            hasAsymmetricalRounding: hasAsymmetricalRounding)
            }
        }
    }

    private func applyConfigurationForNonCVC(state: PaymentPreviewState,
                                             isDraft: Bool,
                                             hasAsymmetricalRounding: Bool) {
        self.reset()
        self.configurationSize = bounds.size
        let maxWidth = (self.bounds.width > 0
                            ? self.bounds.width
                            : CGFloat.greatestFiniteMagnitude)

        let measurementBuilder = CVCellMeasurement.Builder()
        let paymentPreviewSize = Self.measure(maxWidth: maxWidth,
                                           measurementBuilder: measurementBuilder,
                                           state: state,
                                           isDraft: isDraft)
        let cellMeasurement = measurementBuilder.build()
        configureForRendering(state: state,
                              isDraft: isDraft,
                              hasAsymmetricalRounding: hasAsymmetricalRounding,
                              cellMeasurement: cellMeasurement)

        if let nonCvcLayoutConstraint = self.nonCvcLayoutConstraint {
            nonCvcLayoutConstraint.constant = paymentPreviewSize.height
        } else {
            self.nonCvcLayoutConstraint = self.autoSetDimension(.height,
                                                                toSize: paymentPreviewSize.height)
        }
    }

    public func configureForRendering(state: PaymentPreviewState,
                                      isDraft: Bool,
                                      hasAsymmetricalRounding: Bool,
                                      cellMeasurement: CVCellMeasurement) {
        self.state = state
        let adapter = Self.adapter(forState: state, isDraft: isDraft)
        adapter.configureForRendering(paymentPreviewView: self,
                                      hasAsymmetricalRounding: hasAsymmetricalRounding,
                                      cellMeasurement: cellMeasurement)
    }

    private static func adapter(forState state: PaymentPreviewState,
                                isDraft: Bool) -> PaymentPreviewViewAdapter {
        if !state.isLoaded() {
            return PaymentPreviewViewAdapterDraftLoading(state: state)
        } else if isDraft {
            return PaymentPreviewViewAdapterDraft(state: state)
        } else {
//            if state.hasLoadedImage {
//                if Self.sentIsHero(state: state) {
//                    return PaymentPreviewViewAdapterSentHero(state: state)
//                } else if state.previewDescription()?.isEmpty == false,
//                          state.title()?.isEmpty == false {
//                    return PaymentPreviewViewAdapterSentWithDescription(state: state)
//                } else {
//                    return PaymentPreviewViewAdapterSent(state: state)
//                }
//            } else {
                return PaymentPreviewViewAdapterSent(state: state)
//            }
        }
    }

    fileprivate static let sentTitleFontSizePoints: CGFloat = 17
    fileprivate static let sentDomainFontSizePoints: CGFloat = 12
    fileprivate static let sentVSpacing: CGFloat = 4

    // The "sent message" mode has two submodes: "hero" and "non-hero".
    fileprivate static let sentNonHeroHMargin: CGFloat = 12
    fileprivate static let sentNonHeroVMargin: CGFloat = 12
    fileprivate static var sentNonHeroLayoutMargins: UIEdgeInsets {
        UIEdgeInsets(top: sentNonHeroVMargin,
                     left: sentNonHeroHMargin,
                     bottom: sentNonHeroVMargin,
                     right: sentNonHeroHMargin)
    }

    fileprivate static let sentNonHeroImageSize: CGFloat = 64
    fileprivate static let sentNonHeroHSpacing: CGFloat = 8

    fileprivate static let sentHeroHMargin: CGFloat = 12
    fileprivate static let sentHeroVMargin: CGFloat = 12
    fileprivate static var sentHeroLayoutMargins: UIEdgeInsets {
        UIEdgeInsets(top: sentHeroVMargin,
                     left: sentHeroHMargin,
                     bottom: sentHeroVMargin,
                     right: sentHeroHMargin)
    }

    fileprivate static let sentTitleLineCount: Int = 2
    fileprivate static let sentDescriptionLineCount: Int = 3

    fileprivate static func sentIsHero(state: PaymentPreviewState) -> Bool {
        return false
    }

    private static func isSticker(state: PaymentPreviewState) -> Bool {
        guard let urlString = state.urlString() else {
            owsFailDebug("Link preview is missing url.")
            return false
        }
        guard let url = URL(string: urlString) else {
            owsFailDebug("Could not parse URL.")
            return false
        }
        return StickerPackInfo.isStickerPackShare(url)
    }

    static var defaultActivityIndicatorStyle: UIActivityIndicatorView.Style {
        Theme.isDarkThemeEnabled
            ? .white
            : .gray
    }

    // MARK: Events

    @objc func wasTapped(sender: UIGestureRecognizer) {
        guard sender.state == .recognized else {
            return
        }
        if let cancelButton = cancelButton {
            // Permissive hot area to make it very easy to cancel the payment preview.
            if cancelButton.containsGestureLocation(sender, hotAreaAdjustment: 20) {
                self.draftDelegate?.paymentPreviewDidCancel()
                return
            }
        }
    }

    // MARK: Measurement

    public static func measure(maxWidth: CGFloat,
                               measurementBuilder: CVCellMeasurement.Builder,
                               state: PaymentPreviewState,
                               isDraft: Bool) -> CGSize {
        let adapter = Self.adapter(forState: state, isDraft: isDraft)
        let size = adapter.measure(maxWidth: maxWidth,
                                   measurementBuilder: measurementBuilder,
                                   state: state)
        if size.width > maxWidth {
            owsFailDebug("size.width: \(size.width) > maxWidth: \(maxWidth)")
        }
        return size
    }

    @objc
    fileprivate func didTapCancel() {
        draftDelegate?.paymentPreviewDidCancel()
    }

    public override func reset() {
        super.reset()

        self.backgroundColor = nil

        rightStack.reset()
        textStack.reset()
        titleStack.reset()

        titleLabel.text = nil
        descriptionLabel.text = nil
        displayDomainLabel.text = nil

        paymentPreviewImageView.reset()

        for subview in [
            rightStack, textStack, titleStack,
            titleLabel, descriptionLabel, displayDomainLabel,
            paymentPreviewImageView
        ] {
            subview.removeFromSuperview()
        }

        cancelButton = nil

        nonCvcLayoutConstraint?.autoRemove()
        nonCvcLayoutConstraint = nil
    }
}

// MARK: -

private protocol PaymentPreviewViewAdapter {
    func configureForRendering(paymentPreviewView: PaymentPreviewView,
                               hasAsymmetricalRounding: Bool,
                               cellMeasurement: CVCellMeasurement)

    func measure(maxWidth: CGFloat,
                 measurementBuilder: CVCellMeasurement.Builder,
                 state: PaymentPreviewState) -> CGSize
}

// MARK: -

extension PaymentPreviewViewAdapter {

    fileprivate static var measurementKey_rootStack: String { "PaymentPreviewView.measurementKey_rootStack" }
    fileprivate static var measurementKey_rightStack: String { "PaymentPreviewView.measurementKey_rightStack" }
    fileprivate static var measurementKey_textStack: String { "PaymentPreviewView.measurementKey_textStack" }
    fileprivate static var measurementKey_titleStack: String { "PaymentPreviewView.measurementKey_titleStack" }

    func sentTitleLabel(state: PaymentPreviewState) -> UILabel? {
        guard let config = sentTitleLabelConfig(state: state) else {
            return nil
        }
        let label = CVLabel()
        config.applyForRendering(label: label)
        return label
    }

    func sentTitleLabelConfig(state: PaymentPreviewState) -> CVLabelConfig? {
        guard let text = state.title() else {
            return nil
        }
        return CVLabelConfig(text: text,
                             font: UIFont.ows_dynamicTypeSubheadline.ows_semibold,
                             textColor: Theme.primaryTextColor,
                             numberOfLines: PaymentPreviewView.sentTitleLineCount,
                             lineBreakMode: .byTruncatingTail)
    }

    func sentDescriptionLabel(state: PaymentPreviewState) -> UILabel? {
        guard let config = sentDescriptionLabelConfig(state: state) else {
            return nil
        }
        let label = CVLabel()
        config.applyForRendering(label: label)
        return label
    }

    func sentDescriptionLabelConfig(state: PaymentPreviewState) -> CVLabelConfig? {
        guard let text = state.previewDescription() else { return nil }
        return CVLabelConfig(text: text,
                             font: UIFont.ows_dynamicTypeSubheadline,
                             textColor: Theme.primaryTextColor,
                             numberOfLines: PaymentPreviewView.sentDescriptionLineCount,
                             lineBreakMode: .byTruncatingTail)
    }

    func sentDomainLabel(state: PaymentPreviewState) -> UILabel {
        let label = CVLabel()
        sentDomainLabelConfig(state: state).applyForRendering(label: label)
        return label
    }

    func sentDomainLabelConfig(state: PaymentPreviewState) -> CVLabelConfig {
        var labelText: String
        if let displayDomain = state.displayDomain(),
           displayDomain.count > 0 {
            labelText = displayDomain.lowercased()
        } else {
            labelText = NSLocalizedString("LINK_PREVIEW_UNKNOWN_DOMAIN", comment: "Label for payment previews with an unknown host.").uppercased()
        }
        if let date = state.date() {
            labelText.append(" ⋅ \(PaymentPreviewView.dateFormatter.string(from: date))")
        }
        return CVLabelConfig(text: labelText,
                             font: UIFont.ows_dynamicTypeCaption1,
                             textColor: Theme.secondaryTextAndIconColor,
                             lineBreakMode: .byTruncatingTail)
    }

    func configureSentTextStack(paymentPreviewView: PaymentPreviewView,
                                state: PaymentPreviewState,
                                textStack: ManualStackView,
                                textStackConfig: ManualStackView.Config,
                                cellMeasurement: CVCellMeasurement) {

        var subviews = [UIView]()

        if let titleLabel = sentTitleLabel(state: state) {
            subviews.append(titleLabel)
        }
        if let descriptionLabel = sentDescriptionLabel(state: state) {
            subviews.append(descriptionLabel)
        }
        let domainLabel = sentDomainLabel(state: state)
        subviews.append(domainLabel)

        textStack.configure(config: textStackConfig,
                            cellMeasurement: cellMeasurement,
                            measurementKey: Self.measurementKey_textStack,
                            subviews: subviews)
    }

    func measureSentTextStack(state: PaymentPreviewState,
                              textStackConfig: ManualStackView.Config,
                              measurementBuilder: CVCellMeasurement.Builder,
                              maxLabelWidth: CGFloat) -> CGSize {

        var subviewInfos = [ManualStackSubviewInfo]()

        if let labelConfig = sentTitleLabelConfig(state: state) {
            let labelSize = CVText.measureLabel(config: labelConfig, maxWidth: maxLabelWidth)
            subviewInfos.append(labelSize.asManualSubviewInfo)
        }
        if let labelConfig = sentDescriptionLabelConfig(state: state) {
            let labelSize = CVText.measureLabel(config: labelConfig, maxWidth: maxLabelWidth)
            subviewInfos.append(labelSize.asManualSubviewInfo)
        }
        let labelConfig = sentDomainLabelConfig(state: state)
        let labelSize = CVText.measureLabel(config: labelConfig, maxWidth: maxLabelWidth)
        subviewInfos.append(labelSize.asManualSubviewInfo)

        let measurement = ManualStackView.measure(config: textStackConfig,
                                                  measurementBuilder: measurementBuilder,
                                                  measurementKey: Self.measurementKey_textStack,
                                                  subviewInfos: subviewInfos)
        return measurement.measuredSize
    }
}

// MARK: -

private class PaymentPreviewViewAdapterDraft: PaymentPreviewViewAdapter {

    static let draftHeight: CGFloat = 72
    static let draftMarginTop: CGFloat = 6
    var imageSize: CGFloat { Self.draftHeight }
    let cancelSize: CGFloat = 20

    let state: PaymentPreviewState

    init(state: PaymentPreviewState) {
        self.state = state
    }

    var rootStackConfig: ManualStackView.Config {
        let hMarginLeading: CGFloat = 12
        let hMarginTrailing: CGFloat = 12
        let layoutMargins = UIEdgeInsets(top: Self.draftMarginTop,
                                         leading: hMarginLeading,
                                         bottom: 0,
                                         trailing: hMarginTrailing)
        return ManualStackView.Config(axis: .horizontal,
                                      alignment: .fill,
                                      spacing: 8,
                                      layoutMargins: layoutMargins)
    }

    var rightStackConfig: ManualStackView.Config {
        return ManualStackView.Config(axis: .horizontal,
                                      alignment: .fill,
                                      spacing: 8,
                                      layoutMargins: .zero)
    }

    var textStackConfig: ManualStackView.Config {
        return ManualStackView.Config(axis: .vertical,
                                      alignment: .leading,
                                      spacing: 2,
                                      layoutMargins: .zero)
    }

    var titleLabelConfig: CVLabelConfig? {
        guard let text = state.title()?.nilIfEmpty else {
            return nil
        }
        return CVLabelConfig(text: text,
                             font: .ows_dynamicTypeBody,
                             textColor: Theme.primaryTextColor,
                             lineBreakMode: .byTruncatingTail)
    }

    var descriptionLabelConfig: CVLabelConfig? {
        guard let text = state.previewDescription()?.nilIfEmpty else {
            return nil
        }
        return CVLabelConfig(text: text,
                             font: .ows_dynamicTypeSubheadline,
                             textColor: Theme.isDarkThemeEnabled ? .ows_gray05 : .ows_gray90,
                             lineBreakMode: .byTruncatingTail)
    }

    var displayDomainLabelConfig: CVLabelConfig? {
        guard let displayDomain = state.displayDomain()?.nilIfEmpty else {
            return nil
        }
        var text = displayDomain.lowercased()
        if let date = state.date() {
            text.append(" ⋅ \(PaymentPreviewView.dateFormatter.string(from: date))")
        }
        return CVLabelConfig(text: text,
                             font: .ows_dynamicTypeCaption1,
                             textColor: Theme.secondaryTextAndIconColor,
                             lineBreakMode: .byTruncatingTail)
    }

    func configureForRendering(paymentPreviewView: PaymentPreviewView,
                               hasAsymmetricalRounding: Bool,
                               cellMeasurement: CVCellMeasurement) {

        var rootStackSubviews = [UIView]()
        var rightStackSubviews = [UIView]()

        // Text

        var textStackSubviews = [UIView]()

        if let titleLabelConfig = self.titleLabelConfig {
            let titleLabel = paymentPreviewView.titleLabel
            titleLabelConfig.applyForRendering(label: titleLabel)
            textStackSubviews.append(titleLabel)
        }

        if let descriptionLabelConfig = self.descriptionLabelConfig {
            let descriptionLabel = paymentPreviewView.descriptionLabel
            descriptionLabelConfig.applyForRendering(label: descriptionLabel)
            textStackSubviews.append(descriptionLabel)
        }

        if let displayDomainLabelConfig = self.displayDomainLabelConfig {
            let displayDomainLabel = paymentPreviewView.displayDomainLabel
            displayDomainLabelConfig.applyForRendering(label: displayDomainLabel)
            textStackSubviews.append(displayDomainLabel)
        }

        let textStack = paymentPreviewView.textStack
        textStack.configure(config: textStackConfig,
                            cellMeasurement: cellMeasurement,
                            measurementKey: Self.measurementKey_textStack,
                            subviews: textStackSubviews)
        guard let textMeasurement = cellMeasurement.measurement(key: Self.measurementKey_textStack) else {
            owsFailDebug("Missing measurement.")
            return
        }
        let textWrapper = ManualLayoutView(name: "textWrapper")
        textWrapper.addSubview(textStack) { view in
            var textStackFrame = view.bounds
            textStackFrame.size.height = min(textStackFrame.height,
                                             textMeasurement.measuredSize.height)
            textStackFrame.y = (view.bounds.height - textStackFrame.height) * 0.5
            textStack.frame = textStackFrame
        }
        rightStackSubviews.append(textWrapper)

        // Cancel

        let cancelButton = OWSButton { [weak paymentPreviewView] in
            paymentPreviewView?.didTapCancel()
        }
        cancelButton.accessibilityLabel = MessageStrings.removePreviewButtonLabel
        paymentPreviewView.cancelButton = cancelButton
        cancelButton.setTemplateImageName("compose-cancel",
                                          tintColor: Theme.secondaryTextAndIconColor)
        let cancelSize = self.cancelSize
        let cancelContainer = ManualLayoutView(name: "cancelContainer")
        cancelContainer.addSubview(cancelButton) { view in
            cancelButton.frame = CGRect(x: 0,
                                        y: view.bounds.width - cancelSize,
                                        width: cancelSize,
                                        height: cancelSize)
        }
        rightStackSubviews.append(cancelContainer)

        // Right

        let rightStack = paymentPreviewView.rightStack
        rightStack.configure(config: rightStackConfig,
                             cellMeasurement: cellMeasurement,
                             measurementKey: Self.measurementKey_rightStack,
                             subviews: rightStackSubviews)
        rootStackSubviews.append(rightStack)

        // Stroke

        let strokeView = UIView()
        strokeView.backgroundColor = Theme.secondaryTextAndIconColor
        rightStack.addSubviewAsBottomStroke(strokeView)

        paymentPreviewView.configure(config: rootStackConfig,
                                  cellMeasurement: cellMeasurement,
                                  measurementKey: Self.measurementKey_rootStack,
                                  subviews: rootStackSubviews)
    }

    func measure(maxWidth: CGFloat,
                 measurementBuilder: CVCellMeasurement.Builder,
                 state: PaymentPreviewState) -> CGSize {

        var maxLabelWidth = (maxWidth -
                                (textStackConfig.layoutMargins.totalWidth +
                                    rootStackConfig.layoutMargins.totalWidth))
        maxLabelWidth -= cancelSize + rightStackConfig.spacing

        var rootStackSubviewInfos = [ManualStackSubviewInfo]()
        var rightStackSubviewInfos = [ManualStackSubviewInfo]()

        // Text

        var textStackSubviewInfos = [ManualStackSubviewInfo]()
        if let labelConfig = titleLabelConfig {
            let labelSize = CVText.measureLabel(config: labelConfig, maxWidth: maxLabelWidth)
            textStackSubviewInfos.append(labelSize.asManualSubviewInfo)

        }
        if let labelConfig = self.descriptionLabelConfig {
            let labelSize = CVText.measureLabel(config: labelConfig, maxWidth: maxLabelWidth)
            textStackSubviewInfos.append(labelSize.asManualSubviewInfo)
        }
        if let labelConfig = self.displayDomainLabelConfig {
            let labelSize = CVText.measureLabel(config: labelConfig, maxWidth: maxLabelWidth)
            textStackSubviewInfos.append(labelSize.asManualSubviewInfo)
        }

        let textStackMeasurement = ManualStackView.measure(config: textStackConfig,
                                                           measurementBuilder: measurementBuilder,
                                                           measurementKey: Self.measurementKey_textStack,
                                                           subviewInfos: textStackSubviewInfos)
        rightStackSubviewInfos.append(textStackMeasurement.measuredSize.asManualSubviewInfo)

        // Right

        rightStackSubviewInfos.append(CGSize.square(cancelSize).asManualSubviewInfo(hasFixedWidth: true))

        let rightStackMeasurement = ManualStackView.measure(config: rightStackConfig,
                                                            measurementBuilder: measurementBuilder,
                                                            measurementKey: Self.measurementKey_rightStack,
                                                            subviewInfos: rightStackSubviewInfos)
        rootStackSubviewInfos.append(rightStackMeasurement.measuredSize.asManualSubviewInfo)

        let rootStackMeasurement = ManualStackView.measure(config: rootStackConfig,
                                                           measurementBuilder: measurementBuilder,
                                                           measurementKey: Self.measurementKey_rootStack,
                                                           subviewInfos: rootStackSubviewInfos,
                                                           maxWidth: maxWidth)
        var rootStackSize = rootStackMeasurement.measuredSize
        rootStackSize.height = (PaymentPreviewViewAdapterDraft.draftHeight +
                                    PaymentPreviewViewAdapterDraft.draftMarginTop)
        return rootStackSize
    }
}

// MARK: -

private class PaymentPreviewViewAdapterDraftLoading: PaymentPreviewViewAdapter {

    let activityIndicatorSize = CGSize.square(25)

    let state: PaymentPreviewState

    init(state: PaymentPreviewState) {
        self.state = state
    }

    var rootStackConfig: ManualStackView.Config {
        ManualStackView.Config(axis: .vertical,
                               alignment: .fill,
                               spacing: 0,
                               layoutMargins: .zero)
    }

    func configureForRendering(paymentPreviewView: PaymentPreviewView,
                               hasAsymmetricalRounding: Bool,
                               cellMeasurement: CVCellMeasurement) {

        let activityIndicatorStyle = state.activityIndicatorStyle
        let activityIndicator = UIActivityIndicatorView(style: activityIndicatorStyle)
        activityIndicator.startAnimating()
        paymentPreviewView.addSubviewToCenterOnSuperview(activityIndicator,
                                                      size: activityIndicatorSize)

        let strokeView = UIView()
        strokeView.backgroundColor = Theme.secondaryTextAndIconColor
        paymentPreviewView.addSubviewAsBottomStroke(strokeView,
                                                 layoutMargins: UIEdgeInsets(hMargin: 12,
                                                                             vMargin: 0))

        paymentPreviewView.configure(config: rootStackConfig,
                                  cellMeasurement: cellMeasurement,
                                  measurementKey: Self.measurementKey_rootStack,
                                  subviews: [])
    }

    func measure(maxWidth: CGFloat,
                 measurementBuilder: CVCellMeasurement.Builder,
                 state: PaymentPreviewState) -> CGSize {

        let rootStackMeasurement = ManualStackView.measure(config: rootStackConfig,
                                                           measurementBuilder: measurementBuilder,
                                                           measurementKey: Self.measurementKey_rootStack,
                                                           subviewInfos: [],
                                                           maxWidth: maxWidth)
        var rootStackSize = rootStackMeasurement.measuredSize
        rootStackSize.height = (PaymentPreviewViewAdapterDraft.draftHeight +
                                    PaymentPreviewViewAdapterDraft.draftMarginTop)
        return rootStackSize
    }
}

// MARK: -

private class PaymentPreviewViewAdapterGroupLink: PaymentPreviewViewAdapter {

    let state: PaymentPreviewState

    init(state: PaymentPreviewState) {
        self.state = state
    }

    var rootStackConfig: ManualStackView.Config {
        ManualStackView.Config(axis: .horizontal,
                               alignment: .fill,
                               spacing: PaymentPreviewView.sentNonHeroHSpacing,
                               layoutMargins: PaymentPreviewView.sentNonHeroLayoutMargins)
    }

    var textStackConfig: ManualStackView.Config {
        return ManualStackView.Config(axis: .vertical,
                                      alignment: .leading,
                                      spacing: PaymentPreviewView.sentVSpacing,
                                      layoutMargins: .zero)
    }

    func configureForRendering(paymentPreviewView: PaymentPreviewView,
                               hasAsymmetricalRounding: Bool,
                               cellMeasurement: CVCellMeasurement) {

        paymentPreviewView.backgroundColor = Theme.secondaryBackgroundColor

        var rootStackSubviews = [UIView]()

        let textStack = paymentPreviewView.textStack
        var textStackSubviews = [UIView]()
        if let titleLabel = sentTitleLabel(state: state) {
            textStackSubviews.append(titleLabel)
        }
        if let descriptionLabel = sentDescriptionLabel(state: state) {
            textStackSubviews.append(descriptionLabel)
        }
        textStack.configure(config: textStackConfig,
                            cellMeasurement: cellMeasurement,
                            measurementKey: Self.measurementKey_textStack,
                            subviews: textStackSubviews)
        rootStackSubviews.append(textStack)

        paymentPreviewView.configure(config: rootStackConfig,
                                  cellMeasurement: cellMeasurement,
                                  measurementKey: Self.measurementKey_rootStack,
                                  subviews: rootStackSubviews)
    }

    func measure(maxWidth: CGFloat,
                 measurementBuilder: CVCellMeasurement.Builder,
                 state: PaymentPreviewState) -> CGSize {

        var maxLabelWidth = (maxWidth -
                                (textStackConfig.layoutMargins.totalWidth +
                                    rootStackConfig.layoutMargins.totalWidth))

        var rootStackSubviewInfos = [ManualStackSubviewInfo]()

        maxLabelWidth = max(0, maxLabelWidth)

        var textStackSubviewInfos = [ManualStackSubviewInfo]()
        if let labelConfig = sentTitleLabelConfig(state: state) {
            let labelSize = CVText.measureLabel(config: labelConfig, maxWidth: maxLabelWidth)
            textStackSubviewInfos.append(labelSize.asManualSubviewInfo)
        }
        if let labelConfig = sentDescriptionLabelConfig(state: state) {
            let labelSize = CVText.measureLabel(config: labelConfig, maxWidth: maxLabelWidth)
            textStackSubviewInfos.append(labelSize.asManualSubviewInfo)
        }

        let textStackMeasurement = ManualStackView.measure(config: textStackConfig,
                                                           measurementBuilder: measurementBuilder,
                                                           measurementKey: Self.measurementKey_textStack,
                                                           subviewInfos: textStackSubviewInfos)
        rootStackSubviewInfos.append(textStackMeasurement.measuredSize.asManualSubviewInfo)

        let rootStackMeasurement = ManualStackView.measure(config: rootStackConfig,
                                                           measurementBuilder: measurementBuilder,
                                                           measurementKey: Self.measurementKey_rootStack,
                                                           subviewInfos: rootStackSubviewInfos,
                                                           maxWidth: maxWidth)
        return rootStackMeasurement.measuredSize
    }
}

// MARK: -

private class PaymentPreviewViewAdapterSentHero: PaymentPreviewViewAdapter {

    let state: PaymentPreviewState

    init(state: PaymentPreviewState) {
        self.state = state
    }

    var rootStackConfig: ManualStackView.Config {
        ManualStackView.Config(axis: .vertical,
                               alignment: .fill,
                               spacing: 0,
                               layoutMargins: .zero)
    }

    var textStackConfig: ManualStackView.Config {
        return ManualStackView.Config(axis: .vertical,
                                      alignment: .leading,
                                      spacing: PaymentPreviewView.sentVSpacing,
                                      layoutMargins: PaymentPreviewView.sentHeroLayoutMargins)
    }

    func configureForRendering(paymentPreviewView: PaymentPreviewView,
                               hasAsymmetricalRounding: Bool,
                               cellMeasurement: CVCellMeasurement) {

        paymentPreviewView.backgroundColor = Theme.isDarkThemeEnabled ? .ows_gray75 : .ows_gray02

        var rootStackSubviews = [UIView]()

        let paymentPreviewImageView = paymentPreviewView.paymentPreviewImageView
        if let imageView = paymentPreviewImageView.configure(state: state) {
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            rootStackSubviews.append(imageView)
        } else {
            owsFailDebug("Could not load image.")
            rootStackSubviews.append(UIView.transparentSpacer())
        }

        let textStack = paymentPreviewView.textStack
        configureSentTextStack(paymentPreviewView: paymentPreviewView,
                               state: state,
                               textStack: textStack,
                               textStackConfig: textStackConfig,
                               cellMeasurement: cellMeasurement)
        rootStackSubviews.append(textStack)

        paymentPreviewView.configure(config: rootStackConfig,
                                  cellMeasurement: cellMeasurement,
                                  measurementKey: Self.measurementKey_rootStack,
                                  subviews: rootStackSubviews)
    }

    func measure(maxWidth: CGFloat,
                 measurementBuilder: CVCellMeasurement.Builder,
                 state: PaymentPreviewState) -> CGSize {

        guard let conversationStyle = state.conversationStyle else {
            owsFailDebug("Missing conversationStyle.")
            return .zero
        }

        var rootStackSubviewInfos = [ManualStackSubviewInfo]()

        var maxLabelWidth = (maxWidth -
                                (textStackConfig.layoutMargins.totalWidth +
                                    rootStackConfig.layoutMargins.totalWidth))
        maxLabelWidth = max(0, maxLabelWidth)

        let textStackSize = measureSentTextStack(state: state,
                                                 textStackConfig: textStackConfig,
                                                 measurementBuilder: measurementBuilder,
                                                 maxLabelWidth: maxLabelWidth)
        rootStackSubviewInfos.append(textStackSize.asManualSubviewInfo)

        let rootStackMeasurement = ManualStackView.measure(config: rootStackConfig,
                                                           measurementBuilder: measurementBuilder,
                                                           measurementKey: Self.measurementKey_rootStack,
                                                           subviewInfos: rootStackSubviewInfos,
                                                           maxWidth: maxWidth)
        return rootStackMeasurement.measuredSize
    }
}

// MARK: -

private class PaymentPreviewViewAdapterSent: PaymentPreviewViewAdapter {

    let state: PaymentPreviewState

    init(state: PaymentPreviewState) {
        self.state = state
    }

    var rootStackConfig: ManualStackView.Config {
        ManualStackView.Config(axis: .horizontal,
                               alignment: .center,
                               spacing: PaymentPreviewView.sentNonHeroHSpacing,
                               layoutMargins: PaymentPreviewView.sentNonHeroLayoutMargins)
    }

    var textStackConfig: ManualStackView.Config {
        return ManualStackView.Config(axis: .vertical,
                                      alignment: .leading,
                                      spacing: PaymentPreviewView.sentVSpacing,
                                      layoutMargins: .zero)
    }

    func configureForRendering(paymentPreviewView: PaymentPreviewView,
                               hasAsymmetricalRounding: Bool,
                               cellMeasurement: CVCellMeasurement) {

        paymentPreviewView.backgroundColor = Theme.isDarkThemeEnabled ? .ows_gray75 : .ows_gray02

        var rootStackSubviews = [UIView]()

        let textStack = paymentPreviewView.textStack
        configureSentTextStack(paymentPreviewView: paymentPreviewView,
                               state: state,
                               textStack: textStack,
                               textStackConfig: textStackConfig,
                               cellMeasurement: cellMeasurement)
        rootStackSubviews.append(textStack)

        paymentPreviewView.configure(config: rootStackConfig,
                                  cellMeasurement: cellMeasurement,
                                  measurementKey: Self.measurementKey_rootStack,
                                  subviews: rootStackSubviews)
    }

    func measure(maxWidth: CGFloat,
                 measurementBuilder: CVCellMeasurement.Builder,
                 state: PaymentPreviewState) -> CGSize {

        var maxLabelWidth = (maxWidth -
                                (textStackConfig.layoutMargins.totalWidth +
                                    rootStackConfig.layoutMargins.totalWidth))

        var rootStackSubviewInfos = [ManualStackSubviewInfo]()
        maxLabelWidth = max(0, maxLabelWidth)

        let textStackSize = measureSentTextStack(state: state,
                                                 textStackConfig: textStackConfig,
                                                 measurementBuilder: measurementBuilder,
                                                 maxLabelWidth: maxLabelWidth)
        rootStackSubviewInfos.append(textStackSize.asManualSubviewInfo)

        let rootStackMeasurement = ManualStackView.measure(config: rootStackConfig,
                                                           measurementBuilder: measurementBuilder,
                                                           measurementKey: Self.measurementKey_rootStack,
                                                           subviewInfos: rootStackSubviewInfos,
                                                           maxWidth: maxWidth)
        return rootStackMeasurement.measuredSize
    }
}

// MARK: -

private class PaymentPreviewViewAdapterSentWithDescription: PaymentPreviewViewAdapter {

    let state: PaymentPreviewState

    init(state: PaymentPreviewState) {
        self.state = state
    }

    var rootStackConfig: ManualStackView.Config {
        ManualStackView.Config(axis: .vertical,
                               alignment: .fill,
                               spacing: PaymentPreviewView.sentVSpacing,
                               layoutMargins: PaymentPreviewView.sentNonHeroLayoutMargins)
    }

    var titleStackConfig: ManualStackView.Config {
        return ManualStackView.Config(axis: .horizontal,
                                      alignment: .center,
                                      spacing: PaymentPreviewView.sentNonHeroHSpacing,
                                      layoutMargins: UIEdgeInsets(top: 0,
                                                                  left: 0,
                                                                  bottom: PaymentPreviewView.sentVSpacing,
                                                                  right: 0))
    }

    func configureForRendering(paymentPreviewView: PaymentPreviewView,
                               hasAsymmetricalRounding: Bool,
                               cellMeasurement: CVCellMeasurement) {

        paymentPreviewView.backgroundColor = Theme.isDarkThemeEnabled ? .ows_gray75 : .ows_gray02

        var titleStackSubviews = [UIView]()

        if let titleLabel = sentTitleLabel(state: state) {
            titleStackSubviews.append(titleLabel)
        } else {
            owsFailDebug("Text stack required")
        }

        var rootStackSubviews = [UIView]()

        let titleStack = paymentPreviewView.titleStack
        titleStack.configure(config: titleStackConfig,
                             cellMeasurement: cellMeasurement,
                             measurementKey: Self.measurementKey_titleStack,
                             subviews: titleStackSubviews)
        rootStackSubviews.append(titleStack)

        if let descriptionLabel = sentDescriptionLabel(state: state) {
            rootStackSubviews.append(descriptionLabel)
        } else {
            owsFailDebug("Description label required")
        }

        let domainLabel = sentDomainLabel(state: state)
        rootStackSubviews.append(domainLabel)

        paymentPreviewView.configure(config: rootStackConfig,
                                  cellMeasurement: cellMeasurement,
                                  measurementKey: Self.measurementKey_rootStack,
                                  subviews: rootStackSubviews)
    }

    func measure(maxWidth: CGFloat,
                 measurementBuilder: CVCellMeasurement.Builder,
                 state: PaymentPreviewState) -> CGSize {

        var maxRootLabelWidth = (maxWidth -
                                    (titleStackConfig.layoutMargins.totalWidth +
                                        rootStackConfig.layoutMargins.totalWidth))
        maxRootLabelWidth = max(0, maxRootLabelWidth)

        var maxTitleLabelWidth = maxRootLabelWidth

        var titleStackSubviewInfos = [ManualStackSubviewInfo]()

        maxTitleLabelWidth = max(0, maxTitleLabelWidth)

        if let labelConfig = sentTitleLabelConfig(state: state) {
            let labelSize = CVText.measureLabel(config: labelConfig, maxWidth: maxTitleLabelWidth)
            titleStackSubviewInfos.append(labelSize.asManualSubviewInfo)
        } else {
            owsFailDebug("Text stack required")
        }

        var rootStackSubviewInfos = [ManualStackSubviewInfo]()

        let titleStackMeasurement = ManualStackView.measure(config: titleStackConfig,
                                                            measurementBuilder: measurementBuilder,
                                                            measurementKey: Self.measurementKey_titleStack,
                                                            subviewInfos: titleStackSubviewInfos)
        rootStackSubviewInfos.append(titleStackMeasurement.measuredSize.asManualSubviewInfo)

        if let labelConfig = sentDescriptionLabelConfig(state: state) {
            let labelSize = CVText.measureLabel(config: labelConfig, maxWidth: maxRootLabelWidth)
            rootStackSubviewInfos.append(labelSize.asManualSubviewInfo)
        } else {
            owsFailDebug("Description label required")
        }

        do {
            let labelConfig = sentDomainLabelConfig(state: state)
            let labelSize = CVText.measureLabel(config: labelConfig, maxWidth: maxRootLabelWidth)
            rootStackSubviewInfos.append(labelSize.asManualSubviewInfo)
        }

        let rootStackMeasurement = ManualStackView.measure(config: rootStackConfig,
                                                           measurementBuilder: measurementBuilder,
                                                           measurementKey: Self.measurementKey_rootStack,
                                                           subviewInfos: rootStackSubviewInfos,
                                                           maxWidth: maxWidth)
        return rootStackMeasurement.measuredSize
    }
}

// MARK: -

private class PaymentPreviewImageView: CVImageView {
    fileprivate enum Rounding: UInt {
        case standard
        case asymmetrical
        case circular
    }

    fileprivate var rounding: Rounding = .standard {
        didSet {
            if rounding == .asymmetrical {
                layer.mask = asymmetricCornerMask
            } else {
                layer.mask = nil
            }
            updateMaskLayer()
        }
    }

    fileprivate var isHero = false {
        didSet {
            updateMaskLayer()
        }
    }

    // We only need to use a more complicated corner mask if we're
    // drawing asymmetric corners. This is an exceptional case to match
    // the input toolbar curve.
    private let asymmetricCornerMask = CAShapeLayer()

    private static let configurationIdCounter = AtomicUInt(0)
    private var configurationId: UInt = 0

    init() {
        super.init(frame: .zero)
    }

    @available(*, unavailable, message: "use other constructor instead.")
    required init?(coder aDecoder: NSCoder) {
        notImplemented()
    }

    public override func reset() {
        super.reset()

        rounding = .standard
        isHero = false
        configurationId = 0
    }

    override var bounds: CGRect {
        didSet {
            updateMaskLayer()
        }
    }

    override var frame: CGRect {
        didSet {
            updateMaskLayer()
        }
    }

    override var center: CGPoint {
        didSet {
            updateMaskLayer()
        }
    }

    private func updateMaskLayer() {
        let layerBounds = self.bounds
        let bigRounding: CGFloat = 14
        let smallRounding: CGFloat = 6

        switch rounding {
        case .standard:
            layer.cornerRadius = smallRounding
            layer.maskedCorners = isHero ? .top : .all
        case .circular:
            layer.cornerRadius = bounds.size.smallerAxis / 2
            layer.maskedCorners = .all
        case .asymmetrical:
            // This uses a more expensive layer mask to clip corners
            // with different radii.
            // This should only be used in the input toolbar so perf is
            // less of a concern here.
            owsAssertDebug(!isHero, "Link preview drafts never use hero images")

            let upperLeft = CGPoint(x: 0, y: 0)
            let upperRight = CGPoint(x: layerBounds.size.width, y: 0)
            let lowerRight = CGPoint(x: layerBounds.size.width, y: layerBounds.size.height)
            let lowerLeft = CGPoint(x: 0, y: layerBounds.size.height)

            let upperLeftRounding: CGFloat = CurrentAppContext().isRTL ? smallRounding : bigRounding
            let upperRightRounding: CGFloat = CurrentAppContext().isRTL ? bigRounding : smallRounding
            let lowerRightRounding = smallRounding
            let lowerLeftRounding = smallRounding

            let path = UIBezierPath()

            // It's sufficient to "draw" the rounded corners and not the edges that connect them.
            path.addArc(withCenter: upperLeft.offsetBy(dx: +upperLeftRounding).offsetBy(dy: +upperLeftRounding),
                        radius: upperLeftRounding,
                        startAngle: CGFloat.pi * 1.0,
                        endAngle: CGFloat.pi * 1.5,
                        clockwise: true)

            path.addArc(withCenter: upperRight.offsetBy(dx: -upperRightRounding).offsetBy(dy: +upperRightRounding),
                        radius: upperRightRounding,
                        startAngle: CGFloat.pi * 1.5,
                        endAngle: CGFloat.pi * 0.0,
                        clockwise: true)

            path.addArc(withCenter: lowerRight.offsetBy(dx: -lowerRightRounding).offsetBy(dy: -lowerRightRounding),
                        radius: lowerRightRounding,
                        startAngle: CGFloat.pi * 0.0,
                        endAngle: CGFloat.pi * 0.5,
                        clockwise: true)

            path.addArc(withCenter: lowerLeft.offsetBy(dx: +lowerLeftRounding).offsetBy(dy: -lowerLeftRounding),
                        radius: lowerLeftRounding,
                        startAngle: CGFloat.pi * 0.5,
                        endAngle: CGFloat.pi * 1.0,
                        clockwise: true)

            asymmetricCornerMask.path = path.cgPath
        }
    }

    // MARK: -

    func configureForDraft(state: PaymentPreviewState,
                           hasAsymmetricalRounding: Bool) -> UIImageView? {
        guard state.isLoaded() else {
            owsFailDebug("State not loaded.")
            return nil
        }
        self.rounding = hasAsymmetricalRounding ? .asymmetrical : .standard
        let configurationId = Self.configurationIdCounter.increment()
        self.configurationId = configurationId
        return self
    }

    fileprivate static let mediaCache = LRUCache<String, NSObject>(maxSize: 2,
                                                                   shouldEvacuateInBackground: true)

    func configure(state: PaymentPreviewState,
                   rounding roundingParam: PaymentPreviewImageView.Rounding? = nil) -> UIImageView? {
        guard state.isLoaded() else {
            owsFailDebug("State not loaded.")
            return nil
        }
        self.rounding = roundingParam ?? .standard
        let isHero = PaymentPreviewView.sentIsHero(state: state)
        self.isHero = isHero
        let configurationId = Self.configurationIdCounter.increment()
        self.configurationId = configurationId
        let thumbnailQuality: AttachmentThumbnailQuality = isHero ? .medium : .small

        return self
    }
}

// MARK: -

public extension CGPoint {
    func offsetBy(dx: CGFloat = 0.0, dy: CGFloat = 0.0) -> CGPoint {
        return offsetBy(CGVector(dx: dx, dy: dy))
    }

    func offsetBy(_ vector: CGVector) -> CGPoint {
        return CGPoint(x: x + vector.dx, y: y + vector.dy)
    }
}

// MARK: -

public extension ManualLayoutView {
    func addSubviewAsBottomStroke(_ subview: UIView,
                                  layoutMargins: UIEdgeInsets = .zero) {
        addSubview(subview) { view in
            var subviewFrame = view.bounds.inset(by: layoutMargins)
            subviewFrame.size.height = CGHairlineWidth()
            subviewFrame.y = view.bounds.height - (subviewFrame.height +
                                                    layoutMargins.bottom)
            subview.frame = subviewFrame
        }
    }
}
