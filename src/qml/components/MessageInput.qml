/*
    SPDX-FileCopyrightText: 2024 Denys Madureira <denysmb@zoho.com>
    SPDX-License-Identifier: LGPL-2.1-or-later
*/

import QtQuick
import QtQuick.Controls
import QtQuick.Controls as Controls
import QtQuick.Layouts
import Qt.labs.platform as Labs
import org.kde.kirigami as Kirigami
import org.kde.chatqt

RowLayout {
    id: root

    signal sendMessage(string message, var attachments)
    signal cancelOrStop()

    property bool isProviderConfigured: false
    property bool isLoading: false
    property bool isStreaming: false
    property var attachedFiles: []

    property alias textField: messageField

    spacing: Kirigami.Units.smallSpacing

    function sendCurrentMessage() {
        root.sendMessage(messageField.text, root.attachedFiles)
        messageField.text = ""
        root.attachedFiles = []
    }

    function removeAttachment(index) {
        root.attachedFiles = root.attachedFiles.filter(function(_, i) {
            return i !== index
        })
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing

        visible: root.isProviderConfigured

        Flow {
            Layout.fillWidth: true
            visible: root.attachedFiles.length > 0
            spacing: Kirigami.Units.smallSpacing

            Repeater {
                model: root.attachedFiles

                delegate: Rectangle {
                    implicitWidth: chipRow.implicitWidth + Kirigami.Units.smallSpacing * 2
                    implicitHeight: chipRow.implicitHeight + Kirigami.Units.smallSpacing
                    radius: implicitHeight / 2
                    color: Kirigami.Theme.alternateBackgroundColor
                    border.width: 1
                    border.color: Qt.rgba(Kirigami.Theme.disabledTextColor.r, Kirigami.Theme.disabledTextColor.g, Kirigami.Theme.disabledTextColor.b, 0.3)

                    RowLayout {
                        id: chipRow
                        anchors.centerIn: parent
                        spacing: Kirigami.Units.smallSpacing

                        Kirigami.Icon {
                            source: modelData.isImage ? "image-x-generic-symbolic" : "text-x-generic-symbolic"
                            implicitWidth: Kirigami.Units.iconSizes.small
                            implicitHeight: Kirigami.Units.iconSizes.small
                        }

                        Controls.Label {
                            text: modelData.name
                            font: Kirigami.Theme.smallFont
                            elide: Text.ElideMiddle
                            Layout.maximumWidth: Kirigami.Units.gridUnit * 12
                        }

                        Controls.ToolButton {
                            icon.name: "dialog-close-symbolic"
                            icon.width: Kirigami.Units.iconSizes.small
                            icon.height: Kirigami.Units.iconSizes.small
                            display: Controls.AbstractButton.IconOnly
                            onClicked: root.removeAttachment(index)

                            Controls.ToolTip.text: i18n("Remove attachment")
                            Controls.ToolTip.delay: Kirigami.Units.toolTipDelay
                            Controls.ToolTip.visible: hovered
                        }
                    }
                }
            }
        }

        Item {
            id: container

            Layout.fillWidth: true
            Layout.preferredHeight: Kirigami.Units.gridUnit * 6

            enabled: root.isProviderConfigured && !root.isLoading

            Kirigami.Theme.colorSet: Kirigami.Theme.View
            Kirigami.Theme.inherit: false

        Rectangle {
            anchors.fill: parent

            color: Kirigami.Theme.backgroundColor
            radius: Kirigami.Units.smallSpacing
            border.width: 1
            border.color: messageField.activeFocus || messageField.hovered ? Kirigami.Theme.activeTextColor : Qt.rgba(Kirigami.Theme.disabledTextColor.r, Kirigami.Theme.disabledTextColor.g, Kirigami.Theme.disabledTextColor.b, 0.3)

            Flickable {
                id: flickable

                anchors.fill: parent
                anchors.margins: 1

                flickableDirection: Flickable.VerticalFlick
                clip: true

                contentWidth: width
                contentHeight: messageField.implicitHeight

                ScrollBar.vertical: Controls.ScrollBar {
                    id: verticalScrollBar
                    policy: Controls.ScrollBar.AsNeeded
                }

                TextArea.flickable: TextArea {
                    id: messageField

                    focus: true
                    placeholderText: i18n("Type your message...")
                    wrapMode: TextArea.Wrap
                    rightPadding: verticalScrollBar.visible ? verticalScrollBar.width + Kirigami.Units.smallSpacing : Kirigami.Units.smallSpacing
                    leftPadding: Kirigami.Units.smallSpacing
                    topPadding: Kirigami.Units.smallSpacing
                    bottomPadding: Kirigami.Units.smallSpacing
                    background: null

                    Keys.onReturnPressed: {
                        if (event.modifiers & Qt.ControlModifier) {
                            if (root.isLoading) {
                                root.cancelOrStop()
                                event.accepted = true
                            } else {
                                root.sendCurrentMessage()
                            }
                        } else {
                            event.accepted = false;
                        }
                    }

                    Controls.BusyIndicator {
                        anchors.centerIn: parent
                        running: root.isLoading
                        implicitWidth: Kirigami.Units.iconSizes.medium
                        implicitHeight: Kirigami.Units.iconSizes.medium
                    }
                }
            }
        }
    }
    }

    Controls.Button {
        id: attachButton

        Layout.alignment: Qt.AlignBottom
        Layout.preferredHeight: container.height

        visible: root.isProviderConfigured
        enabled: root.isProviderConfigured && !root.isLoading

        icon.name: "mail-attachment-symbolic"
        display: Controls.AbstractButton.IconOnly

        Controls.ToolTip.text: i18n("Attach files")
        Controls.ToolTip.delay: Kirigami.Units.toolTipDelay
        Controls.ToolTip.visible: hovered

        onClicked: fileDialog.open()
    }

    Labs.FileDialog {
        id: fileDialog

        fileMode: Labs.FileDialog.OpenFiles

        onAccepted: {
            var newFiles = root.attachedFiles.slice()
            for (var i = 0; i < fileDialog.files.length; i++) {
                var result = FileHelper.readFile(fileDialog.files[i])
                if (result.success) {
                    newFiles.push({
                        "name": result.name,
                        "mime": result.mime,
                        "isImage": result.isImage,
                        "content": result.content
                    })
                } else {
                    applicationWindow().showPassiveNotification(
                        i18n("Could not attach %1: %2", result.name, result.error)
                    )
                }
            }
            root.attachedFiles = newFiles
        }
    }

    Controls.Button {
        Layout.alignment: Qt.AlignBottom
        Layout.preferredHeight: container.height

        visible: root.isProviderConfigured

        // Dynamic enable state
        enabled: root.isProviderConfigured && (
            root.isLoading ? true : messageField.text.trim().length > 0 || root.attachedFiles.length > 0
        )

        // Dynamic text
        text: root.isLoading ? (root.isStreaming ? i18n("Stop") : i18n("Cancel")) : i18n("Send")

        // Dynamic icon
        icon.name: root.isLoading ? "process-stop" : "document-send"

        display: Controls.AbstractButton.IconOnly

        Controls.ToolTip.text: root.isLoading
            ? (root.isStreaming ? i18n("Stop streaming (Ctrl+Enter)") : i18n("Cancel request (Ctrl+Enter)"))
            : i18n("Send message (Ctrl+Enter)")
        Controls.ToolTip.delay: Kirigami.Units.toolTipDelay
        Controls.ToolTip.visible: hovered

        onClicked: {
            if (root.isLoading) {
                root.cancelOrStop()
            } else if (messageField.text.trim() || root.attachedFiles.length > 0) {
                root.sendCurrentMessage()
            }
        }
    }

    Controls.Label {
        Layout.margins: Kirigami.Units.smallSpacing
        Layout.fillWidth: true
        visible: !root.isProviderConfigured
        text: i18n("Configure a provider to start chatting")
        color: Kirigami.Theme.disabledTextColor
        horizontalAlignment: Qt.AlignHCenter
        wrapMode: Text.WordWrap
    }

    function clearText() {
        messageField.text = ''
    }

    function focusInput() {
        messageField.forceActiveFocus()
    }
}
