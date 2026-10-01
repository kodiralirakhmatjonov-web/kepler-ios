import SwiftUI

struct IumrahActionConfirmationSheet: View {
    @Environment(\.dismiss) private var dismiss

    let imageAsset: String
    let title: String
    let message: String
    let confirmTitle: String
    let cancelTitle: String
    var confirmColor: Color = .red
    let onConfirm: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Image(imageAsset)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 188)
                .clipped()

            VStack(alignment: .leading, spacing: 14) {
                Text(title)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .tracking(-0.45)
                    .fixedSize(horizontal: false, vertical: true)

                Text(message)
                    .font(.system(size: 15.5, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    Button {
                        IumrahHaptics.selection()
                        dismiss()
                    } label: {
                        Text(cancelTitle)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .foregroundStyle(.primary)
                            .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button(role: .destructive) {
                        IumrahHaptics.error()
                        onConfirm()
                        dismiss()
                    } label: {
                        Text(confirmTitle)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .foregroundStyle(.white)
                            .background(confirmColor, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 4)
            }
            .padding(20)
        }
        .background(Color.iumrahPageBackground)
        .presentationDetents([.height(430)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(30)
    }
}
