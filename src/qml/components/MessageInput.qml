/*
    SPDX-FileCopyrightText: 2024 Denys Madureira <denysmb@zoho.com>
    SPDX-License-Identifier: LGPL-2.1-or-later
*/

import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

RowLayout {
    id: root

    signal sendMessage(string message)

    property bool isProviderConfigured: false
    property bool isLoading: false

    spacing: Kirigami.Units.smallSpacing

    Controls.TextArea {
        id: messageField

        Layout.fillWidth: true
        Layout.preferredHeight: Math.max(implicitHeight, Kirigami.Units.gridUnit * 3)

        visible: root.isProviderConfigured
        enabled: root.isProviderConfigured && !root.isLoading

        placeholderText: i18n("Type your message...")
        wrapMode: Controls.TextArea.Wrap

        Keys.onReturnPressed: {
            if (event.modifiers & Qt.ControlModifier) {
                root.sendMessage(messageField.text)
                messageField.text = ""
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

    Controls.Button {
        Layout.alignment: Qt.AlignBottom
        
        Layout.fillHeight: true

        visible: root.isProviderConfigured
        enabled: root.isProviderConfigured && !root.isLoading && messageField.text.trim()

        text: i18n("Send")
        icon.name: "document-send"
        display: Controls.AbstractButton.IconOnly

        Controls.ToolTip.text: i18n("Send message (Ctrl+Enter)")
        Controls.ToolTip.delay: Kirigami.Units.toolTipDelay
        Controls.ToolTip.visible: hovered

        onClicked: {
            if (messageField.text.trim()) {
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
}