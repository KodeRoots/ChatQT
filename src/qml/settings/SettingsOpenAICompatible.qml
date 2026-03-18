/*
    SPDX-FileCopyrightText: 2024 Denys Madureira <denysmb@zoho.com>
    SPDX-License-Identifier: LGPL-2.1-or-later
*/

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami

Kirigami.ScrollablePage {
    id: root

    title: i18nc("@title", "OpenAI Compatible")

    property var settings: null

    Kirigami.ColumnView.fillWidth: true

    Kirigami.FormLayout {
        anchors.fill: parent

        QQC2.TextField {
            id: openaiCompatibleUrlField

            Kirigami.FormData.label: i18nc("@label:textbox", "API URL:")

            Layout.fillWidth: true

            placeholderText: "https://api.openai.com/v1"

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

        QQC2.Label {
            text: i18nc("@info", "The base URL of the OpenAI-compatible API")
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        QQC2.TextField {
            id: openaiCompatibleTokenField

            Kirigami.FormData.label: i18nc("@label:textbox", "API Token:")

            Layout.fillWidth: true

            placeholderText: i18nc("@info:placeholder", "Enter your API token")
            echoMode: QQC2.TextField.Password

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

        QQC2.Label {
            text: i18nc("@info", "Your API key/token for authentication")
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        QQC2.TextField {
            id: openaiCompatibleModelField

            Kirigami.FormData.label: i18nc("@label:textbox", "Model:")

            Layout.fillWidth: true

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

        QQC2.Label {
            text: i18nc("@info", "The model name to use (e.g., gpt-4, gpt-3.5-turbo, deepseek-chat)")
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        QQC2.CheckBox {
            id: thinkingCheckBox

            Kirigami.FormData.label: i18nc("@label:checkbox", "Thinking Mode:")

            text: i18nc("@option:check", "Enable thinking/reasoning mode")

            checked: root.settings ? !root.settings.openaiCompatibleDisableThinking : true

            onCheckedChanged: {
                if (root.settings) {
                    root.settings.openaiCompatibleDisableThinking = !checked
                }
            }

            QQC2.ToolTip.text: i18nc("@info:tooltip", "Enable thinking for models that support reasoning")
            QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
            QQC2.ToolTip.visible: hovered
        }

        QQC2.Label {
            text: i18nc("@info", "Enable thinking for models that support reasoning (e.g., o1, deepseek-r1)")
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }
}
