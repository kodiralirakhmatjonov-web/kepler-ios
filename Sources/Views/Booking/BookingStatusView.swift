import SwiftUI

/// Compatibility entry point kept for older navigation links.
/// The canonical booking-status experience is PilgrimCheckoutView.
struct BookingStatusView: View {
    let bookingID: String

    var body: some View {
        PilgrimCheckoutView(bookingID: bookingID, presentation: .screen)
    }
}
