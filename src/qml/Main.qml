/*
    SPDX-FileCopyrightText: 2024 Denys Madureira <denysmb@zoho.com>
    SPDX-License-Identifier: LGPL-2.1-or-later
*/

import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import Qt.labs.platform as Platform
import org.kde.kirigami as Kirigami
import org.kde.coreaddons
import org.koderoots.chatqt

Kirigami.ApplicationWindow {
    id: root

    width: Kirigami.Units.gridUnit * 48
    height: Kirigami.Units.gridUnit * 40

    minimumWidth: Kirigami.Units.gridUnit * 48
    minimumHeight: Kirigami.Units.gridUnit * 40

    globalDrawer: Kirigami.GlobalDrawer {
        title: i18n("ChatQT")
        titleIcon: "dialog-messages"
        isMenu: true

        actions: [
            Kirigami.Action {
                text: i18n("Disable auto scroll")
                icon.name: "transform-move-vertical"
                checkable: true
                checked: chatPage.disableAutoScroll
                onTriggered: chatPage.disableAutoScroll = !chatPage.disableAutoScroll
            },
            Kirigami.Action {
                text: i18nc("@action", "About")
                icon.name: "help-about"
                onTriggered: root.pageStack.layers.push(aboutPage)
            }
        ]
    }

    Component {
        id: aboutPage
        Kirigami.AboutPage {
            aboutData: AboutData
        }
    }

    pageStack.initialPage: ChatPage {
        id: chatPage
    }

    onClosing: function(close) {
        close.accepted = false
        root.hide()
    }

    Platform.SystemTrayIcon {
        id: systemTray

        visible: true
        icon.name: "org.koderoots.chatqt"

        tooltip: i18n("ChatQT")

        Component.onCompleted: {
            if (systemTray.supportsMessages) {
                systemTray.showMessage(i18n("ChatQT"), i18n("ChatQT is running in the system tray"))
            }
        }

        menu: Platform.Menu {
            Platform.MenuItem {
                text: i18n("Show ChatQT")
                onTriggered: {
                    root.show()
                    root.raise()
                }
            }

            Platform.MenuSeparator {}

            Platform.MenuItem {
                text: i18n("Quit")
                onTriggered: Qt.quit()
            }
        }

        onActivated: function(reason) {
            if (reason === Platform.SystemTrayIcon.Trigger) {
                if (!root.visible || root.visibility === Window.Hidden) {
                    root.show()
                    root.raise()
                } else {
                    root.hide()
                }
            }
        }
    }
}
