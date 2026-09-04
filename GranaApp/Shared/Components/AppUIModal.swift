import SwiftUI

public enum Modal {
    public enum SheetSize {
        public static let compactWidth: CGFloat = 460
        public static let medium = CGSize(width: 620, height: 520)

        public static func large(in hostSize: CGSize) -> CGSize {
            let minimumWidth: CGFloat = 840
            let minimumHeight: CGFloat = 520
            let widthRatio: CGFloat = 0.82
            let heightRatio: CGFloat = 0.84
            let horizontalInset = Theme.Spacing.xl * 2
            let verticalInset = Theme.Spacing.xl * 2

            guard hostSize.width > 0, hostSize.height > 0 else {
                return CGSize(width: minimumWidth, height: minimumHeight)
            }

            let availableWidth = max(minimumWidth, hostSize.width - horizontalInset)
            let availableHeight = max(minimumHeight, hostSize.height - verticalInset)
            let proportionalWidth = max(minimumWidth, hostSize.width * widthRatio)
            let proportionalHeight = max(minimumHeight, hostSize.height * heightRatio)

            return CGSize(
                width: min(availableWidth, proportionalWidth),
                height: min(availableHeight, proportionalHeight)
            )
        }
    }
}
