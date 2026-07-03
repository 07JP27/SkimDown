import CoreGraphics

enum TableOfContentsPlacement {
    static func leadingOffset(
        contentRight: CGFloat?,
        containerWidth: CGFloat,
        paneWidth: CGFloat,
        trailingInset: CGFloat,
        gutter: CGFloat
    ) -> CGFloat {
        let trailingLeading = max(0, containerWidth - trailingInset - paneWidth)
        guard let contentRight, contentRight.isFinite, contentRight > 0 else {
            return trailingLeading
        }

        return max(0, min(contentRight + gutter, trailingLeading))
    }
}

enum PreviewContentLayout {
    private static let minimumInlinePadding: CGFloat = 40
    private static let preferredInlinePaddingRatio: CGFloat = 0.08
    private static let maximumInlinePadding: CGFloat = 120
    private static let contentMaxWidthInRem: CGFloat = 92

    static func estimatedContentRight(
        containerWidth: CGFloat,
        fontSize: CGFloat,
        reservedTrailingWidth: CGFloat
    ) -> CGFloat {
        let leftPadding = inlinePadding(containerWidth: containerWidth)
        let rightPadding = max(leftPadding, reservedTrailingWidth)
        let bodyContentWidth = max(0, containerWidth - leftPadding - rightPadding)
        let contentWidth = min(bodyContentWidth, contentMaxWidthInRem * fontSize)
        let leadingMargin = max(0, (bodyContentWidth - contentWidth) / 2)
        return leftPadding + leadingMargin + contentWidth
    }

    private static func inlinePadding(containerWidth: CGFloat) -> CGFloat {
        min(max(containerWidth * preferredInlinePaddingRatio, minimumInlinePadding), maximumInlinePadding)
    }
}
