import SwiftUI

struct AppUIPreviewSurface<Content: View>: View {
    private let title: String?
    @ViewBuilder private let content: () -> Content

    init(
        title: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.content = content
    }

    var body: some View {
        ZStack {
            GranaBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    if let title {
                        Text(title)
                            .font(Theme.Typography.title3)
                            .foregroundStyle(Theme.Palette.ink)
                    }

                    content()
                }
                .padding(Theme.Spacing.xl)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(minWidth: 720, minHeight: 520)
    }
}
