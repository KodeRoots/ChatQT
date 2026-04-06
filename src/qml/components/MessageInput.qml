/*
    SPDX-FileCopyrightText: 2024 Denys Madureira <denysmb@zoho.com>
    SPDX-License-Identifier: LGPL-2.1-or-later
*/

import QtQuick
import QtQuick.Controls
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

RowLayout {
    id: root

    signal sendMessage(string message)
    signal cancelOrStop()

    property bool isProviderConfigured: false
    property bool isLoading: false
    property bool isStreaming: false

    property alias textField: messageField

    spacing: Kirigami.Units.smallSpacing

    Item {
        id: container

        Layout.fillWidth: true
        Layout.preferredHeight: Kirigami.Units.gridUnit * 6

        visible: root.isProviderConfigured
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
                                root.sendMessage(messageField.text)
                                messageField.text = ""
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

    Controls.Button {
        Layout.alignment: Qt.AlignBottom
        Layout.preferredHeight: container.height

        visible: root.isProviderConfigured

        // Dynamic enable state
        enabled: root.isProviderConfigured && (
            root.isLoading ? true : !root.isLoading && messageField.text.trim()
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
            } else if (messageField.text.trim()) {
                root.sendMessage(messageField.text)
                messageField.text = ""
            }
        }
    }

    Controls.Label {
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