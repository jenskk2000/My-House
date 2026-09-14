import Observation
import SwiftUI

enum AppTab: Hashable { case house, chat, week }

@Observable
@MainActor
final class AppState {
    var selectedTab: AppTab = .house
    var composerDraft: String = ""
    var presentedDinnerDate: LocalDate? = nil
    var showChores: Bool = false
}
