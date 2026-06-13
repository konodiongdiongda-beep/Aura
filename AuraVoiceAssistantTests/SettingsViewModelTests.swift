import XCTest
@testable import AuraVoiceAssistant

@MainActor
final class SettingsViewModelTests: XCTestCase {
    func testDefaultsToEnglishSettingsCopy() {
        let viewModel = SettingsViewModel()

        XCTAssertEqual(viewModel.language, .english)
        XCTAssertEqual(viewModel.text.settingsTitle, "Settings")
        XCTAssertEqual(viewModel.azureStatusText, "Missing key or region")
    }

    func testSwitchesSettingsCopyToChineseAndBack() {
        let viewModel = SettingsViewModel()

        viewModel.setLanguage(.chinese)

        XCTAssertEqual(viewModel.text.settingsTitle, "设置")
        XCTAssertEqual(viewModel.text.configurationSubtitle, "配置")
        XCTAssertEqual(viewModel.azureStatusText, "缺少密钥或区域")

        viewModel.setLanguage(.english)

        XCTAssertEqual(viewModel.text.settingsTitle, "Settings")
        XCTAssertEqual(viewModel.azureStatusText, "Missing key or region")
    }
}
