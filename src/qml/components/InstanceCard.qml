/*
    SPDX-FileCopyrightText: 2024 Denys Madureira <denysmb@zoho.com>
    SPDX-License-Identifier: LGPL-2.1-or-later
*/

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.AbstractCard {
    id: root

    property string instanceDisplayName
    property string instanceUrl
    property string instanceToken
    property bool instanceEnabled

    signal editClicked
    signal removeClicked
    signal enabledToggled(bool newEnabled)

    contentItem: ColumnLayout {
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            QQC2.CheckBox {
                checked: root.instanceEnabled
                onToggled: root.enabledToggled(checked)
                display: QQC2.AbstractButton.IconOnly
            }

            Kirigami.Heading {
                level: 3
                text: root.instanceDisplayName != "" ? root.instanceDisplayName : i18nc("@info", "Unnamed Instance")
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            QQC2.ToolButton {
                icon.name: "document-edit-symbolic"
                display: QQC2.AbstractButton.IconOnly
                text: i18nc("@action:button", "Edit")
                onClicked: root.editClicked()

                QQC2.ToolTip {
                    text: parent.text
                    delay: Kirigami.Units.toolTipDelay
                }
            }

            QQC2.ToolButton {
                icon.name: "delete-symbolic"
                display: QQC2.AbstractButton.IconOnly
                text: i18nc("@action:button", "Remove")
                onClicked: root.removeClicked()

                QQC2.ToolTip {
                    text: parent.text
                    delay: Kirigami.Units.toolTipDelay
                }
            }
        }

        Kirigami.Separator {
            Layout.fillWidth: true
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            opacity: root.instanceEnabled ? 1.0 : 0.5
            Behavior on opacity { NumberAnimation { duration: Kirigami.Units.shortDuration } }

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.largeSpacing

                QQC2.Label {
                    text: i18nc("@label", "URL:")
                    font: Kirigami.Theme.smallFont
                    color: Kirigami.Theme.disabledTextColor
                }

                QQC2.Label {
                    text: root.instanceUrl != "" ? root.instanceUrl : i18nc("@info", "Not set")
                    font: Kirigami.Theme.defaultFont
                    color: root.instanceUrl != "" ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor
                    Layout.fillWidth: true
                    wrapMode: Text.ElideMiddle
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.largeSpacing

                QQC2.Label {
                    text: i18nc("@label", "Token:")
                    font: Kirigami.Theme.smallFont
                    color: Kirigami.Theme.disabledTextColor
                }

                QQC2.Label {
                    text: root.instanceToken != ""
                        ? i18nc("@info", "Configured — API key is saved securely")
                        : i18nc("@info", "Missing — no API key configured")
                    font: Kirigami.Theme.defaultFont
                    color: root.instanceToken != "" ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                }
            }
        }
    }
}