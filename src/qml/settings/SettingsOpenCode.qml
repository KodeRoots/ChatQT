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

    title: i18nc("@title", "OpenCode")

    property var settings: null

    Kirigami.ColumnView.fillWidth: true

    Kirigami.FormLayout {
        anchors.fill: parent

        QQC2.TextField {
            id: opencodeUrlField

            Kirigami.FormData.label: i18nc("@label:textbox", "URL:")

            Layout.fillWidth: true

            placeholderText: "http://127.0.0.1:3000"

            onTextChanged: {
                if (root.settings) {
                    root.settings.opencodeUrl = text
                }
            }

            Component.onCompleted: {
                if (root.settings) {
                    text = root.settings.opencodeUrl || ""
                }
            }
        }

        QQC2.Label {
            text: i18nc("@info", "The URL of your OpenCode instance")
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        QQC2.TextField {
            id: opencodeUsernameField

            Kirigami.FormData.label: i18nc("@label:textbox", "Username:")

            Layout.fillWidth: true

            placeholderText: i18nc("@info:placeholder", "Enter your username")

            onTextChanged: {
                if (root.settings) {
                    root.settings.opencodeUsername = text
                }
            }

            Component.onCompleted: {
                if (root.settings) {
                    text = root.settings.opencodeUsername || ""
                }
            }
        }

        QQC2.Label {
            text: i18nc("@info", "Username for HTTP Basic Authentication")
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        QQC2.TextField {
            id: opencodePasswordField

            Kirigami.FormData.label: i18nc("@label:textbox", "Password:")

            Layout.fillWidth: true

            placeholderText: i18nc("@info:placeholder", "Enter your password")
            echoMode: QQC2.TextField.Password

            onTextChanged: {
                if (root.settings) {
                    root.settings.opencodePassword = text
                }
            }

            Component.onCompleted: {
                if (root.settings) {
                    text = root.settings.opencodePassword || ""
                }
            }
        }

        QQC2.Label {
            text: i18nc("@info", "Password for HTTP Basic Authentication")
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        QQC2.TextField {
            id: opencodeModelField

            Kirigami.FormData.label: i18nc("@label:textbox", "Model:")

            Layout.fillWidth: true

            placeholderText: "default"

            onTextChanged: {
                if (root.settings) {
                    root.settings.opencodeModel = text
                }
            }

            Component.onCompleted: {
                if (root.settings) {
                    text = root.settings.opencodeModel || ""
                }
            }
        }

        QQC2.Label {
            text: i18nc("@info", "The model name to use")
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }
}