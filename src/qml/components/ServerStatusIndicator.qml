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
 * ServerStatusIndicator - A compact status indicator for the OpenCode server.
 * 
 * Shows the current server status with:
 * - Color-coded icon (green=running, yellow=starting/stopping, red=error/stopped)
 * - Status text
 * - Clickable to open settings
 */
Item {
    id: root

    implicitWidth: rowLayout.implicitWidth
    implicitHeight: rowLayout.implicitHeight

    property bool compact: true
    property bool showText: true

    signal clicked()

    function getStatusColor() {
        if (ProcessManager.running) {
            return Kirigami.Theme.positiveTextColor
        }
        
        const status = ProcessManager.status
        if (status === "starting" || status === "stopping") {
            return Kirigami.Theme.neutralTextColor
        }
        if (status === "crashed") {
            return Kirigami.Theme.negativeTextColor
        }
        return Kirigami.Theme.disabledTextColor
    }

    function getStatusIcon() {
        if (ProcessManager.running) {
            return "dialog-ok"
        }
        
        const status = ProcessManager.status
        if (status === "starting") {
            return "media-playback-start"
        }
        if (status === "stopping") {
            return "media-playback-stop"
        }
        if (status === "crashed") {
            return "dialog-error"
        }
        return "dialog-cancel"
    }

    function getStatusText() {
        if (ProcessManager.running) {
            return i18n("Running")
        }
        
        const status = ProcessManager.status
        if (status === "starting") {
            return i18n("Starting...")
        }
        if (status === "stopping") {
            return i18n("Stopping...")
        }
        if (status === "crashed") {
            return i18n("Crashed")
        }
        return i18n("Stopped")
    }

    RowLayout {
        id: rowLayout
        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Icon {
            source: root.getStatusIcon()
            Layout.preferredWidth: root.compact ? Kirigami.Units.iconSizes.small : Kirigami.Units.iconSizes.smallMedium
            Layout.preferredHeight: Layout.preferredWidth
            color: root.getStatusColor()
        }

        QQC2.Label {
            visible: root.showText
            text: root.getStatusText()
            color: root.getStatusColor()
            font: root.compact ? Kirigami.Theme.smallFont : Kirigami.Theme.defaultFont
        }

        QQC2.ToolTip.text: ProcessManager.lastError || root.getStatusText()
        QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
        QQC2.ToolTip.visible: mouseArea.containsMouse
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}