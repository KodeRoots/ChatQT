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

    Component {
        id: piPage
        SettingsPi {}
    }

    Component {
        id: skillsMcpPage
        SettingsSkillsMCP {}
    }

    Component {
        id: agentPage
        SettingsAgent {}
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
            text: i18nc("@action:button", "OpenClaw")
            description: i18nc("@info:whatsthis", "Configure OpenClaw URL and token")
            icon.name: "network-server"
            onClicked: Kirigami.PageStack.push(openclawPage, {
                settings: root.settings
            })
        }

        FormCard.FormDelegateSeparator {
            above: openclawButton
            below: openaiCompatibleButton
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
            below: opencodeButton
        }

        FormCard.FormButtonDelegate {
            id: opencodeButton
            text: i18nc("@action:button", "OpenCode")
            description: i18nc("@info:whatsthis", "Configure OpenCode settings")
            icon.name: "network-server"
            onClicked: Kirigami.PageStack.push(opencodePage, {
                settings: root.settings
            })
        }

        FormCard.FormDelegateSeparator {
            above: opencodeButton
            below: piButton
        }

        FormCard.FormButtonDelegate {
            id: piButton
            text: i18nc("@action:button", "Pi")
            description: i18nc("@info:whatsthis", "Configure Pi (RPC mode)")
            icon.name: "network-server"
            onClicked: Kirigami.PageStack.push(piPage, {
                settings: root.settings
            })
        }

        FormCard.FormDelegateSeparator {
            above: piButton
            below: skillsMcpButton
        }

        FormCard.FormButtonDelegate {
            id: skillsMcpButton
            text: i18nc("@action:button", "Skills and MCPs")
            description: i18nc("@info:whatsthis", "Configure skills folders and MCP servers")
            icon.name: "network-connect"
            onClicked: Kirigami.PageStack.push(skillsMcpPage, {
                settings: root.settings
            })
        }

        FormCard.FormDelegateSeparator {
            above: skillsMcpButton
            below: agentButton
        }

        FormCard.FormButtonDelegate {
            id: agentButton
            text: i18nc("@action:button", "Agent")
            description: i18nc("@info:whatsthis", "Configure agent instructions (AGENTS.md)")
            icon.name: "user-identity"
            onClicked: Kirigami.PageStack.push(agentPage, {
                settings: root.settings
            })
        }
    }
}
