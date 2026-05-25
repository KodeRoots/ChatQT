/*
    SPDX-FileCopyrightText: 2026 Denys Madureira <denys@koderoots.org>
    SPDX-License-Identifier: LGPL-2.1-or-later
*/

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami

Kirigami.ScrollablePage {
    id: root

    title: i18nc("@title", "Soul")

    property var settings: null

    Kirigami.ColumnView.fillWidth: true

    ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Heading {
            level: 2
            text: i18nc("@title", "Soul")
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.largeSpacing
            Layout.rightMargin: Kirigami.Units.largeSpacing
            Layout.topMargin: Kirigami.Units.largeSpacing
        }

        QQC2.Label {
            text: i18nc("@info", "Define the AI's personality, tone, and behavior rules. This content is sent as the system message with every conversation.")
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.largeSpacing
            Layout.rightMargin: Kirigami.Units.largeSpacing
        }

        Kirigami.AbstractCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: Kirigami.Units.largeSpacing
            Layout.rightMargin: Kirigami.Units.largeSpacing
            Layout.topMargin: Kirigami.Units.smallSpacing
            Layout.bottomMargin: Kirigami.Units.largeSpacing

            contentItem: QQC2.TextArea {
                id: soulTextArea

                text: root.settings ? root.settings.soulContent : ""
                placeholderText: i18nc("@info:placeholder", "You are a helpful, concise assistant.\n\nRules:\n- Be direct and clear\n- Use simple language\n- Ask for clarification when unsure")
                wrapMode: TextEdit.Wrap
                font.family: "Monospace"

                onTextChanged: {
                    if (root.settings && root.settings.soulContent !== text) {
                        root.settings.soulContent = text
                    }
                }

                Connections {
                    target: root.settings
                    function onSoulContentChanged() {
                        if (root.settings && soulTextArea.text !== root.settings.soulContent) {
                            soulTextArea.text = root.settings.soulContent
                        }
                    }
                }
            }
        }
    }
}
