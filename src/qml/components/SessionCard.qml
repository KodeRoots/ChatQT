/*
    SPDX-FileCopyrightText: 2026 Denys Madureira <denysmb@zoho.com>
    SPDX-License-Identifier: LGPL-2.1-or-later
*/

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.AbstractCard {
    id: root

    property string sessionTitle: ""
    property string sessionProvider: ""
    property string sessionTimestamp: ""
    property bool isActive: false

    signal clicked
    signal deleteClicked

    showClickFeedback: true

    background: Rectangle {
        radius: Kirigami.Units.smallSpacing
        color: root.isActive
            ? Kirigami.Theme.highlightColor
            : Kirigami.Theme.backgroundColor
        border.color: root.isActive
            ? Kirigami.Theme.highlightColor
            : Kirigami.ColorUtils.tintWithAlpha(
                Kirigami.Theme.textColor,
                Kirigami.Theme.backgroundColor,
                0.8
              )
        border.width: 1
    }

    contentItem: ColumnLayout {
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            Layout.preferredHeight: deleteButton.height

            Kirigami.Heading {
                level: 3
                text: root.sessionTitle !== "" ? root.sessionTitle : i18nc("@info", "New Chat")
                Layout.fillWidth: true
                elide: Text.ElideRight
                maximumLineCount: 1
                color: root.isActive ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
                Layout.alignment: Qt.AlignVTop
            }

            QQC2.Button {
                id: deleteButton
                icon.name: "delete-symbolic"
                display: QQC2.AbstractButton.IconOnly
                text: i18nc("@action:button", "Delete")
                visible: mouseArea.containsMouse || root.isActive
                opacity: visible ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: Kirigami.Units.shortDuration } }

                onClicked: root.deleteClicked()

                QQC2.ToolTip {
                    text: parent.text
                    delay: Kirigami.Units.toolTipDelay
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            QQC2.Label {
                text: root.sessionProvider !== "" ? root.sessionProvider : i18nc("@info", "Unknown provider")
                font: Kirigami.Theme.smallFont
                color: root.isActive ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.disabledTextColor
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            QQC2.Label {
                text: root.sessionTimestamp
                font: Kirigami.Theme.smallFont
                color: root.isActive ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.disabledTextColor
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
