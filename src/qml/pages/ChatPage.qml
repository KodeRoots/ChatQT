/*
    SPDX-FileCopyrightText: 2024 Denys Madureira <denysmb@zoho.com>
    SPDX-License-Identifier: LGPL-2.1-or-later
*/

import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.chatqt

import "../components"
import "../logic"
import "../logic/ApiClient.js" as ApiClient
import "../logic/OpenCodeClient.js" as OpenCodeClient

Kirigami.Page {
    id: root

    actions: [
        Kirigami.Action {
            id: thinkingAction
            text: i18n("Thinking")
            icon.name: root.thinkingEnabled ? "flash" : "flash-off"
            checkable: true
            checked: root.thinkingEnabled
            onToggled: root.toggleThinking()
        },
        Kirigami.Action {
            text: i18n("Settings")
            icon.name: "settings-configure"
            onTriggered: root.openSettings()
        },
        Kirigami.Action {
            text: i18n("New chat")
            icon.name: "list-add-symbolic"
            onTriggered: {
                root.clearChat()
                root.refreshSessionList()
            }
        }
    ]

    property string currentModel: ''
    property var listModelController: null
    property var promptArray: []
    property var modelsArray: []
    property bool isLoading: false
    property bool hasLocalModel: false
    property bool disableAutoScroll: false
    property string currentProvider: appSettings.provider
    property bool thinkingEnabled: true
    property bool isStreaming: false
    property string lastSentMessage: ""
    property var activeXhr: null
    property string currentSessionId: ""

    function buildProviderOptions() {
        var options = [
            { text: "Ollama", value: "ollama" },
            { text: "OpenCode", value: "opencode" }
        ]

        if (appSettings && appSettings.openclawEnabled) {
            var instances = appSettings.getOpenClawInstances()
            for (var i = 0; i < instances.length; i++) {
                if (instances[i].enabled) {
                    options.push({
                        text: instances[i].displayName + " (OpenClaw)",
                        value: "openclaw:" + instances[i].id
                    })
                }
            }
        }

        if (appSettings && appSettings.openaiCompatibleEnabled) {
            var providers = appSettings.getOpenaiCompatibleProviders()
            for (var i = 0; i < providers.length; i++) {
                if (providers[i].enabled) {
                    options.push({
                        text: providers[i].displayName + " (OpenAI Compatible)",
                        value: "openai-compatible:" + providers[i].id
                    })
                }
            }
        }

        return options
    }

    property var providerOptions: buildProviderOptions()

    property var enabledProviderOptions: providerOptions.filter(function(opt) {
        if (!appSettings) return true
        var baseProvider = opt.value.split(":")[0]
        switch (baseProvider) {
            case "ollama": return appSettings.ollamaEnabled
            case "openclaw": return appSettings.openclawEnabled
            case "openai-compatible": return appSettings.openaiCompatibleEnabled
            case "opencode": return appSettings.opencodeEnabled
            default: return true
        }
    })

    padding: 0

    AppSettings {
        id: appSettings
    }

    function getProviderDisplayName() {
        return appSettings.getProviderDisplayName()
    }

    function switchProvider(newProvider) {
        if (newProvider === appSettings.provider) return;

        clearChat();

        if (newProvider.startsWith("openai-compatible:")) {
            var providerId = newProvider.substring("openai-compatible:".length)
            appSettings.selectedOpenAICompatibleProviderId = providerId
            appSettings.provider = "openai-compatible"

            if (!appSettings.getSelectedOpenAICompatibleProvider()) {
                var providers = appSettings.getOpenaiCompatibleProviders()
                for (var i = 0; i < providers.length; i++) {
                    if (providers[i].enabled) {
                        appSettings.selectedOpenAICompatibleProviderId = providers[i].id
                        break
                    }
                }
            }
        } else if (newProvider.startsWith("openclaw:")) {
            var instanceId = newProvider.substring("openclaw:".length)
            appSettings.selectedOpenClawInstanceId = instanceId
            appSettings.provider = "openclaw"

            if (!appSettings.getSelectedOpenClawInstance()) {
                var instances = appSettings.getOpenClawInstances()
                for (var i = 0; i < instances.length; i++) {
                    if (instances[i].enabled) {
                        appSettings.selectedOpenClawInstanceId = instances[i].id
                        break
                    }
                }
            }
        } else {
            appSettings.provider = newProvider;
        }

        currentProvider = newProvider;

        if (newProvider === "ollama") {
            getModels();
        }

        applicationWindow().showPassiveNotification(i18n("Switched to %1", appSettings.getProviderDisplayName()));
    }

    function toggleThinking() {
        thinkingEnabled = !thinkingEnabled;
        var status = thinkingEnabled ? i18n("enabled") : i18n("disabled");
        applicationWindow().showPassiveNotification(i18n("Thinking %1", status));
    }

    function isProviderConfigured() {
        const provider = currentProvider;
        if (provider === "ollama") {
            return hasLocalModel;
        } else if (provider.startsWith("openclaw")) {
            var instance = appSettings.getSelectedOpenClawInstance()
            return instance && instance.url && instance.token;
        } else if (provider === "opencode") {
            return appSettings.opencodeUrl &&
                   appSettings.opencodeUsername &&
                   appSettings.opencodePassword;
        } else if (currentProvider.startsWith("openai-compatible")) {
            var openaiProvider = appSettings.getSelectedOpenAICompatibleProvider()
            return openaiProvider && openaiProvider.url && openaiProvider.token && openaiProvider.model;
        }
        return false;
    }

    function getProviderNotConfiguredMessage() {
        if (currentProvider === "ollama") {
            return i18n("No local model found.\nPlease install some first.\n\nIf you need help, check Ollama documentation.");
        } else if (currentProvider.startsWith("openclaw")) {
            return i18n("OpenClaw instance not configured.\nPlease set URL and Token in settings.");
        } else if (currentProvider === "opencode") {
            return i18n("OpenCode not configured.\nPlease set URL, Username, Password and Model in settings.");
        } else if (currentProvider.startsWith("openai-compatible")) {
            return i18n("OpenAI Compatible provider not configured.\nPlease configure it in settings.");
        }
        return i18n("Provider not configured.");
    }

    function handleStreaming(text, oldLength, listModel, thinkingText) {
        isStreaming = true;

        if (!disableAutoScroll && listView.contentHeight > listView.height) {
            listView.positionViewAtEnd();
        }

        if (listModel.count === oldLength) {
            listModel.append({
                "name": "Assistant",
                "content": text,
                "thinkingContent": thinkingText !== undefined ? thinkingText : ""
            });
            if (currentSessionId !== "") {
                SessionStore.addMessage(currentSessionId, "assistant", text, thinkingText !== undefined ? thinkingText : "")
            }
        } else {
            listModel.setProperty(oldLength, "content", text);
            if (thinkingText !== undefined) {
                listModel.setProperty(oldLength, "thinkingContent", thinkingText);
            }
        }

        if (currentSessionId !== "" && !streamingSaveTimer.running) {
            streamingSaveTimer.start();
        }
    }

    function handleRequestComplete(oldLength, listModel) {
        if (activeXhr === null) return;

        if (listModel.count > oldLength) {
            const lastValue = listModel.get(oldLength);
            promptArray.push({ "role": "assistant", "content": lastValue.content, "images": [] });
        }
        isLoading = false;

        activeXhr = null;
        isStreaming = false;

        if (currentSessionId !== "" && listModel.count > oldLength) {
            var lastMsg = listModel.get(oldLength);
            SessionStore.finalizeLastAssistantMessage(currentSessionId, lastMsg.content, lastMsg.thinkingContent || "");
            refreshSessionList();
        }
    }

    function cancelRequest() {
        if (!isLoading) return "";

        var wasStreamingBeforeAbort = isStreaming;

        // Abort active request based on provider
        if (currentProvider === "ollama" || currentProvider.startsWith("openclaw") || currentProvider.startsWith("openai-compatible")) {
            ApiClient.abortActiveRequest();
        } else if (currentProvider === "opencode") {
            OpenCodeClient.abortActiveRequest();
        }
        activeXhr = null;

        var restoreText = "";

        if (!wasStreamingBeforeAbort) {
            // No response received yet - remove the empty AI message and restore user's text
            if (listModelController.count > 0) {
                listModelController.remove(listModelController.count - 1);
            }
            promptArray.pop();
            restoreText = lastSentMessage;
        } else {
            if (currentSessionId !== "" && listModelController.count > 0) {
                var lastItem = listModelController.get(listModelController.count - 1);
                if (lastItem && lastItem.name === "Assistant") {
                    SessionStore.finalizeLastAssistantMessage(currentSessionId, lastItem.content, lastItem.thinkingContent || "");
                    refreshSessionList();
                }
            }
        }

        isLoading = false;
        isStreaming = false;
        return restoreText;
    }

    function stopRequest() {
        if (!isLoading) return;

        // Abort active request
        if (currentProvider === "ollama" || currentProvider.startsWith("openclaw") || currentProvider.startsWith("openai-compatible")) {
            ApiClient.abortActiveRequest();
        } else if (currentProvider === "opencode") {
            OpenCodeClient.abortActiveRequest();
        }
        activeXhr = null;

        // Keep partial response in history
        if (listModelController.count > 0) {
            var lastIndex = listModelController.count - 1;
            var lastItem = listModelController.get(lastIndex);
            if (lastItem && lastItem.name === "Assistant") {
                promptArray.push({ "role": "assistant", "content": lastItem.content, "images": [] });
                if (currentSessionId !== "") {
                    SessionStore.finalizeLastAssistantMessage(currentSessionId, lastItem.content, lastItem.thinkingContent || "");
                    refreshSessionList();
                }
            }
        }

        isLoading = false;
        isStreaming = false;
    }

    function sendMessage(prompt) {
        if (!prompt.trim() || isLoading) return;

        lastSentMessage = prompt;
        isStreaming = false;

        if (currentSessionId === "") {
            var providerName = currentProvider
            var modelName = currentModel || ""
            if (currentProvider.startsWith("openclaw")) {
                var instance = appSettings.getSelectedOpenClawInstance()
                if (instance) {
                    providerName = "openclaw:" + instance.id
                    modelName = instance.displayName || "openclaw"
                }
            } else if (currentProvider.startsWith("openai-compatible:")) {
                var provider = appSettings.getSelectedOpenAICompatibleProvider()
                if (provider) {
                    providerName = "openai-compatible:" + provider.id
                    modelName = provider.displayName || provider.model || "unknown"
                }
            }
            currentSessionId = SessionStore.createSession(providerName, modelName)
            var title = prompt.length > 50 ? prompt.substring(0, 50) + "…" : prompt
            SessionStore.updateSessionTitle(currentSessionId, title)
            refreshSessionList()
        }

        SessionStore.addMessage(currentSessionId, "user", prompt, "")

        var currentProviderName = currentProvider
        var currentModelName = currentModel || ""
        if (currentProvider.startsWith("openclaw")) {
            var instance = appSettings.getSelectedOpenClawInstance()
            if (instance) {
                currentProviderName = "openclaw:" + instance.id
                currentModelName = instance.displayName || "openclaw"
            }
        } else if (currentProvider.startsWith("openai-compatible:")) {
            var provider = appSettings.getSelectedOpenAICompatibleProvider()
            if (provider) {
                currentProviderName = "openai-compatible:" + provider.id
                currentModelName = provider.displayName || provider.model || "unknown"
            }
        }
        SessionStore.updateSessionProvider(currentSessionId, currentProviderName, currentModelName)

        listModel.append({
            "name": "User",
            "content": prompt,
            "thinkingContent": ""
        });

        promptArray.push({ "role": "user", "content": prompt, "images": [] });

        isLoading = true;
        listView.positionViewAtEnd();

        if (currentProvider === "ollama") {
            activeXhr = ApiClient.requestOllama(
                currentModel,
                promptArray,
                listModel,
                handleStreaming,
                handleRequestComplete,
                thinkingEnabled
            );
        } else if (currentProvider.startsWith("openclaw")) {
            var instance = appSettings.getSelectedOpenClawInstance()
            if (instance) {
                activeXhr = ApiClient.requestOpenAICompatible(
                    instance.url,
                    instance.token,
                    "openclaw",
                    promptArray,
                    thinkingEnabled,
                    { "x-openclaw-agent-id": "main" },
                    true,
                    listModel,
                    handleStreaming,
                    handleRequestComplete
                );
            }
        } else if (currentProvider.startsWith("openai-compatible:")) {
            var provider = appSettings.getSelectedOpenAICompatibleProvider()
            if (provider) {
                activeXhr = ApiClient.requestOpenAICompatible(
                    provider.url,
                    provider.token,
                    provider.model,
                    promptArray,
                    thinkingEnabled,
                    null,
                    false,
                    listModel,
                    handleStreaming,
                    handleRequestComplete
                );
            }
        } else if (currentProvider === "opencode") {
            activeXhr = OpenCodeClient.requestOpenCode(
                appSettings.opencodeUrl,
                appSettings.opencodeUsername,
                appSettings.opencodePassword,
                appSettings.opencodeModel,
                promptArray,
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
        currentSessionId = "";
        appSettings.lastActiveSessionId = "";
        OpenCodeClient.resetSession();
    }

    function refreshSessionList() {
        sessionModel.clear();
        var sessions = SessionStore.listSessions();
        for (var i = 0; i < sessions.length; i++) {
            var s = sessions[i];
            var providerDisplay = getProviderLabel(s.provider, s.model)
            var timestampDisplay = SessionStore.formatRelativeTime(s.updated_at)
            sessionModel.append({
                "sessionId": s.id,
                "title": s.title,
                "provider": providerDisplay,
                "timestamp": timestampDisplay
            });
        }
    }

    function getProviderLabel(provider, model) {
        if (provider === "ollama") {
            return "Ollama · " + (model || "unknown");
        } else if (provider.startsWith("openclaw:")) {
            return model || "OpenClaw";
        } else if (provider.startsWith("openai-compatible:")) {
            return model || "OpenAI Compatible";
        } else if (provider === "opencode") {
            return "OpenCode";
        }
        return provider;
    }

    function loadSessionById(sessionId) {
        if (isLoading) return;

        if (currentSessionId === sessionId) return;

        var sessionInfo = SessionStore.getSession(sessionId);
        if (!sessionInfo || !sessionInfo.id) return;

        listModelController.clear();
        promptArray = [];
        OpenCodeClient.resetSession();

        var messages = SessionStore.loadSession(sessionId);
        for (var i = 0; i < messages.length; i++) {
            var msg = messages[i];
            var roleName = msg.role === "user" ? "User" : "Assistant";
            listModelController.append({
                "name": roleName,
                "content": msg.content,
                "thinkingContent": msg.thinkingContent || ""
            });
            if (msg.role === "user" || msg.role === "assistant") {
                promptArray.push({ "role": msg.role, "content": msg.content, "images": [] });
            }
        }

        currentSessionId = sessionId;
        appSettings.lastActiveSessionId = sessionId;
    }

    function openSettings() {
        applicationWindow().pageStack.pushDialogLayer(Qt.resolvedUrl("../settings/SettingsPage.qml"), {
            settings: appSettings
        }, {
            title: i18n("Settings"),
            width: 600,
            height: 550,
            minimumWidth: 600,
            minimumHeight: 550,
            maximumWidth: 600,
            maximumHeight: 550
        });
    }

    Component.onCompleted: {
        if (currentProvider === "ollama") {
            getModels();
        }
        messageInput.focusInput();
        refreshSessionList();

        if (appSettings.lastActiveSessionId !== "") {
            var sessionInfo = SessionStore.getSession(appSettings.lastActiveSessionId);
            if (sessionInfo && sessionInfo.id) {
                loadSessionById(appSettings.lastActiveSessionId);
            }
        }
    }

    ListModel {
        id: sessionModel
    }

    Timer {
        id: streamingSaveTimer
        interval: 500
        repeat: false
        onTriggered: {
            if (currentSessionId !== "" && listModelController && listModelController.count > 0) {
                var lastIdx = listModelController.count - 1;
                var lastItem = listModelController.get(lastIdx);
                if (lastItem && lastItem.name === "Assistant") {
                    SessionStore.updateLastAssistantMessage(currentSessionId, lastItem.content, lastItem.thinkingContent || "");
                }
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        SessionSidebar {
            id: sessionSidebar
            Layout.preferredWidth: Kirigami.Units.gridUnit * 16
            Layout.minimumWidth: Kirigami.Units.gridUnit * 16
            Layout.maximumWidth: Kirigami.Units.gridUnit * 16
            Layout.fillHeight: true
            sessionModel: sessionModel
            currentSessionId: root.currentSessionId

            onSessionClicked: function(sessionId) {
                root.loadSessionById(sessionId)
            }
            onSessionDeleteClicked: function(sessionId) {
                if (sessionId === root.currentSessionId) {
                    root.clearChat()
                }
                SessionStore.deleteSession(sessionId)
                root.refreshSessionList()
            }
            onNewChatClicked: {
                root.clearChat()
            }
        }

        Kirigami.Separator {
            Layout.fillHeight: true
        }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 0

        RowLayout {
            id: providerComboBoxRow
            spacing: Kirigami.Units.smallSpacing
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.smallSpacing
            Layout.rightMargin: Kirigami.Units.smallSpacing
            Layout.topMargin: Kirigami.Units.smallSpacing
            Layout.bottomMargin: Kirigami.Units.smallSpacing

            Controls.ComboBox {
                id: providerComboBox

                Layout.fillWidth: true

                flat: true
                model: root.enabledProviderOptions
                textRole: "text"
                valueRole: "value"

                currentIndex: {
                    var currentValue = appSettings.provider
                    if (currentValue === "openai-compatible" && appSettings.selectedOpenAICompatibleProviderId) {
                        currentValue = "openai-compatible:" + appSettings.selectedOpenAICompatibleProviderId
                    }
                    if (currentValue === "openclaw" && appSettings.selectedOpenClawInstanceId) {
                        currentValue = "openclaw:" + appSettings.selectedOpenClawInstanceId
                    }

                    for (let i = 0; i < root.enabledProviderOptions.length; i++) {
                        if (root.enabledProviderOptions[i].value === currentValue) {
                            return i;
                        }
                    }
                    if (root.enabledProviderOptions.length > 0) {
                        root.switchProvider(root.enabledProviderOptions[0].value)
                    }
                    return 0;
                }

                onActivated: function(index) {
                    root.switchProvider(root.enabledProviderOptions[index].value);
                }

                enabled: !root.isLoading

                Controls.ToolTip.text: i18n("Select AI provider")
                Controls.ToolTip.delay: Kirigami.Units.toolTipDelay
                Controls.ToolTip.visible: hovered
            }
        }

        Kirigami.Separator {
            Layout.fillWidth: true
        }

        // OpenCode server status warning
        Kirigami.InlineMessage {
            Layout.margins: Kirigami.Units.smallSpacing
            Layout.fillWidth: true
            visible: currentProvider === "opencode" && !ProcessManager.running
            type: Kirigami.MessageType.Warning
            text: ProcessManager.lastError || i18n("OpenCode server is not running. Start it in Settings.")
        }

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
                thinkingText: thinkingContent || ""
            }

            Controls.ScrollBar.vertical: Controls.ScrollBar {}
        }

        Kirigami.Separator {
            Layout.fillWidth: true
        }

        // Ollama model selector dropdown
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.largeSpacing
            Layout.rightMargin: Kirigami.Units.largeSpacing
            Layout.topMargin: Kirigami.Units.smallSpacing

            visible: currentProvider === "ollama" && hasLocalModel

            Controls.ComboBox {
                id: modelComboBox

                Layout.fillWidth: true

                model: modelsArray
                textRole: "text"
                valueRole: "value"

                currentIndex: {
                    if (!currentModel || modelsArray.length === 0) return -1
                    for (let i = 0; i < modelsArray.length; i++) {
                        if (modelsArray[i].value === currentModel) return i
                    }
                    return 0
                }

                onCurrentValueChanged: {
                    if (currentValue && currentValue !== currentModel) {
                        currentModel = currentValue
                    }
                }

                enabled: !isLoading
            }

            Controls.Button {
                icon.name: "view-refresh"
                display: Controls.AbstractButton.IconOnly

                Controls.ToolTip.text: i18n("Refresh model list")
                Controls.ToolTip.delay: Kirigami.Units.toolTipDelay
                Controls.ToolTip.visible: hovered

                onClicked: getModels()
            }
        }

        MessageInput {
            id: messageInput

            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.largeSpacing

            isProviderConfigured: root.isProviderConfigured()
            isLoading: root.isLoading
            isStreaming: root.isStreaming

            onCancelOrStop: {
                var restoreText = root.cancelRequest();
                if (restoreText) {
                    messageInput.clearText();
                    messageInput.textField.text = restoreText;
                }
            }

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
}
