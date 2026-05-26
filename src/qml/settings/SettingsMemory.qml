/*
    SPDX-FileCopyrightText: 2026 Denys Madureira <denysmb@zoho.com>
    SPDX-License-Identifier: LGPL-2.1-or-later
*/

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami

Kirigami.ScrollablePage {
    id: root

    title: i18nc("@title", "Memory")

    property var settings: null

    Kirigami.ColumnView.fillWidth: true

    ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Heading {
            level: 2
            text: i18nc("@title", "Memory")
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.largeSpacing
            Layout.rightMargin: Kirigami.Units.largeSpacing
            Layout.topMargin: Kirigami.Units.largeSpacing
        }

        QQC2.Label {
            text: i18nc("@info", "The AI can save important information here to remember across conversations. You can also edit this manually.")
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
                id: memoryTextArea

                text: root.settings ? root.settings.memoryContent : ""
                placeholderText: i18nc("@info:placeholder", "User prefers Portuguese.\nWorks with KDE/Qt.\nLikes concise answers.")
                wrapMode: TextEdit.Wrap
                font.family: "Monospace"

                onTextChanged: {
                    if (root.settings && root.settings.memoryContent !== text) {
                        root.settings.memoryContent = text
                    }
                }

                Connections {
                    target: root.settings
                    function onMemoryContentChanged() {
                        if (root.settings && memoryTextArea.text !== root.settings.memoryContent) {
                            memoryTextArea.text = root.settings.memoryContent
                        }
                    }
                }
            }
        }
    }
}
