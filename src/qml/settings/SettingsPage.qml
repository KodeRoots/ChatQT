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
    property bool openclawVisible: settings ? settings.openclawEnabled : false

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
        id: mcpPage
        SettingsMCP {}
    }

    Component {
        id: soulPage
        SettingsSoul {}
    }

    Component {
        id: memoryPage
        SettingsMemory {}
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
            icon.name: "applications-system-symbolic"
            onClicked: Kirigami.PageStack.push(generalPage, {
                settings: root.settings
            })
        }

        FormCard.FormDelegateSeparator {
            above: generalButton
            below: openclawButton
        }

        FormCard.FormButtonDelegate {
            id: openclawButton
            visible: root.openclawVisible
            text: i18nc("@action:button", "OpenClaw")
            description: i18nc("@info:whatsthis", "Configure OpenClaw URL and token")
            icon.name: "network-server-database-symbolic"
            onClicked: Kirigami.PageStack.push(openclawPage, {
                settings: root.settings
            })
        }

        FormCard.FormDelegateSeparator {
            above: openclawButton
            below: openaiCompatibleButton
            visible: root.openclawVisible
        }

        FormCard.FormButtonDelegate {
            id: openaiCompatibleButton
            text: i18nc("@action:button", "OpenAI Compatible")
            description: i18nc("@info:whatsthis", "Configure OpenAI-compatible API settings")
            icon.name: "network-connect"
            onClicked: Kirigami.PageStack.push(openaiCompatiblePage, {
                settings: root.settings
            })
        }

        FormCard.FormDelegateSeparator {
            above: openaiCompatibleButton
            below: mcpButton
        }

        FormCard.FormButtonDelegate {
            id: mcpButton
            text: i18nc("@action:button", "MCP Servers")
            description: i18nc("@info:whatsthis", "Configure remote MCP servers")
            icon.name: "code-context-symbolic"
            onClicked: Kirigami.PageStack.push(mcpPage, {
                settings: root.settings
            })
        }

        FormCard.FormDelegateSeparator {
            above: mcpButton
            below: soulButton
        }

        FormCard.FormButtonDelegate {
            id: soulButton
            text: i18nc("@action:button", "Soul")
            description: i18nc("@info:whatsthis", "Configure the AI personality and behavior")
            icon.name: "user-identity-symbolic"
            onClicked: Kirigami.PageStack.push(soulPage, {
                settings: root.settings
            })
        }

        FormCard.FormDelegateSeparator {
            above: soulButton
            below: memoryButton
        }

        FormCard.FormButtonDelegate {
            id: memoryButton
            text: i18nc("@action:button", "Memory")
            description: i18nc("@info:whatsthis", "View and edit what the AI remembers across conversations")
            icon.name: "kmouth-phrasebook-symbolic"
            onClicked: Kirigami.PageStack.push(memoryPage, {
                settings: root.settings
            })
        }
    }
}
