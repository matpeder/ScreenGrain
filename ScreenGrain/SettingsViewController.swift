import AppKit

final class SettingsViewController: NSViewController {
    private enum SliderKind: String {
        case opacity
        case grainSize
        case intensity
        case character
    }

    private let model: AppModel
    private let enabledToggle = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let modeControl = NSSegmentedControl(
        labels: GrainMode.allCases.map(\.title),
        trackingMode: .selectOne,
        target: nil,
        action: nil
    )
    private let presetControl = NSPopUpButton()
    private let opacitySlider = NSSlider()
    private let grainSizeSlider = NSSlider()
    private let intensitySlider = NSSlider()
    private let characterSlider = NSSlider()
    private let seedLabel = NSTextField(labelWithString: "")
    private let loginToggle = NSButton(checkboxWithTitle: "Launch at Login", target: nil, action: nil)
    private let loginMessage = NSTextField(wrappingLabelWithString: "")
    private var valueLabels: [SliderKind: NSTextField] = [:]

    init(model: AppModel) {
        self.model = model
        super.init(nibName: nil, bundle: nil)
        preferredContentSize = NSSize(width: 320, height: 510)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView()

        let content = NSStackView()
        content.orientation = .vertical
        content.alignment = .leading
        content.spacing = 13
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
        content.addArrangedSubview(makePresetRow())
        content.addArrangedSubview(
            makeSliderRow(
                title: "Opacity",
                kind: .opacity,
                slider: opacitySlider,
                range: 0.02...0.25
            )
        )
        content.addArrangedSubview(
            makeSliderRow(
                title: "Grain size",
                kind: .grainSize,
                slider: grainSizeSlider,
                range: 0.65...2.5
            )
        )
        content.addArrangedSubview(
            makeSliderRow(
                title: "Intensity",
                kind: .intensity,
                slider: intensitySlider,
                range: 0.2...1
            )
        )
        content.addArrangedSubview(
            makeSliderRow(
                title: "Character",
                kind: .character,
                slider: characterSlider,
                range: 0...1
            )
        )
        content.addArrangedSubview(makeRerollRow())
        content.addArrangedSubview(NSBox.separator())

        loginToggle.target = self
        loginToggle.action = #selector(loginItemChanged)
        content.addArrangedSubview(loginToggle)

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

        if let presetIndex = GrainPreset.all.firstIndex(where: { $0.id == settings.presetID }) {
            presetControl.selectItem(at: presetIndex + 1)
        } else {
            presetControl.selectItem(at: 0)
        }

        opacitySlider.doubleValue = settings.opacity
        grainSizeSlider.doubleValue = settings.grainSize
        intensitySlider.doubleValue = settings.intensity
        characterSlider.doubleValue = settings.character
        updateValueLabels()

        seedLabel.stringValue = String(
            format: "%016llX",
            settings.seed
        )
        loginToggle.state = settings.launchAtLogin ? .on : .off
        loginMessage.stringValue = model.loginItemMessage ?? ""
        loginMessage.isHidden = model.loginItemMessage == nil
    }

    private func makeHeader() -> NSView {
        let title = NSTextField(labelWithString: "ScreenGrain")
        title.font = .boldSystemFont(ofSize: NSFont.systemFontSize)
        let subtitle = NSTextField(labelWithString: "Static texture on every display")
        subtitle.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        subtitle.textColor = .secondaryLabelColor

        let text = NSStackView(views: [title, subtitle])
        text.orientation = .vertical
        text.alignment = .leading
        text.spacing = 1

        enabledToggle.setButtonType(.switch)
        enabledToggle.target = self
        enabledToggle.action = #selector(enabledChanged)

        let row = NSStackView(views: [text, NSView(), enabledToggle])
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

    private func makePresetRow() -> NSView {
        presetControl.addItems(withTitles: ["Custom"] + GrainPreset.all.map(\.name))
        presetControl.target = self
        presetControl.action = #selector(presetChanged)
        presetControl.controlSize = .small

        let label = NSTextField(labelWithString: "Preset")
        let row = NSStackView(views: [label, NSView(), presetControl])
        row.orientation = .horizontal
        row.alignment = .centerY
        stretch(row)
        return row
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
        valueLabels[.opacity]?.stringValue = "\(Int(opacitySlider.doubleValue * 100))%"
        valueLabels[.grainSize]?.stringValue = String(
            format: "%.1f×",
            grainSizeSlider.doubleValue
        )
        valueLabels[.intensity]?.stringValue = "\(Int(intensitySlider.doubleValue * 100))%"
        valueLabels[.character]?.stringValue = characterSlider.doubleValue < 0.05
            ? "Mono"
            : "\(Int(characterSlider.doubleValue * 100))%"
    }

    private func stretch(_ view: NSView) {
        view.translatesAutoresizingMaskIntoConstraints = false
        view.widthAnchor.constraint(equalToConstant: 288).isActive = true
    }

    @objc private func enabledChanged() {
        model.set(\.enabled, to: enabledToggle.state == .on, clearsPreset: false)
    }

    @objc private func modeChanged() {
        model.set(\.mode, to: modeControl.selectedSegment == 0 ? .noise : .filmGrain)
    }

    @objc private func presetChanged() {
        guard presetControl.indexOfSelectedItem > 0 else { return }
        model.apply(GrainPreset.all[presetControl.indexOfSelectedItem - 1])
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
        case .character:
            model.set(\.character, to: sender.doubleValue)
        }
        updateValueLabels()
    }

    @objc private func reroll() {
        model.reroll()
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
