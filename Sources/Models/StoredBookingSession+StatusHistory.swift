import Foundation

// Booking lifecycle views use this helper to derive a fallback timestamp when
// a dedicated lifecycle timestamp is unavailable. Keep it on the session model
// so every booking surface uses the same status-history semantics.
extension StoredBookingSession {
    func latestStatusTimestamp(matching statuses: Set<String>) -> String? {
        let normalizedStatuses = Set(
            statuses.map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            }
        )

        return orderedStatusHistory
            .filter {
                normalizedStatuses.contains(
                    $0.newStatus.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                )
            }
            .last?
            .createdAt
    }
}
