/*
    SPDX-FileCopyrightText: 2024 Denys Madureira <denysmb@zoho.com>
    SPDX-License-Identifier: LGPL-2.1-or-later
*/

import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

import "pages"

Kirigami.ApplicationWindow {
    id: root

    title: i18n("ChatQT")

    minimumWidth: Kirigami.Units.gridUnit * 20
    minimumHeight: Kirigami.Units.gridUnit * 30

    width: Kirigami.Units.gridUnit * 40
    height: Kirigami.Units.gridUnit * 50

    pageStack.initialPage: ChatPage {}
}