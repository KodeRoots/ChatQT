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
    title: i18nc("@title", "Pi")
    property var settings: null
    Kirigami.ColumnView.fillWidth: true

    Kirigami.FormLayout {
        Layout.fillWidth: true

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18nc("@title:group", "Server Status")
        }

        RowLayout {
            Kirigami.FormData.label: i18nc("@label", "Status:")

            Rectangle {
                radius: Kirigami.Units.smallSpacing
                height: Kirigami.Units.gridUnit * 1.2
                width: statusText.width + Kirigami.Units.smallSpacing * 2
                color: {
                    if (PiProcessManager.status === "running") return Kirigami.Theme.positiveTextColor
                    if (PiProcessManager.status === "starting") return Kirigami.Theme.neutralTextColor
                    if (PiProcessManager.status === "crashed") return Kirigami.Theme.negativeTextColor
                    return Kirigami.Theme.disabledTextColor
                }

                QQC2.Label {
                    id: statusText
                    anchors.centerIn: parent
                    text: {
                        if (PiProcessManager.status === "running") return i18nc("@info", "Running")
                        if (PiProcessManager.status === "starting") return i18nc("@info", "Starting…")
                        if (PiProcessManager.status === "stopping") return i18nc("@info", "Stopping…")
                        if (PiProcessManager.status === "crashed") return i18nc("@info", "Crashed")
                        return i18nc("@info", "Stopped")
                    }
                    font.bold: true
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    color: Kirigami.Theme.backgroundColor
                }
            }
        }

        RowLayout {
            Kirigami.FormData.label: i18nc("@label", "Controls:")

            QQC2.Button {
                text: i18n("Start")
                icon.name: "media-playback-start"
                enabled: !PiProcessManager.running
                         && PiProcessManager.status !== "starting"
                         && PiProcessManager.validateBinaryPath(binaryPathField.text)
                onClicked: {
                    PiProcessManager.binaryPath = binaryPathField.text
                    PiProcessManager.start()
                }

                QQC2.ToolTip.visible: hovered && !PiProcessManager.validateBinaryPath(binaryPathField.text)
                QQC2.ToolTip.text: i18n("Set a valid binary path before starting")
            }

            QQC2.Button {
                text: i18n("Stop")
                icon.name: "media-playback-stop"
                enabled: PiProcessManager.running && PiProcessManager.status !== "stopping"
                onClicked: PiProcessManager.stop()
            }
        }

        QQC2.CheckBox {
            id: autoStartCheck

            Kirigami.FormData.label: i18nc("@label:checkbox", "Auto-start:")

            checked: PiProcessManager.autoStart
            text: i18nc("@info:checkbox", "Start Pi when app opens and Pi is the active provider")

            onCheckedChanged: {
                PiProcessManager.autoStart = checked
            }

            Connections {
                target: PiProcessManager
                function onAutoStartChanged() {
                    autoStartCheck.checked = PiProcessManager.autoStart
                }
            }
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18nc("@title:group", "Binary Configuration")
        }

        RowLayout {
            Kirigami.FormData.label: i18nc("@label:textbox", "Binary Path:")

            QQC2.TextField {
                id: binaryPathField
                Layout.fillWidth: true
                placeholderText: i18nc("@info:placeholder", "Path to Pi binary")
                text: PiProcessManager.binaryPath

                onEditingFinished: {
                    PiProcessManager.binaryPath = text
                }

                Connections {
                    target: PiProcessManager
                    function onBinaryPathChanged() {
                        binaryPathField.text = PiProcessManager.binaryPath
                    }
                }
            }

            QQC2.Button {
                icon.name: "folder-open"
                display: QQC2.AbstractButton.IconOnly
                QQC2.ToolTip.text: i18n("Browse for Pi binary")
                QQC2.ToolTip.visible: hovered
                onClicked: fileDialog.open()

                FileDialog {
                    id: fileDialog
                    title: i18n("Select Pi Binary")
                    fileMode: FileDialog.OpenFile
                    nameFilters: ["Executable files (*)"]
                    onAccepted: {
                        var path = selectedFile.toString()
                        if (path.startsWith("file://")) {
                            path = path.substring(7)
                        }
                        PiProcessManager.binaryPath = path
                    }
                }
            }

            QQC2.Button {
                icon.name: "search"
                display: QQC2.AbstractButton.IconOnly
                QQC2.ToolTip.text: i18n("Auto-detect Pi binary")
                QQC2.ToolTip.visible: hovered
                onClicked: {
                    if (!PiProcessManager.autoDetectBinary()) {
                        applicationWindow().showPassiveNotification(i18n("Could not find Pi binary"))
                    }
                }
            }
        }

        QQC2.Label {
            text: PiProcessManager.validateBinaryPath(binaryPathField.text)
                ? i18nc("@info", "Binary found and executable")
                : i18nc("@info", "Binary not found or not executable")
            font: Kirigami.Theme.smallFont
            color: PiProcessManager.validateBinaryPath(binaryPathField.text) ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.negativeTextColor
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }

        QQC2.Label {
            text: i18nc("@info", "Pi runs in RPC mode (stdin/stdout JSONL protocol). No server URL or password needed.")
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18nc("@title:group", "Server Logs")
        }

        ListView {
            id: logListView
            Kirigami.FormData.label: i18nc("@label", "Output:")
            Layout.fillWidth: true
            Layout.preferredHeight: 200
            clip: true

            model: PiProcessManager.logs
            delegate: QQC2.Label {
                width: logListView.width
                text: modelData
                font.family: "monospace"
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                color: modelData.indexOf("[ERROR]") >= 0 || modelData.indexOf("[STDERR]") >= 0
                       ? Kirigami.Theme.negativeTextColor
                       : Kirigami.Theme.textColor
            }

            QQC2.ScrollBar.vertical: QQC2.ScrollBar {}

            Connections {
                target: PiProcessManager
                function onLogsChanged() {
                    Qt.callLater(function() {
                        logListView.positionViewAtEnd()
                    })
                }
            }

            Component.onCompleted: {
                if (PiProcessManager.logs.length > 0) {
                    logListView.positionViewAtEnd()
                }
            }
        }
    }
}
