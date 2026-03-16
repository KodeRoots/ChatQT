/*
    SPDX-FileCopyrightText: 2024 Denys Madureira <denysmb@zoho.com>
    SPDX-License-Identifier: LGPL-2.1-or-later
*/

import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Rectangle {
    id: root

    signal sendMessage(string message)

    property bool isProviderConfigured: false
    property bool isLoading: false

    implicitHeight: inputLayout.implicitHeight + Kirigami.Units.largeSpacing * 2
    radius: Kirigami.Units.cornerRadius

    color: Kirigami.Theme.backgroundColor
    border.width: 1
    border.color: Kirigami.Theme.textColor

    RowLayout {
        id: inputLayout

        anchors.fill: parent
        anchors.margins: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing

        Controls.ScrollView {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(messageField.implicitHeight, Kirigami.Units.gridUnit * 6)

            visible: root.isProviderConfigured
            clip: true

            Controls.TextArea {
                id: messageField

                placeholderText: i18n("Type your message...")
                wrapMode: Controls.TextArea.Wrap
                enabled: root.isProviderConfigured && !root.isLoading

                Keys.onReturnPressed: {
                    if (event.modifiers & Qt.ControlModifier) {
                        root.sendMessage(messageField.text)
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

        Controls.Button {
            id: sendButton

            visible: root.isProviderConfigured
            enabled: root.isProviderConfigured && !root.isLoading && messageField.text.trim()

            text: i18n("Send")
            icon.name: "document-send"

            display: Controls.AbstractButton.TextBesideIcon

            Controls.ToolTip.text: i18n("Send message (Ctrl+Enter)")
            Controls.ToolTip.delay: Kirigami.Units.toolTipDelay
            Controls.ToolTip.visible: hovered

            onClicked: {
                if (messageField.text.trim()) {
                    root.sendMessage(messageField.text)
                }
            }
        }

        Controls.Label {
            Layout.fillWidth: true
            visible: !root.isProviderConfigured
            text: i18n("Configure a provider to start chatting")
            color: Kirigami.Theme.disabledTextColor
            horizontalAlignment: Qt.AlignHCenter
        }
    }

    function clearText() {
        messageField.text = ''
    }

    function getText() {
        return messageField.text
    }
}