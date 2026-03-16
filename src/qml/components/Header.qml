/*
    SPDX-FileCopyrightText: 2024 Denys Madureira <denysmb@zoho.com>
    SPDX-License-Identifier: LGPL-2.1-or-later
*/

import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Rectangle {
    id: root

    signal clearChatRequested()
    signal modelSelected(string modelValue)
    signal settingsRequested()

    property bool isProviderConfigured: false
    property bool isLoading: false
    property string currentProvider: "ollama"
    property bool hasLocalModel: false
    property var modelsArray: []
    property string currentModel: ""
    property bool thinkingEnabled: true

    implicitHeight: toolbarLayout.implicitHeight + Kirigami.Units.smallSpacing * 2

    color: Kirigami.Theme.backgroundColor
    border.width: 0

    Kirigami.Separator {
        anchors.bottom: parent.bottom
        width: parent.width
    }

    RowLayout {
        id: toolbarLayout

        anchors.fill: parent
        anchors.margins: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing

        Controls.ToolButton {
            icon.name: "edit-clear-history-symbolic"
            text: i18n("Clear chat")
            display: Controls.AbstractButton.IconOnly
            enabled: root.isProviderConfigured && !root.isLoading

            Controls.ToolTip.text: text
            Controls.ToolTip.delay: Kirigami.Units.toolTipDelay
            Controls.ToolTip.visible: hovered

            onClicked: root.clearChatRequested()
        }

        Controls.ComboBox {
            id: modelsCombobox

            visible: root.currentProvider === "ollama"
            enabled: root.hasLocalModel && !root.isLoading

            Layout.fillWidth: true

            model: root.modelsArray.map(model => model.text)

            onActivated: {
                const selectedModel = root.modelsArray.find(model => model.text === modelsCombobox.currentText);
                if (selectedModel) {
                    root.modelSelected(selectedModel.value);
                }
            }
        }

        Controls.Label {
            visible: root.currentProvider === "openclaw"
            Layout.fillWidth: true
            text: "OpenClaw"
            horizontalAlignment: Qt.AlignHCenter
            font.weight: Font.Bold
        }

        RowLayout {
            visible: root.currentProvider === "openai-compatible"
            Layout.fillWidth: true

            Controls.Label {
                text: root.currentModel || "OpenAI Compatible"
                Layout.alignment: Qt.AlignHCenter
                font.weight: Font.Bold
            }

            Item { Layout.fillWidth: true }

            Controls.CheckBox {
                text: i18n("Thinking")
                checked: root.thinkingEnabled
                onCheckedChanged: {
                    if (checked !== root.thinkingEnabled) {
                        root.thinkingEnabled = checked
                    }
                }

                Controls.ToolTip.text: i18n("Toggle thinking/reasoning mode")
                Controls.ToolTip.delay: Kirigami.Units.toolTipDelay
                Controls.ToolTip.visible: hovered
            }
        }

        Controls.ToolButton {
            icon.name: "settings-configure"
            text: i18n("Settings")
            display: Controls.AbstractButton.IconOnly

            Controls.ToolTip.text: text
            Controls.ToolTip.delay: Kirigami.Units.toolTipDelay
            Controls.ToolTip.visible: hovered

            onClicked: root.settingsRequested()
        }
    }
}