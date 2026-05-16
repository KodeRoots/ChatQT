/*
    SPDX-FileCopyrightText: 2026 Denys Madureira <denys@koderoots.org>
    SPDX-License-Identifier: LGPL-2.1-or-later
*/

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Dialogs

import org.kde.kirigami as Kirigami
import org.kde.chatqt
import org.koderoots.chatqt

Kirigami.ScrollablePage {
    id: root

    title: i18nc("@title", "Agent")

    property var settings: null

    property string agentFilePath: settings ? (settings.agentFilePath || "") : ""
    property string agentContent: ""
    property bool agentLoaded: false

    Component.onCompleted: {
        loadAgentContent()
    }

    function loadAgentContent() {
        if (!agentFilePath || agentFilePath === "") {
            agentContent = ""
            agentLoaded = false
            return
        }

        var content = SkillScanner.readFile(agentFilePath)
        if (content && content !== "") {
            agentContent = content
            agentLoaded = true
        } else {
            agentContent = ""
            agentLoaded = false
        }
    }

    function setAgentFile(path) {
        var cleanPath = path.replace(/^file:\/\//, "")
        if (settings) {
            settings.agentFilePath = cleanPath
        }
        agentFilePath = cleanPath
        loadAgentContent()
    }

    function clearAgentFile() {
        if (settings) {
            settings.agentFilePath = ""
        }
        agentFilePath = ""
        agentContent = ""
        agentLoaded = false
    }

    FileDialog {
        id: agentFileDialog
        title: i18nc("@title:window", "Select Agent File")
        nameFilters: ["Markdown files (*.md)", "All files (*)"]
        onAccepted: {
            var path = agentFileDialog.selectedFile.toString()
            root.setAgentFile(path)
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.largeSpacing

        QQC2.Label {
            text: i18nc("@info", "Select an agent instruction file (e.g., AGENTS.md or CLAUDE.md) that will be loaded into the chat context. This provides the AI with persistent instructions and guidelines for every session.")
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        Kirigami.Heading {
            level: 2
            text: i18nc("@title:group", "Agent File")
            Layout.fillWidth: true
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            QQC2.TextField {
                id: agentPathField
                Layout.fillWidth: true
                placeholderText: i18nc("@info:placeholder", "e.g., ~/.agents/AGENTS.md or ~/.claude/CLAUDE.md")
                text: root.agentFilePath
                onEditingFinished: {
                    if (text !== root.agentFilePath) {
                        root.setAgentFile(text)
                    }
                }
            }

            QQC2.Button {
                icon.name: "folder-open-symbolic"
                display: QQC2.AbstractButton.IconOnly
                text: i18nc("@action:button", "Browse")
                onClicked: agentFileDialog.open()

                QQC2.ToolTip {
                    text: parent.text
                    delay: Kirigami.Units.toolTipDelay
                }
            }

            QQC2.Button {
                visible: root.agentFilePath !== ""
                icon.name: "edit-delete-symbolic"
                display: QQC2.AbstractButton.IconOnly
                text: i18nc("@action:button", "Clear")
                onClicked: root.clearAgentFile()

                QQC2.ToolTip {
                    text: parent.text
                    delay: Kirigami.Units.toolTipDelay
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: root.agentLoaded
            spacing: Kirigami.Units.smallSpacing

            Rectangle {
                radius: Kirigami.Units.smallSpacing
                height: Kirigami.Units.gridUnit * 1.2
                width: statusLabel.width + Kirigami.Units.smallSpacing * 2
                color: Kirigami.Theme.positiveTextColor
                Layout.alignment: Qt.AlignVCenter

                QQC2.Label {
                    id: statusLabel
                    anchors.centerIn: parent
                    text: i18nc("@info", "Loaded")
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    font.bold: true
                    color: Kirigami.Theme.backgroundColor
                }
            }

            QQC2.Label {
                text: i18nc("@info", "%1 character(s)").arg(root.agentContent.length)
                font: Kirigami.Theme.smallFont
                color: Kirigami.Theme.disabledTextColor
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: root.agentFilePath !== "" && !root.agentLoaded
            spacing: Kirigami.Units.smallSpacing

            Rectangle {
                radius: Kirigami.Units.smallSpacing
                height: Kirigami.Units.gridUnit * 1.2
                width: errorLabel.width + Kirigami.Units.smallSpacing * 2
                color: Kirigami.Theme.negativeTextColor
                Layout.alignment: Qt.AlignVCenter

                QQC2.Label {
                    id: errorLabel
                    anchors.centerIn: parent
                    text: i18nc("@info", "Not Found")
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    font.bold: true
                    color: Kirigami.Theme.backgroundColor
                }
            }

            QQC2.Label {
                text: i18nc("@info", "File could not be read")
                font: Kirigami.Theme.smallFont
                color: Kirigami.Theme.disabledTextColor
            }
        }

        Kirigami.Separator {
            Layout.fillWidth: true
        }

        Kirigami.Heading {
            level: 2
            text: i18nc("@title:group", "Preview")
            Layout.fillWidth: true
        }

        QQC2.Label {
            visible: root.agentContent === ""
            text: i18nc("@info", "No agent file loaded. Select a file above to preview its content.")
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        Kirigami.AbstractCard {
            visible: root.agentContent !== ""
            Layout.fillWidth: true
            Layout.fillHeight: true

            contentItem: QQC2.ScrollView {
                clip: true

                QQC2.TextArea {
                    readOnly: true
                    text: root.agentContent
                    wrapMode: Text.WordWrap
                    font.family: "monospace"
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    background: null
                }
            }
        }
    }
}
