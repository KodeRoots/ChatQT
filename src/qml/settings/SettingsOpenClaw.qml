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

    title: i18nc("@title", "OpenClaw")

    property var settings: null

    Kirigami.FormLayout {
        anchors.fill: parent

        QQC2.TextField {
            id: openclawUrlField

            Kirigami.FormData.label: i18nc("@label:textbox", "URL:")

            Layout.fillWidth: true

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

        QQC2.Label {
            text: i18nc("@info", "The URL of your OpenClaw instance")
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        QQC2.TextField {
            id: openclawTokenField

            Kirigami.FormData.label: i18nc("@label:textbox", "Token:")

            Layout.fillWidth: true

            placeholderText: i18nc("@info:placeholder", "Enter your token")
            echoMode: QQC2.TextField.Password

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

        QQC2.Label {
            text: i18nc("@info", "Authentication token for OpenClaw")
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }
}
