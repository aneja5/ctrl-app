import Foundation

// MARK: - Focus Schedule

struct FocusSchedule: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String                    // "morning focus", "sleep mode"
    var modeId: UUID                    // links to BlockingMode
    var startTime: DateComponents       // hour + minute only
    var endTime: DateComponents         // hour + minute only
    var repeatDays: Set<Int>            // 1=Sun, 2=Mon, ..., 7=Sat (Calendar weekday)
    var requireNFCToEnd: Bool = false   // if true, shields stay until NFC tap
    var isEnabled: Bool = true          // toggle on/off without deleting

    init(name: String, modeId: UUID, startTime: DateComponents, endTime: DateComponents, repeatDays: Set<Int>) {
        self.name = name
        self.modeId = modeId
        self.startTime = startTime
        self.endTime = endTime
        self.repeatDays = repeatDays
    }

    // MARK: - Display Helpers

    /// Format time components as "9:00 AM" style string
    static func formatTime(_ components: DateComponents) -> String {
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        let calendar = Calendar.current
        var dc = DateComponents()
        dc.hour = hour
        dc.minute = minute
        guard let date = calendar.date(from: dc) else {
            return "\(hour):\(String(format: "%02d", minute))"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date).lowercased()
    }

    /// Short time range string: "9:00 am – 5:00 pm"
    var timeRangeString: String {
        "\(Self.formatTime(startTime)) – \(Self.formatTime(endTime))"
    }

    /// Day letters for display
    static let dayLetters: [(weekday: Int, letter: String)] = [
        (2, "M"), (3, "T"), (4, "W"), (5, "T"), (6, "F"), (7, "S"), (1, "S")
    ]

    /// Whether this schedule crosses midnight (end time is before start time)
    var crossesMidnight: Bool {
        let startMinutes = (startTime.hour ?? 0) * 60 + (startTime.minute ?? 0)
        let endMinutes = (endTime.hour ?? 0) * 60 + (endTime.minute ?? 0)
        return endMinutes <= startMinutes
    }

    /// Duration in minutes (accounts for midnight crossing)
    var durationMinutes: Int {
        let startMinutes = (startTime.hour ?? 0) * 60 + (startTime.minute ?? 0)
        let endMinutes = (endTime.hour ?? 0) * 60 + (endTime.minute ?? 0)
        if endMinutes > startMinutes {
            return endMinutes - startMinutes
        } else {
            return (24 * 60 - startMinutes) + endMinutes
        }
    }

    /// Minimum duration required by DeviceActivityCenter (15 minutes)
    static let minimumDurationMinutes = 15
}

// ScheduleConfig removed — schedule metadata now stored as simple key-value pairs
// in shared UserDefaults (schedule_modeId_<id>, schedule_requireNFC_<id>, etc.)
