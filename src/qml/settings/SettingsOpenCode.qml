/*
    SPDX-FileCopyrightText: 2024 Denys Madureira <denysmb@zoho.com>
    SPDX-License-Identifier: LGPL-2.1-or-later
*/

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Dialogs

import org.kde.kirigami as Kirigami
import org.kde.chatqt

import "../components"

Kirigami.ScrollablePage {
    id: root
    title: i18nc("@title", "OpenCode")
    property var settings: null
    Kirigami.ColumnView.fillWidth: true

    Kirigami.FormLayout {
        Layout.fillWidth: true

        // ==================== Server Status Section ====================
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18nc("@title:group", "Server Status")
        }

        RowLayout {
            Kirigami.FormData.label: i18nc("@label", "Status:")

            ServerStatusIndicator {
                showText: true
                compact: false
            }
        }

        RowLayout {
            Kirigami.FormData.label: i18nc("@label", "Controls:")

            QQC2.Button {
                text: i18n("Start")
                icon.name: "media-playback-start"
                enabled: !ProcessManager.running 
                         && ProcessManager.status !== "starting"
                         && ProcessManager.validateBinaryPath(binaryPathField.text)
                onClicked: {
                    ProcessManager.binaryPath = binaryPathField.text
                    ProcessManager.start()
                }

                QQC2.ToolTip.visible: hovered && !ProcessManager.validateBinaryPath(binaryPathField.text)
                QQC2.ToolTip.text: i18n("Set a valid binary path before starting")
            }

            QQC2.Button {
                text: i18n("Stop")
                icon.name: "media-playback-stop"
                enabled: ProcessManager.running && ProcessManager.status !== "stopping"
                onClicked: ProcessManager.stop()
            }

            QQC2.Button {
                text: i18n("Restart")
                icon.name: "media-playback-restart"
                enabled: ProcessManager.running && ProcessManager.status !== "stopping"
                onClicked: ProcessManager.restart()
            }
        }

        // ==================== Server Configuration Section ====================
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18nc("@title:group", "Server Configuration")
        }

        RowLayout {
            Kirigami.FormData.label: i18nc("@label:textbox", "Binary Path:")

            QQC2.TextField {
                id: binaryPathField
                Layout.fillWidth: true
                placeholderText: i18nc("@info:placeholder", "Path to OpenCode binary")
                text: ProcessManager.binaryPath

                onEditingFinished: {
                    ProcessManager.binaryPath = text
                }

                Connections {
                    target: ProcessManager
                    function onBinaryPathChanged() {
                        binaryPathField.text = ProcessManager.binaryPath
                    }
                }
            }

            QQC2.Button {
                icon.name: "folder-open"
                display: QQC2.AbstractButton.IconOnly
                QQC2.ToolTip.text: i18n("Browse for OpenCode binary")
                QQC2.ToolTip.visible: hovered
                onClicked: fileDialog.open()

                FileDialog {
                    id: fileDialog
                    title: i18n("Select OpenCode Binary")
                    fileMode: FileDialog.OpenFile
                    nameFilters: ["Executable files (*)"]
                    onAccepted: {
                        // selectedFile returns a URL like "file:///path/to/file"
                        // Convert to local path by removing the "file://" prefix
                        var path = selectedFile.toString()
                        if (path.startsWith("file://")) {
                            path = path.substring(7)
                        }
                        ProcessManager.binaryPath = path
                    }
                }
            }

            QQC2.Button {
                icon.name: "search"
                display: QQC2.AbstractButton.IconOnly
                QQC2.ToolTip.text: i18n("Auto-detect OpenCode binary")
                QQC2.ToolTip.visible: hovered
                onClicked: {
                    if (!ProcessManager.autoDetectBinary()) {
                        applicationWindow().showPassiveNotification(i18n("Could not find OpenCode binary"))
                    }
                }
            }
        }

        QQC2.Label {
            text: ProcessManager.validateBinaryPath(binaryPathField.text) 
                ? i18nc("@info", "Binary found and executable") 
                : i18nc("@info", "Binary not found or not executable")
            font: Kirigami.Theme.smallFont
            color: ProcessManager.validateBinaryPath(binaryPathField.text) ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.negativeTextColor
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }

        RowLayout {
            Kirigami.FormData.label: i18nc("@label:textbox", "Password:")

            QQC2.TextField {
                id: passwordField
                Layout.fillWidth: true
                placeholderText: i18nc("@info:placeholder", "Server password")
                text: ProcessManager.password
                echoMode: QQC2.TextField.Password

                onEditingFinished: {
                    ProcessManager.password = text
                }

                Connections {
                    target: ProcessManager
                    function onPasswordChanged() {
                        passwordField.text = ProcessManager.password
                    }
                }
            }

            QQC2.Button {
                icon.name: "visibility"
                display: QQC2.AbstractButton.IconOnly
                checkable: true
                QQC2.ToolTip.text: i18n("Toggle password visibility")
                QQC2.ToolTip.visible: hovered
                onCheckedChanged: {
                    passwordField.echoMode = checked ? QQC2.TextField.Normal : QQC2.TextField.Password
                }
            }

            QQC2.Button {
                icon.name: "roll"
                display: QQC2.AbstractButton.IconOnly
                QQC2.ToolTip.text: i18n("Generate new password")
                QQC2.ToolTip.visible: hovered
                onClicked: ProcessManager.regeneratePassword()
            }
        }

        QQC2.Label {
            text: i18nc("@info", "Password is set via OPENCODE_SERVER_PASSWORD environment variable")
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        QQC2.CheckBox {
            id: autoStartCheck

            Kirigami.FormData.label: i18nc("@label:checkbox", "Auto-start:")

            checked: ProcessManager.autoStart
            text: i18nc("@info:checkbox", "Start server when app opens")

            onCheckedChanged: {
                ProcessManager.autoStart = checked
            }

            Connections {
                target: ProcessManager
                function onAutoStartChanged() {
                    autoStartCheck.checked = ProcessManager.autoStart
                }
            }
        }

        QQC2.CheckBox {
            id: autoRestartCheck

            Kirigami.FormData.label: i18nc("@label:checkbox", "Auto-restart:")

            checked: ProcessManager.autoRestart
            text: i18nc("@info:checkbox", "Restart server on crash (max 3 attempts)")

            onCheckedChanged: {
                ProcessManager.autoRestart = checked
            }

            Connections {
                target: ProcessManager
                function onAutoRestartChanged() {
                    autoRestartCheck.checked = ProcessManager.autoRestart
                }
            }
        }

        RowLayout {
            Kirigami.FormData.label: i18nc("@label", "Restart attempts:")

            QQC2.Label {
                text: ProcessManager.restartAttempts + " / 3"
                color: ProcessManager.restartAttempts > 0 ? Kirigami.Theme.neutralTextColor : Kirigami.Theme.textColor
            }

            QQC2.Button {
                icon.name: "edit-reset"
                display: QQC2.AbstractButton.IconOnly
                visible: ProcessManager.restartAttempts > 0
                QQC2.ToolTip.text: i18n("Reset restart counter")
                QQC2.ToolTip.visible: hovered
                onClicked: ProcessManager.restart()
            }
        }

        // ==================== Connection Settings Section ====================
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18nc("@title:group", "Connection Settings")
        }

        QQC2.Label {
            Kirigami.FormData.label: i18nc("@label", "Host:")
            text: "127.0.0.1"
            color: Kirigami.Theme.disabledTextColor
        }

        QQC2.Label {
            Kirigami.FormData.label: i18nc("@label", "Port:")
            text: "4096"
            color: Kirigami.Theme.disabledTextColor
        }

        QQC2.Label {
            Kirigami.FormData.label: i18nc("@label", "URL:")
            text: "http://127.0.0.1:4096"
            color: Kirigami.Theme.disabledTextColor
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
            text: i18nc("@info", "The model name to use for chat")
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }
}