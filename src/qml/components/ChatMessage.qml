/*
    SPDX-FileCopyrightText: 2024 Denys Madureira <denysmb@zoho.com>
    SPDX-License-Identifier: LGPL-2.1-or-later
*/

import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.AbstractCard {
    id: root

    property string messageText: ""
    property string senderName: ""

    readonly property bool isUser: senderName === "User"

    Layout.fillWidth: true

    showClickFeedback: false

    contentItem: ColumnLayout {
        spacing: Kirigami.Units.smallSpacing

        Controls.Label {
            text: senderName
            font.weight: Font.Bold
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            color: isUser ? Kirigami.Theme.disabledTextColor : Kirigami.Theme.textColor
        }

        TextEdit {
            id: textMessage

            Layout.fillWidth: true

            topPadding: Kirigami.Units.smallSpacing
            bottomPadding: Kirigami.Units.smallSpacing

            readOnly: true
            wrapMode: TextEdit.WordWrap
            text: root.messageText
            textFormat: TextEdit.MarkdownText
            color: Kirigami.Theme.textColor
            selectByMouse: true

            onLinkActivated: function(link) {
                Qt.openUrlExternally(link)
            }

            HoverHandler {
                id: hoverHandler
            }
        }
    }

    Controls.ToolButton {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Kirigami.Units.smallSpacing

        icon.name: "edit-copy-symbolic"
        display: Controls.AbstractButton.IconOnly
        text: i18n("Copy")
        visible: hoverHandler.hovered

        onClicked: {
            textMessage.selectAll();
            textMessage.copy();
            textMessage.deselect();
        }

        Controls.ToolTip.text: text
        Controls.ToolTip.delay: Kirigami.Units.toolTipDelay
        Controls.ToolTip.visible: hovered
    }
}