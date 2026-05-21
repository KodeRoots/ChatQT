/*
    SPDX-FileCopyrightText: 2026 Denys Madureira <denys@koderoots.org>
    SPDX-License-Identifier: LGPL-2.1-or-later
*/

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.koderoots.chatqt

ColumnLayout {
    id: root

    property alias sessionModel: sessionListView.model
    property string currentSessionId: ""

    signal sessionClicked(string sessionId)
    signal sessionDeleteClicked(string sessionId)
    signal newChatClicked()

    spacing: 0

    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: Kirigami.Units.gridUnit * 2
        Layout.topMargin: Kirigami.Units.smallSpacing
        Layout.leftMargin: Kirigami.Units.smallSpacing
        Layout.rightMargin: Kirigami.Units.smallSpacing

        Kirigami.Heading {
            level: 2
            text: i18n("Sessions")
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
        }
    }

    Kirigami.Separator {
        Layout.fillWidth: true
    }

    ListView {
        id: sessionListView

        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.margins: Kirigami.Units.smallSpacing

        spacing: Kirigami.Units.smallSpacing
        clip: true

        Kirigami.PlaceholderMessage {
            anchors.centerIn: parent
            width: parent.width - (Kirigami.Units.largeSpacing * 4)
            visible: sessionListView.count === 0

            icon {
                name: "view-history-symbolic"
                source: ""
                color: Kirigami.Theme.disabledTextColor
            }

            text: i18n("Your chat sessions will appear here")

            explanation: i18n("Start a new conversation to see it listed in this sidebar.")
        }

        delegate: SessionCard {
            width: sessionListView.width - Kirigami.Units.smallSpacing - (sessionScrollBar.visible ? sessionScrollBar.width : 0)
            sessionId: model.sessionId
            sessionTitle: model.title
            sessionProvider: model.provider
            sessionTimestamp: model.timestamp
            isActive: model.sessionId === root.currentSessionId
            isLoading: model.isLoading || false

            onClicked: root.sessionClicked(model.sessionId)
            onDeleteClicked: root.sessionDeleteClicked(model.sessionId)
        }

        QQC2.ScrollBar.vertical: QQC2.ScrollBar {
            id: sessionScrollBar
        }
    }
}
