/*
    SPDX-FileCopyrightText: 2024 Denys Madureira <denysmb@zoho.com>
    SPDX-License-Identifier: LGPL-2.1-or-later
*/

import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

import "../components"
import "../logic"
import "../logic/ApiClient.js" as ApiClient

Kirigami.Page {
    id: root

    title: appSettings.getProviderDisplayName()

    property string currentModel: ''
    property var listModelController: null
    property var promptArray: []
    property var modelsArray: []
    property bool isLoading: false
    property bool hasLocalModel: false
    property bool disableAutoScroll: false
    property string currentProvider: appSettings.provider
    property bool thinkingEnabled: !appSettings.openaiCompatibleDisableThinking

    padding: 0

    AppSettings {
        id: appSettings
    }

    function getProviderDisplayName() {
        return appSettings.getProviderDisplayName()
    }

    function isProviderConfigured() {
        const provider = currentProvider;
        if (provider === "ollama") {
            return hasLocalModel;
        } else if (provider === "openclaw") {
            return appSettings.openclawUrl && appSettings.openclawToken;
        } else if (provider === "openai-compatible") {
            return appSettings.openaiCompatibleUrl &&
                   appSettings.openaiCompatibleToken &&
                   appSettings.openaiCompatibleModel;
        }
        return false;
    }

    function getProviderNotConfiguredMessage() {
        if (currentProvider === "ollama") {
            return i18n("No local model found.\nPlease install some first.\n\nIf you need help, check Ollama documentation.");
        } else if (currentProvider === "openclaw") {
            return i18n("OpenClaw not configured.\nPlease set URL and Token in settings.");
        } else if (currentProvider === "openai-compatible") {
            return i18n("OpenAI Compatible not configured.\nPlease set URL, Token and Model in settings.");
        }
        return i18n("Provider not configured.");
    }

    function handleStreaming(text, oldLength, listModel) {
        if (!disableAutoScroll && listView.contentHeight > listView.height) {
            listView.positionViewAtEnd();
        }

        if (listModel.count === oldLength) {
            listModel.append({
                "name": "Assistant",
                "content": text
            });
        } else {
            const lastValue = listModel.get(oldLength);
            lastValue.content = text;
        }
    }

    function handleRequestComplete(oldLength, listModel) {
        if (listModel.count > oldLength) {
            const lastValue = listModel.get(oldLength);
            promptArray.push({ "role": "assistant", "content": lastValue.content, "images": [] });
        }
        isLoading = false;
    }

    function sendMessage(prompt) {
        if (!prompt.trim() || isLoading) return;

        listModel.append({
            "name": "User",
            "content": prompt
        });

        promptArray.push({ "role": "user", "content": prompt, "images": [] });

        isLoading = true;
        listView.positionViewAtEnd();

        if (currentProvider === "ollama") {
            ApiClient.requestOllama(
                currentModel,
                promptArray,
                listModel,
                handleStreaming,
                handleRequestComplete
            );
        } else if (currentProvider === "openclaw") {
            ApiClient.requestOpenAICompatible(
                appSettings.openclawUrl,
                appSettings.openclawToken,
                "openclaw",
                promptArray,
                true,
                { "x-openclaw-agent-id": "main" },
                true,
                listModel,
                handleStreaming,
                handleRequestComplete
            );
        } else if (currentProvider === "openai-compatible") {
            ApiClient.requestOpenAICompatible(
                appSettings.openaiCompatibleUrl,
                appSettings.openaiCompatibleToken,
                appSettings.openaiCompatibleModel,
                promptArray,
                thinkingEnabled,
                null,
                false,
                listModel,
                handleStreaming,
                handleRequestComplete
            );
        }
    }

    function getModels() {
        ApiClient.getOllamaModels(
            function(models) {
                if (models.length) {
                    hasLocalModel = true;
                    currentModel = models[0];
                    modelsArray = models.map(model => ({
                        text: ApiClient.parseTextToComboBox(model),
                        value: model
                    }));
                }
            },
            function(status, statusText) {
                console.error('Error fetching models:', status, statusText);
            }
        );
    }

    function clearChat() {
        listModelController.clear();
        promptArray = [];
    }

    function openSettings() {
        applicationWindow().pageStack.pushDialogLayer(Qt.resolvedUrl("../settings/SettingsPage.qml"), {
            settings: appSettings
        }, {
            title: i18n("Settings")
        });
    }

    Component.onCompleted: {
        if (currentProvider === "ollama") {
            getModels();
        }
    }

    actions: [
        Kirigami.Action {
            text: i18n("Settings")
            icon.name: "settings-configure"
            onTriggered: root.openSettings()
        }
    ]

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        ListView {
            id: listView

            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: Kirigami.Units.largeSpacing

            spacing: Kirigami.Units.largeSpacing
            clip: true

            Kirigami.PlaceholderMessage {
                anchors.centerIn: parent
                width: parent.width - (Kirigami.Units.largeSpacing * 4)
                visible: listView.count === 0
                text: root.isProviderConfigured() ? i18n("I am waiting for your questions...") : root.getProviderNotConfiguredMessage()
            }

            model: ListModel {
                id: listModel

                Component.onCompleted: {
                    listModelController = listModel;
                }
            }

            delegate: ChatMessage {
                width: listView.width - Kirigami.Units.largeSpacing * 2
                messageText: ApiClient.preprocessMarkdown(content)
                senderName: name
            }

            Controls.ScrollBar.vertical: Controls.ScrollBar {}
        }

        Kirigami.Separator {
            Layout.fillWidth: true
        }

        MessageInput {
            id: messageInput

            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.largeSpacing

            isProviderConfigured: root.isProviderConfigured()
            isLoading: root.isLoading

            onSendMessage: function(message) {
                root.sendMessage(message);
            }
        }

        Controls.Button {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.largeSpacing
            Layout.rightMargin: Kirigami.Units.largeSpacing
            Layout.bottomMargin: Kirigami.Units.largeSpacing

            text: i18n("Refresh models list")
            visible: currentProvider === "ollama" && !hasLocalModel

            onClicked: getModels()
        }
    }
}