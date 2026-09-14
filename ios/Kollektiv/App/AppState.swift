import Observation
import SwiftUI

enum AppTab: Hashable { case house, chat, week }

@Observable
@MainActor
final class AppState {
    var selectedTab: AppTab = .house
    var composerDraft: String = ""
    /// Set when the member explicitly tapped an "@House" affordance; cleared after sending.
    var mentionHouse: Bool = false
    var presentedDinnerDate: LocalDate? = nil
    var showChores: Bool = false
}
