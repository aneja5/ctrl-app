import ManagedSettings
import ManagedSettingsUI
import UIKit

class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    // MARK: - App Shielding

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        return ShieldConfiguration(
            backgroundBlurStyle: .systemThickMaterialDark,
            backgroundColor: UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 0.95),
            icon: UIImage(systemName: "hand.raised.fill"),
            title: ShieldConfiguration.Label(
                text: "App Blocked",
                color: .white
            ),
            subtitle: ShieldConfiguration.Label(
                text: "Tap your CTRL token to unlock",
                color: UIColor(white: 0.7, alpha: 1.0)
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "OK",
                color: UIColor(red: 0, green: 0.72, blue: 0.58, alpha: 1.0)
            ),
            primaryButtonBackgroundColor: UIColor(white: 0.2, alpha: 1.0),
            secondaryButtonLabel: nil
        )
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        return configuration(shielding: application)
    }

    // MARK: - Web Domain Shielding

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        return ShieldConfiguration(
            backgroundBlurStyle: .systemThickMaterialDark,
            backgroundColor: UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 0.95),
            icon: UIImage(systemName: "globe"),
            title: ShieldConfiguration.Label(
                text: "Website Blocked",
                color: .white
            ),
            subtitle: ShieldConfiguration.Label(
                text: "Tap your CTRL token to unlock",
                color: UIColor(white: 0.7, alpha: 1.0)
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "OK",
                color: UIColor(red: 0, green: 0.72, blue: 0.58, alpha: 1.0)
            ),
            primaryButtonBackgroundColor: UIColor(white: 0.2, alpha: 1.0),
            secondaryButtonLabel: nil
        )
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        return configuration(shielding: webDomain)
    }
}
