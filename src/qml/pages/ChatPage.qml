/*
    SPDX-FileCopyrightText: 2024 Denys Madureira <denysmb@zoho.com>
    SPDX-License-Identifier: LGPL-2.1-or-later
*/

import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

import "../components"
import "../logic/ApiClient.js" as ApiClient

Kirigami.Page {
    id: root

    title: i18n("Chat")

    property string currentModel: ''
    property var listModelController: null
    property var promptArray: []
    property var modelsArray: []
    property bool isLoading: false
    property bool hasLocalModel: false
    property bool disableAutoScroll: false
    property string currentProvider: settings.provider
    property bool thinkingEnabled: !settings.openaiCompatibleDisableThinking

    QtObject {
        id: settings
        property string provider: "ollama"
        property string openclawUrl: ""
        property string openclawToken: ""
        property string openaiCompatibleUrl: ""
        property string openaiCompatibleToken: ""
        property string openaiCompatibleModel: ""
        property bool openaiCompatibleDisableThinking: false
    }

    function isProviderConfigured() {
        const provider = currentProvider;
        if (provider === "ollama") {
            return hasLocalModel;
        } else if (provider === "openclaw") {
            return settings.openclawUrl && settings.openclawToken;
        } else if (provider === "openai-compatible") {
            return settings.openaiCompatibleUrl &&
                   settings.openaiCompatibleToken &&
                   settings.openaiCompatibleModel;
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
                settings.openclawUrl,
                settings.openclawToken,
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
                settings.openaiCompatibleUrl,
                settings.openaiCompatibleToken,
                settings.openaiCompatibleModel,
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

    Component.onCompleted: {
        if (currentProvider === "ollama") {
            getModels();
        }
    }

    actions: [
        Kirigami.Action {
            text: i18n("Clear chat")
            icon.name: "edit-clear"
            onTriggered: root.clearChat()
        },
        Kirigami.Action {
            text: i18n("Disable auto scroll")
            icon.name: "transform-move-vertical"
            checkable: true
            checked: root.disableAutoScroll
            onTriggered: root.disableAutoScroll = !root.disableAutoScroll
        }
    ]

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Header {
            id: header

            Layout.fillWidth: true

            isProviderConfigured: root.isProviderConfigured()
            isLoading: root.isLoading
            currentProvider: root.currentProvider
            hasLocalModel: root.hasLocalModel
            modelsArray: root.modelsArray
            currentModel: root.currentModel
            thinkingEnabled: root.thinkingEnabled

            onClearChatRequested: root.clearChat()
            onModelSelected: function(modelValue) {
                root.currentModel = modelValue;
                root.clearChat();
            }
            onSettingsRequested: {
                applicationWindow().pageStack.pushDialogLayer(Qt.resolvedUrl("../settings/SettingsPage.qml"), {
                    settings: settings
                }, {
                    title: i18n("Settings")
                });
            }
        }

        ListView {
            id: listView

            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: Kirigami.Units.smallSpacing

            spacing: Kirigami.Units.smallSpacing
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
                width: listView.width
                messageText: ApiClient.preprocessMarkdown(content)
                senderName: name
            }

            Controls.ScrollBar.vertical: Controls.ScrollBar {}
        }

        MessageInput {
            id: messageInput

            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.smallSpacing

            isProviderConfigured: root.isProviderConfigured()
            isLoading: root.isLoading

            onSendMessage: function(message) {
                root.sendMessage(message);
            }
        }

        Controls.Button {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.smallSpacing

            text: i18n("Refresh models list")
            visible: currentProvider === "ollama" && !hasLocalModel

            onClicked: getModels()
        }
    }
}