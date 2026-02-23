import Foundation

enum CalendarHelper {
    /// Monday-first calendar for consistent week boundaries (Mon–Sun).
    /// Use this everywhere week boundaries are calculated so that
    /// Sunday falls at the END of a Mon–Sun week, not the start.
    static var mondayFirst: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday
        return cal
    }
}
