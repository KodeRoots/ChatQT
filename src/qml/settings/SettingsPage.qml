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

    Component {
        id: opencodePage
        SettingsOpenCode {}
    }

    FormCard.FormCard {
        id: formCard
        width: parent.width

        states: [
            State {
                name: "centered"
                when: !applicationWindow().pageStack.wideMode
                AnchorChanges {
                    target: formCard
                    anchors.verticalCenter: formCard.parent.verticalCenter
                }
            },
            State {
                name: "top"
                when: applicationWindow().pageStack.wideMode
                AnchorChanges {
                    target: formCard
                    anchors.top: formCard.parent.top
                }
            }
        ]

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

        FormCard.FormDelegateSeparator { above: openaiCompatibleButton; below: opencodeButton }

        FormCard.FormButtonDelegate {
            id: opencodeButton
            text: i18nc("@action:button", "OpenCode")
            description: i18nc("@info:whatsthis", "Configure OpenCode settings")
            icon.name: "network-server"
            onClicked: applicationWindow().pageStack.push(opencodePage, {
                settings: root.settings
            })
        }
    }
}
