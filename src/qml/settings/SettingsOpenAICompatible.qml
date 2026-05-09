/*
    SPDX-FileCopyrightText: 2024 Denys Madureira <denysmb@zoho.com>
    SPDX-License-Identifier: LGPL-2.1-or-later
*/

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.koderoots.chatqt

Kirigami.ScrollablePage {
    id: root

    title: i18nc("@title", "OpenAI Compatible")

    property var settings: null

    ListModel {
        id: providersModel
    }

    Component.onCompleted: {
        if (root.settings) {
            loadProviders()
        }
    }

    function generateUuid() {
        return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
            var r = Math.random() * 16 | 0
            var v = c === 'x' ? r : (r & 0x3 | 0x8)
            return v.toString(16)
        })
    }

    function loadProviders() {
        providersModel.clear()
        try {
            var providers = JSON.parse(root.settings.openaiCompatibleProviders || "[]")
            console.log("Loaded providers:", providers.length)
            for (var i = 0; i < providers.length; i++) {
                console.log("Provider", i, ":", JSON.stringify(providers[i]))
                if (providers[i].enabled === undefined) {
                    providers[i].enabled = true
                }
                if (!providers[i].id) {
                    providers[i].id = generateUuid()
                }
                providersModel.append(providers[i])
            }
        } catch (e) {
            console.error("Failed to parse providers:", e)
        }
    }

    function saveProviders() {
        var providers = []
        for (var i = 0; i < providersModel.count; i++) {
            var item = providersModel.get(i)
            providers.push({
                id: item.id,
                displayName: item.displayName,
                url: item.url,
                token: item.token,
                model: item.model,
                enabled: item.enabled !== undefined ? item.enabled : true
            })
        }
        root.settings.openaiCompatibleProviders = JSON.stringify(providers)
        console.log("Saved providers:", root.settings.openaiCompatibleProviders)
    }

    function addProvider(provider) {
        if (provider === undefined) {
            provider = {
                id: generateUuid(),
                displayName: i18nc("@info", "New Provider"),
                url: "",
                token: "",
                model: "",
                enabled: true
            }
        }
        if (provider.enabled === undefined) {
            provider.enabled = true
        }
        if (!provider.id) {
            provider.id = generateUuid()
        }
        providersModel.append(provider)
        saveProviders()
    }

    function updateProvider(index, provider) {
        var existing = providersModel.get(index)
        if (existing.enabled !== undefined) {
            provider.enabled = existing.enabled
        }
        providersModel.set(index, provider)
        saveProviders()
    }

    function removeProvider(index) {
        providersModel.remove(index)
        saveProviders()
    }

    function toggleProviderEnabled(index) {
        var item = providersModel.get(index)
        providersModel.setProperty(index, "enabled", !item.enabled)
        saveProviders()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.largeSpacing

        QQC2.Label {
            text: i18nc("@info", "Configure multiple OpenAI-compatible API providers (OpenAI, DeepSeek, Groq, etc.). Add, edit, or remove providers using the buttons below.")
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        Kirigami.Heading {
            visible: providersModel.count > 0
            level: 2
            text: i18nc("@title:group", "Providers")
            Layout.fillWidth: true
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: providersModel.count > 0
            spacing: Kirigami.Units.smallSpacing

            Repeater {
                model: providersModel
                delegate: ProviderCard {
                    Layout.fillWidth: true
                    providerDisplayName: providersModel.get(index).displayName
                    providerUrl: providersModel.get(index).url
                    providerToken: providersModel.get(index).token
                    providerModel: providersModel.get(index).model
                    providerEnabled: providersModel.get(index).enabled !== undefined ? providersModel.get(index).enabled : true
                    onEditClicked: editSheet.openProvider(index)
                    onRemoveClicked: root.removeProvider(index)
                    onEnabledToggled: root.toggleProviderEnabled(index)
                }
            }
        }

        QQC2.Button {
            id: addButton
            text: i18nc("@action:button", "Add Provider")
            icon.name: "list-add-symbolic"
            Layout.fillWidth: true
            onClicked: editSheet.openNewProvider()
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }

        Kirigami.Dialog {
            id: editSheet
            parent: root
            title: i18nc("@title:window", "Edit Provider")
            padding: Kirigami.Units.largeSpacing
            width: Kirigami.Units.gridUnit * 28

            property int editingIndex: -1

            function openNewProvider() {
                editingIndex = -1
                displayNameField.text = i18nc("@info", "New Provider")
                urlField.text = ""
                tokenField.text = ""
                modelField.text = ""
                editSheet.title = i18nc("@title:window", "Add Provider")
                editSheet.open()
            }

            function openProvider(index) {
                editingIndex = index
                var provider = providersModel.get(index)
                displayNameField.text = provider.displayName
                urlField.text = provider.url
                tokenField.text = provider.token
                modelField.text = provider.model
                editSheet.title = i18nc("@title:window", "Edit Provider")
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

                if (!modelField.text.trim()) {
                    testState = "error"
                    testErrorStatusText = "EMPTY_MODEL"
                    return
                }

                testState = "testing"

                var baseUrl = urlField.text.trim()
                var token = tokenField.text.trim()
                var model = modelField.text.trim()

                testXhr = ApiClient.testConnection(
                    "openai-compatible",
                    baseUrl,
                    token,
                    model,
                    null,
                    false,
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
                var provider = {
                    displayName: displayNameField.text,
                    url: urlField.text,
                    token: tokenField.text,
                    model: modelField.text
                }
                if (editingIndex >= 0) {
                    root.updateProvider(editingIndex, provider)
                } else {
                    root.addProvider(provider)
                }
            }

            ColumnLayout {
                spacing: Kirigami.Units.smallSpacing

                QQC2.Label {
                    text: i18nc("@label:textbox", "Display Name:")
                    font: Kirigami.Theme.smallFont
                    color: Kirigami.Theme.disabledTextColor
                }

                QQC2.TextField {
                    id: displayNameField
                    Layout.fillWidth: true
                    placeholderText: i18nc("@info:placeholder", "e.g., DeepSeek, Groq, OpenAI")
                }

                QQC2.Label {
                    text: i18nc("@label:textbox", "API URL:")
                    font: Kirigami.Theme.smallFont
                    color: Kirigami.Theme.disabledTextColor
                }

                QQC2.TextField {
                    id: urlField
                    Layout.fillWidth: true
                    placeholderText: "https://api.openai.com/v1"
                    onTextChanged: editSheet.resetTestState()
                }

                QQC2.Label {
                    text: i18nc("@label:textbox", "API Token:")
                    font: Kirigami.Theme.smallFont
                    color: Kirigami.Theme.disabledTextColor
                }

                QQC2.TextField {
                    id: tokenField
                    Layout.fillWidth: true
                    placeholderText: i18nc("@info:placeholder", "Enter your API token")
                    echoMode: QQC2.TextField.Password
                    onTextChanged: editSheet.resetTestState()
                }

                QQC2.Label {
                    text: i18nc("@label:textbox", "Model:")
                    font: Kirigami.Theme.smallFont
                    color: Kirigami.Theme.disabledTextColor
                }

                QQC2.TextField {
                    id: modelField
                    Layout.fillWidth: true
                    placeholderText: "gpt-4"
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
                        if (editSheet.testState === "success") {
                            if (editSheet.testModelCount > 0) return i18nc("@info", "Connection successful. %1 model(s) available.").arg(editSheet.testModelCount);
                            return i18nc("@info", "Connection successful!");
                        }
                        if (editSheet.testErrorStatusText === "TIMEOUT") return i18nc("@info", "Connection timed out after 10 seconds.");
                        if (editSheet.testErrorStatusText === "NETWORK_ERROR") return i18nc("@info", "Could not reach the server. Check the URL and network connection.");
                        if (editSheet.testErrorStatusText === "UNAUTHORIZED") return i18nc("@info", "Authentication failed. Check your API token.");
                        if (editSheet.testErrorStatusText === "NOT_FOUND") return i18nc("@info", "Server not found at this URL. Check the API URL.");
                        if (editSheet.testErrorStatusText === "EMPTY_URL") return i18nc("@info", "Please enter an API URL before testing.");
                        if (editSheet.testErrorStatusText === "EMPTY_TOKEN") return i18nc("@info", "Please enter an API token before testing.");
                        if (editSheet.testErrorStatusText === "EMPTY_MODEL") return i18nc("@info", "Please enter a model name before testing.");
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
