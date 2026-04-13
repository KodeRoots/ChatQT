/*
    SPDX-FileCopyrightText: 2026 Denys Madureira <denys@koderoots.org>
    SPDX-License-Identifier: LGPL-2.1-or-later
*/

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

import "../components"

ColumnLayout {
    id: root

    property alias sessionModel: sessionListView.model
    property int activeSessionIndex: -1

    signal sessionClicked(int index)
    signal sessionDeleteClicked(int index)

    spacing: 0

    Kirigami.Heading {
        level: 2
        text: i18n("Sessions")
        Layout.fillWidth: true
        Layout.preferredHeight: providerComboBoxRow.height
        Layout.topMargin: Kirigami.Units.smallSpacing * 2
        Layout.leftMargin: Kirigami.Units.smallSpacing
        Layout.rightMargin: Kirigami.Units.smallSpacing
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
            width: sessionListView.width
            sessionTitle: model.title
            sessionProvider: model.provider
            sessionTimestamp: model.timestamp
            isActive: model.index === root.activeSessionIndex

            onClicked: root.sessionClicked(model.index)
            onDeleteClicked: root.sessionDeleteClicked(model.index)
        }

        QQC2.ScrollBar.vertical: QQC2.ScrollBar {}
    }
}
