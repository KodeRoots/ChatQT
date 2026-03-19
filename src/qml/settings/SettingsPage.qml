/*
    SPDX-FileCopyrightText: 2024 Denys Madureira <denysmb@zoho.com>
    SPDX-License-Identifier: LGPL-2.1-or-later
*/

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.kirigamiaddons.formcard as FormCard

Kirigami.ScrollablePage {
    id: root

    title: i18nc("@title", "Settings")

    property var settings: null

    padding: 0

    Kirigami.ColumnView.pinned: true
    Kirigami.ColumnView.preferredWidth: Kirigami.Units.gridUnit * 18
    Kirigami.ColumnView.minimumWidth: Kirigami.Units.gridUnit * 12
    Kirigami.ColumnView.maximumWidth: Kirigami.Units.gridUnit * 22

    Component {
        id: generalPage
        SettingsGeneral {}
    }

    Component {
        id: openclawPage
        SettingsOpenClaw {}
    }

    Component {
        id: openaiCompatiblePage
        SettingsOpenAICompatible {}
    }

    ColumnLayout {
        spacing: 0
        anchors.fill: parent

        FormCard.FormCard {
            Layout.alignment: Qt.AlignVCenter
            Layout.fillWidth: true

            FormCard.FormButtonDelegate {
                id: generalButton
                text: i18nc("@action:button", "General")
                description: i18nc("@info:whatsthis", "Select the active AI provider")
                icon.name: "preferences-system"
                onClicked: applicationWindow().pageStack.push(generalPage, {
                    settings: root.settings
                })
            }

            FormCard.FormDelegateSeparator { above: generalButton; below: openclawButton }

            FormCard.FormButtonDelegate {
                id: openclawButton
                text: i18nc("@action:button", "OpenClaw")
                description: i18nc("@info:whatsthis", "Configure OpenClaw URL and token")
                icon.name: "network-server"
                onClicked: applicationWindow().pageStack.push(openclawPage, {
                    settings: root.settings
                })
            }

            FormCard.FormDelegateSeparator { above: openclawButton; below: openaiCompatibleButton }

            FormCard.FormButtonDelegate {
                id: openaiCompatibleButton
                text: i18nc("@action:button", "OpenAI Compatible")
                description: i18nc("@info:whatsthis", "Configure OpenAI-compatible API settings")
                icon.name: "network-connect"
                onClicked: applicationWindow().pageStack.push(openaiCompatiblePage, {
                    settings: root.settings
                })
            }
        }
    }
}
