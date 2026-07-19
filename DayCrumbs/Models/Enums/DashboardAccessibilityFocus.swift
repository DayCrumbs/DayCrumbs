import Foundation

/// VoiceOver destinations owned by the Dashboard view hierarchy.
///
/// Keeping this contract in the UI layer prevents presentation focus from
/// leaking into generation state or service orchestration.
enum DashboardAccessibilityFocus: Hashable {
    case insight
    case range
    case trigger(String)
    case triggerDialogTitle
    case emptyState
    case error
}
