#if canImport(UIKit)
import UIKit

/// Opt-in default UI for modal / banner in-app messages.
/// Started when `OpenCDPConfig.enableInAppAutoPresent` is true.
final class InAppAutoPresenter {
    private weak var openCDP: OpenCDP?
    private let config: OpenCDPConfig
    private var bannerView: UIView?
    private var presenting = false
    private var started = false

    init(openCDP: OpenCDP, config: OpenCDPConfig) {
        self.openCDP = openCDP
        self.config = config
    }

    func start() {
        guard !started else { return }
        started = true
        openCDP?.addInAppListener { [weak self] message in
            DispatchQueue.main.async {
                self?.present(message)
            }
        }
        if config.debug {
            NSLog("[OpenCDP] InAppAutoPresenter started")
        }
    }

    func stop() {
        started = false
        dismissBanner()
        // Listeners are cleared when the in-app manager is disposed on re-init.
    }

    private func present(_ message: InAppMessage) {
        switch message.renderType {
        case .modal:
            showModal(message)
        case .banner:
            showBanner(message)
        case .inline, .inboxCard, .unknown:
            if config.debug {
                NSLog(
                    "[OpenCDP] Skipping auto-present for \(message.renderType) delivery=\(message.deliveryId)"
                )
            }
        }
    }

    private func showModal(_ message: InAppMessage) {
        guard let top = Self.topViewController(), !presenting else { return }
        presenting = true

        Task { await openCDP?.trackInAppImpression(message) }

        let alert = UIAlertController(
            title: message.title ?? "Message",
            message: message.body,
            preferredStyle: .alert
        )

        if message.ctas.isEmpty {
            alert.addAction(UIAlertAction(title: "Close", style: .cancel) { [weak self] _ in
                Task { await self?.openCDP?.trackInAppDismiss(message, reason: .userClose) }
                self?.presenting = false
            })
        } else {
            let primary = message.ctas[0]
            alert.addAction(UIAlertAction(title: primary.label, style: .default) { [weak self] _ in
                Task { await self?.openCDP?.trackInAppClick(message, actionId: primary.id) }
                self?.presenting = false
            })
            alert.addAction(UIAlertAction(title: "Close", style: .cancel) { [weak self] _ in
                Task { await self?.openCDP?.trackInAppDismiss(message, reason: .userClose) }
                self?.presenting = false
            })
        }

        top.present(alert, animated: true)
    }

    private func showBanner(_ message: InAppMessage) {
        guard let window = Self.keyWindow() else { return }
        dismissBanner()

        Task { await openCDP?.trackInAppImpression(message) }

        let banner = UIView()
        banner.backgroundColor = .white
        banner.layer.cornerRadius = 12
        banner.layer.shadowOpacity = 0.12
        banner.layer.shadowRadius = 8
        banner.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false

        if let title = message.title, !title.isEmpty {
            let label = UILabel()
            label.text = title
            label.font = .boldSystemFont(ofSize: 14)
            stack.addArrangedSubview(label)
        }
        if let body = message.body, !body.isEmpty {
            let label = UILabel()
            label.text = body
            label.font = .systemFont(ofSize: 12)
            label.numberOfLines = 2
            stack.addArrangedSubview(label)
        }

        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 8
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        row.addArrangedSubview(stack)

        if let primary = message.ctas.first {
            let button = UIButton(type: .system)
            button.setTitle(primary.label, for: .normal)
            button.addAction(UIAction { [weak self] _ in
                Task { await self?.openCDP?.trackInAppClick(message, actionId: primary.id) }
                self?.dismissBanner()
            }, for: .touchUpInside)
            row.addArrangedSubview(button)
        }

        let close = UIButton(type: .system)
        close.setTitle("✕", for: .normal)
        close.addAction(UIAction { [weak self] _ in
            Task { await self?.openCDP?.trackInAppDismiss(message, reason: .userClose) }
            self?.dismissBanner()
        }, for: .touchUpInside)
        row.addArrangedSubview(close)

        banner.addSubview(row)
        window.addSubview(banner)
        NSLayoutConstraint.activate([
            banner.leadingAnchor.constraint(equalTo: window.safeAreaLayoutGuide.leadingAnchor, constant: 12),
            banner.trailingAnchor.constraint(equalTo: window.safeAreaLayoutGuide.trailingAnchor, constant: -12),
            banner.topAnchor.constraint(equalTo: window.safeAreaLayoutGuide.topAnchor, constant: 8),
            row.leadingAnchor.constraint(equalTo: banner.leadingAnchor, constant: 14),
            row.trailingAnchor.constraint(equalTo: banner.trailingAnchor, constant: -14),
            row.topAnchor.constraint(equalTo: banner.topAnchor, constant: 10),
            row.bottomAnchor.constraint(equalTo: banner.bottomAnchor, constant: -10),
        ])
        bannerView = banner

        DispatchQueue.main.asyncAfter(deadline: .now() + 6) { [weak self] in
            guard let self, self.bannerView === banner else { return }
            Task { await self.openCDP?.trackInAppDismiss(message, reason: .expired) }
            self.dismissBanner()
        }
    }

    private func dismissBanner() {
        bannerView?.removeFromSuperview()
        bannerView = nil
    }

    private static func keyWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }

    private static func topViewController(
        base: UIViewController? = keyWindow()?.rootViewController
    ) -> UIViewController? {
        if let nav = base as? UINavigationController {
            return topViewController(base: nav.visibleViewController)
        }
        if let tab = base as? UITabBarController {
            return topViewController(base: tab.selectedViewController)
        }
        if let presented = base?.presentedViewController {
            return topViewController(base: presented)
        }
        return base
    }
}
#endif
