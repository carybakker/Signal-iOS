//
//  Copyright (c) 2021 Open Whisper Systems. All rights reserved.
//

import Foundation

public class CVComponentPaymentPreview: CVComponentBase, CVComponent {

    public var componentKey: CVComponentKey { .paymentPreview }

    private let paymentPreviewState: CVComponentState.PaymentPreview

    init(itemModel: CVItemModel,
         paymentPreviewState: CVComponentState.PaymentPreview) {
        self.paymentPreviewState = paymentPreviewState

        super.init(itemModel: itemModel)
    }

    public func buildComponentView(componentDelegate: CVComponentDelegate) -> CVComponentView {
        CVComponentViewPaymentPreview()
    }

    public func configureForRendering(componentView componentViewParam: CVComponentView,
                                      cellMeasurement: CVCellMeasurement,
                                      componentDelegate: CVComponentDelegate) {
        guard let componentView = componentViewParam as? CVComponentViewPaymentPreview else {
            owsFailDebug("Unexpected componentView.")
            componentViewParam.reset()
            return
        }

        let paymentPreviewView = componentView.paymentPreviewView
        paymentPreviewView.configureForRendering(state: paymentPreviewState.state,
                                              isDraft: false,
                                              hasAsymmetricalRounding: false,
                                              cellMeasurement: cellMeasurement)
    }

    private var stackConfig: CVStackViewConfig {
        CVStackViewConfig(axis: .vertical,
                          alignment: .fill,
                          spacing: 0,
                          layoutMargins: .zero)
    }

    public func measure(maxWidth: CGFloat, measurementBuilder: CVCellMeasurement.Builder) -> CGSize {
        owsAssertDebug(maxWidth > 0)

        let maxWidth = min(maxWidth, conversationStyle.maxMediaMessageWidth)
        return PaymentPreviewView.measure(maxWidth: maxWidth,
                                       measurementBuilder: measurementBuilder,
                                       state: paymentPreviewState.state,
                                       isDraft: false)
    }

    // MARK: - Events

    public override func handleTap(sender: UITapGestureRecognizer,
                                   componentDelegate: CVComponentDelegate,
                                   componentView: CVComponentView,
                                   renderItem: CVRenderItem) -> Bool {

        componentDelegate.cvc_didTapPaymentPreview(paymentPreviewState.paymentPreview)
        return true
    }

    // MARK: -

    // Used for rendering some portion of an Conversation View item.
    // It could be the entire item or some part thereof.
    public class CVComponentViewPaymentPreview: NSObject, CVComponentView {

        fileprivate let paymentPreviewView = PaymentPreviewView(draftDelegate: nil)

        public var isDedicatedCellView = false

        public var rootView: UIView {
            paymentPreviewView
        }

        public func setIsCellVisible(_ isCellVisible: Bool) {}

        public func reset() {
            paymentPreviewView.reset()
        }

    }
}
