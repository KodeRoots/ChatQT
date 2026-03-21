/*
    SPDX-FileCopyrightText: 2024 Denys Madureira <denysmb@zoho.com>
    SPDX-License-Identifier: LGPL-2.1-or-later
*/

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.chatqt

/**
 * ServerLogsViewer - An overlay sheet for viewing server logs.
 * 
 * Shows:
 * - Last 50-100 log lines
 * - Color-coded messages (errors in red, warnings in yellow)
 * - Auto-scrolls to bottom
 */
Kirigami.OverlaySheet {
    id: root

    title: i18n("Server Logs")

    property int maxLines: 100
    property var logModel: ListModel { id: logModel }

    function refreshLogs() {
        logModel.clear()
        const logs = ProcessManager.recentLogs(maxLines)
        for (let i = 0; i < logs.length; i++) {
            const log = logs[i]
            logModel.append({
                "logText": log,
                "isError": log.indexOf("[ERROR]") !== -1 || log.indexOf("error") !== -1 || log.indexOf("Error") !== -1,
                "isWarning": log.indexOf("warning") !== -1 || log.indexOf("Warning") !== -1
            })
        }
        // Scroll to bottom
        Qt.callLater(function() { logListView.positionViewAtEnd() })
    }

    function getLogColor(isError, isWarning) {
        if (isError) {
            return Kirigami.Theme.negativeTextColor
        }
        if (isWarning) {
            return Kirigami.Theme.neutralTextColor
        }
        return Kirigami.Theme.textColor
    }

    onOpened: {
        refreshLogs()
    }

    Connections {
        target: ProcessManager
        function onLogReceived(log) {
            if (!root.opened) return
            
            logModel.append({
                "logText": log,
                "isError": log.indexOf("[ERROR]") !== -1 || log.indexOf("error") !== -1 || log.indexOf("Error") !== -1,
                "isWarning": log.indexOf("warning") !== -1 || log.indexOf("Warning") !== -1
            })

            // Keep buffer size limited
            while (logModel.count > maxLines) {
                logModel.remove(0)
            }

            // Auto-scroll to bottom
            Qt.callLater(function() { logListView.positionViewAtEnd() })
        }
    }

    ColumnLayout {
        id: contentLayout

        implicitWidth: Kirigami.Units.gridUnit * 35
        implicitHeight: Kirigami.Units.gridUnit * 20
        spacing: Kirigami.Units.smallSpacing

        ListView {
            id: logListView

            Layout.fillWidth: true
            Layout.fillHeight: true

            clip: true
            model: logModel

            boundsBehavior: Flickable.StopAtBounds

            QQC2.ScrollBar.vertical: QQC2.ScrollBar {
                policy: QQC2.ScrollBar.AsNeeded
            }

            delegate: Item {
                width: logListView.width
                height: logLabel.implicitHeight + Kirigami.Units.smallSpacing

                QQC2.Label {
                    id: logLabel

                    anchors.fill: parent
                    anchors.leftMargin: Kirigami.Units.smallSpacing
                    anchors.rightMargin: Kirigami.Units.smallSpacing

                    text: model.logText
                    color: root.getLogColor(model.isError, model.isWarning)
                    font.family: "monospace"
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.9
                    wrapMode: Text.WrapAnywhere
                    elide: Text.ElideNone
                }
            }

            Kirigami.PlaceholderMessage {
                anchors.centerIn: parent
                width: parent.width - Kirigami.Units.largeSpacing * 2
                visible: logListView.count === 0
                text: i18n("No logs available")
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            QQC2.Button {
                text: i18n("Refresh")
                icon.name: "view-refresh"
                onClicked: root.refreshLogs()
            }

            QQC2.Button {
                text: i18n("Clear")
                icon.name: "edit-clear-history"
                onClicked: logModel.clear()
            }

            Item { Layout.fillWidth: true }

            QQC2.Label {
                text: i18n("%1 lines", logListView.count)
                color: Kirigami.Theme.disabledTextColor
                font: Kirigami.Theme.smallFont
            }
        }
    }
}