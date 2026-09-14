import Testing
@testable import Kollektiv

@Suite struct SmokeTests {
    @Test func themeColoursExist() {
        _ = Theme.cobalt
        _ = Theme.butter
    }
}
