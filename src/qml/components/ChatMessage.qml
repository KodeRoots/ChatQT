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

    property string messageText: ""
    property string senderName: ""

    readonly property bool isUser: senderName === "User"

    implicitHeight: messageColumn.implicitHeight + Kirigami.Units.largeSpacing * 2
    radius: Kirigami.Units.cornerRadius
    color: isUser ? Kirigami.Theme.highlightColor : Kirigami.Theme.backgroundColor

    border.width: !isUser ? 1 : 0
    border.color: Kirigami.Theme.textColor

    RowLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Icon {
            source: isUser ? "user-identity" : "dialog-messages"
            Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
            Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
            Layout.alignment: Qt.AlignTop
            color: isUser ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
        }

        ColumnLayout {
            id: messageColumn

            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing / 2

            Controls.Label {
                text: senderName
                font.weight: Font.Bold
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                color: isUser ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
            }

            TextEdit {
                id: textMessage

                Layout.fillWidth: true

                readOnly: true
                wrapMode: TextEdit.WordWrap
                text: root.messageText
                textFormat: TextEdit.MarkdownText
                color: isUser ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
                selectByMouse: true

                onLinkActivated: function(link) {
                    Qt.openUrlExternally(link)
                }

                HoverHandler {
                    id: hoverHandler
                }

                Controls.ToolTip.visible: hovered && copyButton.hovered
                Controls.ToolTip.text: i18n("Click to copy")
                Controls.ToolTip.delay: Kirigami.Units.toolTipDelay
            }
        }

        Controls.ToolButton {
            id: copyButton

            Layout.alignment: Qt.AlignTop
            visible: hoverHandler.hovered || hovered

            icon.name: "edit-copy-symbolic"
            display: Controls.AbstractButton.IconOnly
            text: i18n("Copy")

            onClicked: {
                textMessage.selectAll();
                textMessage.copy();
                textMessage.deselect();
            }

            Controls.ToolTip.text: text
            Controls.ToolTip.delay: Kirigami.Units.toolTipDelay
            Controls.ToolTip.visible: hovered

            Kirigami.Theme.inherit: isUser
            Kirigami.Theme.textColor: isUser ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
        }
    }
}