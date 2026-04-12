/*
    SPDX-FileCopyrightText: 2024 Denys Madureira <denysmb@zoho.com>
    SPDX-License-Identifier: LGPL-2.1-or-later
*/

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import "../components" as COMPONENTS
import "../logic/ApiClient.js" as ApiClient

Kirigami.ScrollablePage {
    id: root

    title: i18nc("@title", "OpenClaw")

    property var settings: null

    ListModel {
        id: instancesModel
    }

    Component.onCompleted: {
        if (root.settings) {
            loadInstances()
        }
    }

    function generateUuid() {
        return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
            var r = Math.random() * 16 | 0
            var v = c === 'x' ? r : (r & 0x3 | 0x8)
            return v.toString(16)
        })
    }

    function loadInstances() {
        instancesModel.clear()
        try {
            var instances = JSON.parse(root.settings.openclawInstances || "[]")
            console.log("Loaded instances:", instances.length)
            for (var i = 0; i < instances.length; i++) {
                console.log("Instance", i, ":", JSON.stringify(instances[i]))
                if (instances[i].enabled === undefined) {
                    instances[i].enabled = true
                }
                if (!instances[i].id) {
                    instances[i].id = generateUuid()
                }
                instancesModel.append(instances[i])
            }
        } catch (e) {
            console.error("Failed to parse instances:", e)
        }
    }

    function saveInstances() {
        var instances = []
        for (var i = 0; i < instancesModel.count; i++) {
            var item = instancesModel.get(i)
            instances.push({
                id: item.id,
                displayName: item.displayName,
                url: item.url,
                token: item.token,
                enabled: item.enabled !== undefined ? item.enabled : true
            })
        }
        root.settings.openclawInstances = JSON.stringify(instances)
        console.log("Saved instances:", root.settings.openclawInstances)
    }

    function addInstance(instance) {
        if (instance === undefined) {
            instance = {
                id: generateUuid(),
                displayName: i18nc("@info", "New Instance"),
                url: "",
                token: "",
                enabled: true
            }
        }
        if (instance.enabled === undefined) {
            instance.enabled = true
        }
        if (!instance.id) {
            instance.id = generateUuid()
        }
        instancesModel.append(instance)
        saveInstances()
    }

    function updateInstance(index, instance) {
        var existing = instancesModel.get(index)
        if (existing.enabled !== undefined) {
            instance.enabled = existing.enabled
        }
        instancesModel.set(index, instance)
        saveInstances()
    }

    function removeInstance(index) {
        instancesModel.remove(index)
        saveInstances()
    }

    function toggleInstanceEnabled(index) {
        var item = instancesModel.get(index)
        instancesModel.setProperty(index, "enabled", !item.enabled)
        saveInstances()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.largeSpacing

        QQC2.Label {
            text: i18nc("@info", "Configure multiple OpenClaw instances. Add, edit, or remove instances using the buttons below.")
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        Kirigami.Heading {
            visible: instancesModel.count > 0
            level: 2
            text: i18nc("@title:group", "Instances")
            Layout.fillWidth: true
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: instancesModel.count > 0
            spacing: Kirigami.Units.smallSpacing

            Repeater {
                model: instancesModel
                delegate: COMPONENTS.InstanceCard {
                    Layout.fillWidth: true
                    instanceDisplayName: instancesModel.get(index).displayName
                    instanceUrl: instancesModel.get(index).url
                    instanceToken: instancesModel.get(index).token
                    instanceEnabled: instancesModel.get(index).enabled !== undefined ? instancesModel.get(index).enabled : true
                    onEditClicked: editSheet.openInstance(index)
                    onRemoveClicked: root.removeInstance(index)
                    onEnabledToggled: root.toggleInstanceEnabled(index)
                }
            }
        }

        QQC2.Button {
            id: addButton
            text: i18nc("@action:button", "Add Instance")
            icon.name: "list-add-symbolic"
            Layout.fillWidth: true
            onClicked: editSheet.openNewInstance()
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }

        Kirigami.Dialog {
            id: editSheet
            title: i18nc("@title:window", "Edit Instance")

            property int editingIndex: -1

            function openNewInstance() {
                editingIndex = -1
                displayNameField.text = i18nc("@info", "New Instance")
                urlField.text = ""
                tokenField.text = ""
                editSheet.title = i18nc("@title:window", "Add Instance")
                editSheet.open()
            }

            function openInstance(index) {
                editingIndex = index
                var instance = instancesModel.get(index)
                displayNameField.text = instance.displayName
                urlField.text = instance.url
                tokenField.text = instance.token
                editSheet.title = i18nc("@title:window", "Edit Instance")
                editSheet.open()
            }

            standardButtons: Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel

            property string testState: "idle"
            property int testErrorStatus: 0
            property string testErrorStatusText: ""
            property int testModelCount: 0
            property var testXhr: null

            Timer {
                id: testTimeoutTimer
                interval: 10000
                onTriggered: {
                    if (editSheet.testXhr) {
                        editSheet.testXhr.onreadystatechange = function() {}
                        editSheet.testXhr.onload = function() {}
                        editSheet.testXhr.abort()
                        editSheet.testXhr = null
                    }
                    editSheet.testState = "error"
                    editSheet.testErrorStatusText = "TIMEOUT"
                }
            }

            function resetTestState() {
                testState = "idle"
                testErrorStatus = 0
                testErrorStatusText = ""
                testModelCount = 0
            }

            function runTest() {
                resetTestState()

                if (!urlField.text.trim()) {
                    testState = "error"
                    testErrorStatusText = "EMPTY_URL"
                    return
                }

                if (!/^https?:\/\//i.test(urlField.text.trim())) {
                    testState = "error"
                    testErrorStatusText = "INVALID_URL"
                    return
                }

                if (!tokenField.text.trim()) {
                    testState = "error"
                    testErrorStatusText = "EMPTY_TOKEN"
                    return
                }

                testState = "testing"

                var baseUrl = urlField.text.trim()
                var token = tokenField.text.trim()
                var extraHeaders = { "x-openclaw-agent-id": "main" }

                testXhr = ApiClient.testConnection(
                    "openclaw",
                    baseUrl,
                    token,
                    "",
                    extraHeaders,
                    true,
                    function(result) {
                        testTimeoutTimer.stop()
                        testXhr = null
                        testState = "success"
                        testModelCount = result.modelCount
                    },
                    function(errorInfo) {
                        testTimeoutTimer.stop()
                        testXhr = null
                        testState = "error"
                        testErrorStatus = errorInfo.status
                        testErrorStatusText = errorInfo.statusText
                    }
                )

                testTimeoutTimer.start()
            }

            onAccepted: {
                var instance = {
                    displayName: displayNameField.text,
                    url: urlField.text,
                    token: tokenField.text
                }
                if (editingIndex >= 0) {
                    root.updateInstance(editingIndex, instance)
                } else {
                    root.addInstance(instance)
                }
            }

            Kirigami.FormLayout {
                QQC2.TextField {
                    id: displayNameField
                    Kirigami.FormData.label: i18nc("@label:textbox", "Display Name:")
                    Layout.fillWidth: true
                    placeholderText: i18nc("@info:placeholder", "e.g., Local OpenClaw, Remote Server")
                }

                QQC2.TextField {
                    id: urlField
                    Kirigami.FormData.label: i18nc("@label:textbox", "URL:")
                    Layout.fillWidth: true
                    placeholderText: "http://127.0.0.1:18789"
                    onTextChanged: editSheet.resetTestState()
                }

                QQC2.TextField {
                    id: tokenField
                    Kirigami.FormData.label: i18nc("@label:textbox", "Token:")
                    Layout.fillWidth: true
                    placeholderText: i18nc("@info:placeholder", "Enter your token")
                    echoMode: QQC2.TextField.Password
                    onTextChanged: editSheet.resetTestState()
                }

                Kirigami.InlineMessage {
                    id: testResultMessage
                    Layout.fillWidth: true
                    Layout.topMargin: Kirigami.Units.smallSpacing
                    visible: true
                    type: {
                        if (editSheet.testState === "idle") return Kirigami.MessageType.Information;
                        if (editSheet.testState === "testing") return Kirigami.MessageType.Information;
                        if (editSheet.testState === "success") return Kirigami.MessageType.Positive;
                        if (editSheet.testState === "error") return Kirigami.MessageType.Error;
                        return Kirigami.MessageType.Information;
                    }
                    text: {
                        if (editSheet.testState === "idle") return i18nc("@info", "Connection has not been tested.");
                        if (editSheet.testState === "testing") return i18nc("@info", "Testing connection…");
                        if (editSheet.testState === "success") return i18nc("@info", "Connection successful!");
                        if (editSheet.testErrorStatusText === "TIMEOUT") return i18nc("@info", "Connection timed out after 10 seconds.");
                        if (editSheet.testErrorStatusText === "NETWORK_ERROR") return i18nc("@info", "Could not reach the server. Check the URL and network connection.");
                        if (editSheet.testErrorStatusText === "UNAUTHORIZED") return i18nc("@info", "Authentication failed. Check your API token.");
                        if (editSheet.testErrorStatusText === "NOT_FOUND") return i18nc("@info", "Server not found at this URL. Check the API URL.");
                        if (editSheet.testErrorStatusText === "EMPTY_URL") return i18nc("@info", "Please enter a URL before testing.");
                        if (editSheet.testErrorStatusText === "EMPTY_TOKEN") return i18nc("@info", "Please enter a token before testing.");
                        if (editSheet.testErrorStatusText === "INVALID_URL") return i18nc("@info", "URL must start with http:// or https://.");
                        if (editSheet.testErrorStatus > 0) return i18nc("@info", "Server returned error %1: %2").arg(editSheet.testErrorStatus).arg(editSheet.testErrorStatusText);
                        return i18nc("@info", "Unknown connection error.");
                    }
                    actions: [
                        Kirigami.Action {
                            text: i18nc("@action:button", "Test Now")
                            visible: editSheet.testState === "idle"
                            onTriggered: editSheet.runTest()
                        }
                    ]
                }
            }
        }
    }
}