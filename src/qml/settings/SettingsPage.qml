/*
    SPDX-FileCopyrightText: 2024 Denys Madureira <denysmb@zoho.com>
    SPDX-License-Identifier: LGPL-2.1-or-later
*/

import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.Page {
    id: root

    title: i18n("Settings")

    property var settings: null

    Kirigami.FormLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing

        Kirigami.Separator {
            Kirigami.FormData.label: i18n("AI Provider")
            Kirigami.FormData.isSection: true
        }

        Controls.ComboBox {
            id: providerComboBox

            Kirigami.FormData.label: i18nc("@title:group", "Provider:")

            model: [
                { text: i18n("Ollama"), value: "ollama" },
                { text: i18n("OpenClaw"), value: "openclaw" },
                { text: i18n("OpenAI Compatible"), value: "openai-compatible" }
            ]

            textRole: "text"
            valueRole: "value"

            onCurrentValueChanged: {
                if (root.settings) {
                    root.settings.provider = currentValue
                }
            }

            Component.onCompleted: {
                if (root.settings) {
                    currentIndex = indexOfValue(root.settings.provider || "ollama")
                }
            }
        }

        Kirigami.Separator {
            Kirigami.FormData.label: i18n("OpenClaw Settings")
            Kirigami.FormData.isSection: true
            visible: providerComboBox.currentValue === "openclaw"
        }

        Controls.TextField {
            id: openclawUrlField

            visible: providerComboBox.currentValue === "openclaw"
            Kirigami.FormData.label: i18n("URL:")

            placeholderText: "http://127.0.0.1:18789"

            onTextChanged: {
                if (root.settings) {
                    root.settings.openclawUrl = text
                }
            }

            Component.onCompleted: {
                if (root.settings) {
                    text = root.settings.openclawUrl || ""
                }
            }
        }

        Controls.TextField {
            id: openclawTokenField

            visible: providerComboBox.currentValue === "openclaw"
            Kirigami.FormData.label: i18n("Token:")

            placeholderText: i18n("Enter your token")
            echoMode: Controls.TextField.Password

            onTextChanged: {
                if (root.settings) {
                    root.settings.openclawToken = text
                }
            }

            Component.onCompleted: {
                if (root.settings) {
                    text = root.settings.openclawToken || ""
                }
            }
        }

        Kirigami.Separator {
            Kirigami.FormData.label: i18n("OpenAI Compatible Settings")
            Kirigami.FormData.isSection: true
            visible: providerComboBox.currentValue === "openai-compatible"
        }

        Controls.TextField {
            id: openaiCompatibleUrlField

            visible: providerComboBox.currentValue === "openai-compatible"
            Kirigami.FormData.label: i18n("API URL:")

            placeholderText: "https://api.example.com"

            onTextChanged: {
                if (root.settings) {
                    root.settings.openaiCompatibleUrl = text
                }
            }

            Component.onCompleted: {
                if (root.settings) {
                    text = root.settings.openaiCompatibleUrl || ""
                }
            }
        }

        Controls.TextField {
            id: openaiCompatibleTokenField

            visible: providerComboBox.currentValue === "openai-compatible"
            Kirigami.FormData.label: i18n("API Token:")

            placeholderText: i18n("Enter your API token")
            echoMode: Controls.TextField.Password

            onTextChanged: {
                if (root.settings) {
                    root.settings.openaiCompatibleToken = text
                }
            }

            Component.onCompleted: {
                if (root.settings) {
                    text = root.settings.openaiCompatibleToken || ""
                }
            }
        }

        Controls.TextField {
            id: openaiCompatibleModelField

            visible: providerComboBox.currentValue === "openai-compatible"
            Kirigami.FormData.label: i18n("Model:")

            placeholderText: "gpt-4"

            onTextChanged: {
                if (root.settings) {
                    root.settings.openaiCompatibleModel = text
                }
            }

            Component.onCompleted: {
                if (root.settings) {
                    text = root.settings.openaiCompatibleModel || ""
                }
            }
        }

        Controls.CheckBox {
            visible: providerComboBox.currentValue === "openai-compatible"
            Kirigami.FormData.label: i18n("Enable thinking:")

            checked: root.settings ? !root.settings.openaiCompatibleDisableThinking : true

            onCheckedChanged: {
                if (root.settings) {
                    root.settings.openaiCompatibleDisableThinking = !checked
                }
            }

            Controls.ToolTip.text: i18n("Toggle thinking/reasoning mode")
            Controls.ToolTip.delay: Kirigami.Units.toolTipDelay
            Controls.ToolTip.visible: hovered
        }
    }

    footer: Controls.ToolBar {
        RowLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing

            Item { Layout.fillWidth: true }

            Controls.Button {
                text: i18n("Save")
                icon.name: "dialog-ok"

                onClicked: {
                    applicationWindow().pageStack.pop()
                }
            }

            Controls.Button {
                text: i18n("Cancel")
                icon.name: "dialog-cancel"

                onClicked: {
                    applicationWindow().pageStack.pop()
                }
            }
        }
    }
}