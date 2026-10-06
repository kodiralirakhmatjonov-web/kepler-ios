import SwiftUI

/// Flight First starts after the traveler has already chosen airfare in the Flights tab.
/// It deliberately skips the generic TripBuilder flight step and enters the shared
/// package engine at Primary Hotels, while preserving the selected fare, dates, party
/// and Makkah/Madinah scope in JourneyStore.
struct FlightFirstPackageFlowView: View {
    var body: some View {
        PrimaryHotelView(entryMode: .flightFirst)
    }
}
