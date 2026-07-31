import AppKit

final class SettingsViewController: NSViewController {
    private enum SliderKind: String {
        case opacity
        case grainSize
        case intensity
    }

    private let model: AppModel
    private let enabledToggle = NSSwitch()
    private let modeControl = NSSegmentedControl(
        labels: GrainMode.allCases.map(\.title),
        trackingMode: .selectOne,
        target: nil,
        action: nil
    )
    private let colorControl = NSSegmentedControl(
        labels: GrainColorMode.allCases.map(\.title),
        trackingMode: .selectOne,
        target: nil,
        action: nil
    )
    private let opacitySlider = NSSlider()
    private let grainSizeSlider = NSSlider()
    private let intensitySlider = NSSlider()
    private let seedLabel = NSTextField(labelWithString: "")
    private let screenshotToggle = NSSwitch()
    private let loginToggle = NSSwitch()
    private let loginMessage = NSTextField(wrappingLabelWithString: "")
    private let content = NSStackView()
    private var valueLabels: [SliderKind: NSTextField] = [:]

    init(model: AppModel) {
        self.model = model
        super.init(nibName: nil, bundle: nil)
        preferredContentSize = NSSize(width: 320, height: 384)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView()

        content.orientation = .vertical
        content.alignment = .leading
        content.spacing = 9
        content.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(content)

        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            content.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            content.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            content.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -16),
        ])

        content.addArrangedSubview(makeHeader())
        content.addArrangedSubview(makeModeRow())
        content.addArrangedSubview(
            makeSliderRow(
                title: "Opacity",
                kind: .opacity,
                slider: opacitySlider,
                range: GrainSettings.opacityRange
            )
        )
        content.addArrangedSubview(
            makeSliderRow(
                title: "Grain size",
                kind: .grainSize,
                slider: grainSizeSlider,
                range: GrainSettings.grainSizeRange
            )
        )
        content.addArrangedSubview(
            makeSliderRow(
                title: "Intensity",
                kind: .intensity,
                slider: intensitySlider,
                range: GrainSettings.intensityRange
            )
        )
        content.addArrangedSubview(makeColorRow())
        content.addArrangedSubview(makeRerollRow())

        screenshotToggle.target = self
        screenshotToggle.action = #selector(screenshotVisibilityChanged)
        screenshotToggle.setAccessibilityLabel("Show in Screenshot UI")
        screenshotToggle.toolTip = "Keep grain visible while macOS Screenshot is open."
        content.addArrangedSubview(makeToggleRow(title: "Show in Screenshot UI", toggle: screenshotToggle))
        content.addArrangedSubview(NSBox.separator())

        loginToggle.target = self
        loginToggle.action = #selector(loginItemChanged)
        loginToggle.setAccessibilityLabel("Launch at Login")
        content.addArrangedSubview(makeToggleRow(title: "Launch at Login", toggle: loginToggle))

        loginMessage.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        loginMessage.textColor = .secondaryLabelColor
        loginMessage.maximumNumberOfLines = 2
        content.addArrangedSubview(loginMessage)

        let quitRow = NSStackView()
        quitRow.orientation = .horizontal
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let quitButton = NSButton(title: "Quit ScreenGrain", target: self, action: #selector(quit))
        quitButton.keyEquivalent = "q"
        quitRow.addArrangedSubview(spacer)
        quitRow.addArrangedSubview(quitButton)
        stretch(quitRow)
        content.addArrangedSubview(quitRow)

        refresh()
    }

    func refresh() {
        guard isViewLoaded else { return }
        let settings = model.settings
        enabledToggle.state = settings.enabled ? .on : .off
        modeControl.selectedSegment = settings.mode == .noise ? 0 : 1
        colorControl.selectedSegment = settings.colorMode == .monochrome ? 0 : 1

        opacitySlider.doubleValue = settings.opacity
        grainSizeSlider.doubleValue = settings.grainSize
        intensitySlider.doubleValue = settings.intensity
        updateValueLabels()

        seedLabel.stringValue = String(
            format: "%016llX",
            settings.seed
        )
        screenshotToggle.state = settings.showsInScreenshotUI ? .on : .off
        loginToggle.state = settings.launchAtLogin ? .on : .off
        loginMessage.stringValue = model.loginItemMessage ?? ""
        loginMessage.isHidden = model.loginItemMessage == nil
        content.layoutSubtreeIfNeeded()
        preferredContentSize = NSSize(
            width: 320,
            height: ceil(content.fittingSize.height + 32)
        )
    }

    private func makeHeader() -> NSView {
        let title = NSTextField(labelWithString: "ScreenGrain")
        title.font = .boldSystemFont(ofSize: NSFont.systemFontSize)

        enabledToggle.target = self
        enabledToggle.action = #selector(enabledChanged)
        enabledToggle.setAccessibilityLabel("Enabled")

        let row = NSStackView(views: [
            title,
            NSView(),
            makeToggleGroup(title: "Enabled", toggle: enabledToggle),
        ])
        row.orientation = .horizontal
        row.alignment = .centerY
        stretch(row)
        return row
    }

    private func makeModeRow() -> NSView {
        modeControl.target = self
        modeControl.action = #selector(modeChanged)
        stretch(modeControl)
        return modeControl
    }

    private func makeColorRow() -> NSView {
        colorControl.target = self
        colorControl.action = #selector(colorModeChanged)
        colorControl.translatesAutoresizingMaskIntoConstraints = false
        colorControl.widthAnchor.constraint(equalToConstant: 184).isActive = true

        let label = NSTextField(labelWithString: "Grain color")
        label.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        let row = NSStackView(views: [label, NSView(), colorControl])
        row.orientation = .horizontal
        row.alignment = .centerY
        stretch(row)
        return row
    }

    private func makeToggleRow(title: String, toggle: NSSwitch) -> NSView {
        let row = NSStackView(views: [
            NSTextField(labelWithString: title),
            NSView(),
            toggle,
        ])
        row.orientation = .horizontal
        row.alignment = .centerY
        stretch(row)
        return row
    }

    private func makeToggleGroup(title: String, toggle: NSSwitch) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        let group = NSStackView(views: [label, toggle])
        group.orientation = .horizontal
        group.alignment = .centerY
        group.spacing = 6
        return group
    }

    private func makeSliderRow(
        title: String,
        kind: SliderKind,
        slider: NSSlider,
        range: ClosedRange<Double>
    ) -> NSView {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        let valueLabel = NSTextField(labelWithString: "")
        valueLabel.font = .monospacedDigitSystemFont(
            ofSize: NSFont.smallSystemFontSize,
            weight: .regular
        )
        valueLabel.textColor = .secondaryLabelColor
        valueLabels[kind] = valueLabel

        let labels = NSStackView(views: [titleLabel, NSView(), valueLabel])
        labels.orientation = .horizontal
        stretch(labels)

        slider.minValue = range.lowerBound
        slider.maxValue = range.upperBound
        slider.identifier = NSUserInterfaceItemIdentifier(kind.rawValue)
        slider.target = self
        slider.action = #selector(sliderChanged)
        slider.isContinuous = true
        stretch(slider)

        let stack = NSStackView(views: [labels, slider])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 3
        stretch(stack)
        return stack
    }

    private func makeRerollRow() -> NSView {
        let button = NSButton(
            title: "Re-roll",
            image: NSImage(systemSymbolName: "dice", accessibilityDescription: nil)!,
            target: self,
            action: #selector(reroll)
        )
        button.imagePosition = .imageLeading
        seedLabel.font = .monospacedDigitSystemFont(
            ofSize: NSFont.smallSystemFontSize,
            weight: .regular
        )
        seedLabel.textColor = .secondaryLabelColor

        let row = NSStackView(views: [button, NSView(), seedLabel])
        row.orientation = .horizontal
        row.alignment = .centerY
        stretch(row)
        return row
    }

    private func updateValueLabels() {
        valueLabels[.opacity]?.stringValue =
            "\(Int((opacitySlider.doubleValue * 100).rounded()))%"
        valueLabels[.grainSize]?.stringValue = String(
            format: "%.1f×",
            grainSizeSlider.doubleValue
        )
        valueLabels[.intensity]?.stringValue =
            "\(Int((intensitySlider.doubleValue * 100).rounded()))%"
    }

    private func stretch(_ view: NSView) {
        view.translatesAutoresizingMaskIntoConstraints = false
        view.widthAnchor.constraint(equalToConstant: 288).isActive = true
    }

    @objc private func enabledChanged() {
        model.set(\.enabled, to: enabledToggle.state == .on)
    }

    @objc private func modeChanged() {
        model.set(\.mode, to: modeControl.selectedSegment == 0 ? .noise : .filmGrain)
    }

    @objc private func colorModeChanged() {
        model.set(
            \.colorMode,
            to: colorControl.selectedSegment == 0 ? .monochrome : .color
        )
    }

    @objc private func sliderChanged(_ sender: NSSlider) {
        guard
            let identifier = sender.identifier?.rawValue,
            let kind = SliderKind(rawValue: identifier)
        else { return }

        switch kind {
        case .opacity:
            model.set(\.opacity, to: sender.doubleValue)
        case .grainSize:
            model.set(\.grainSize, to: sender.doubleValue)
        case .intensity:
            model.set(\.intensity, to: sender.doubleValue)
        }
        updateValueLabels()
    }

    @objc private func reroll() {
        model.reroll()
    }

    @objc private func screenshotVisibilityChanged() {
        model.set(\.showsInScreenshotUI, to: screenshotToggle.state == .on)
    }

    @objc private func loginItemChanged() {
        model.setLaunchAtLogin(loginToggle.state == .on)
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}

private extension NSBox {
    static func separator() -> NSBox {
        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.widthAnchor.constraint(equalToConstant: 288).isActive = true
        return separator
    }
}
