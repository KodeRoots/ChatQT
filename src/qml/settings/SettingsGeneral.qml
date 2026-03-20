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

    title: i18nc("@title", "General")

    property var settings: null

    Kirigami.ColumnView.fillWidth: true

    Kirigami.FormLayout {
        anchors.fill: parent

        QQC2.ComboBox {
            id: providerComboBox

            Kirigami.FormData.label: i18nc("@title:group", "Provider:")

            model: [
                { text: i18n("Ollama"), value: "ollama" },
                { text: i18n("OpenClaw"), value: "openclaw" },
                { text: i18n("OpenAI Compatible"), value: "openai-compatible" },
                { text: i18n("OpenCode"), value: "opencode" }
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

        QQC2.Label {
            text: i18nc("@info", "Select the AI provider to use for chat.")
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }
}
