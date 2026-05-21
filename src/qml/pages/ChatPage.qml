/*
    SPDX-FileCopyrightText: 2024 Denys Madureira <denysmb@zoho.com>
    SPDX-License-Identifier: LGPL-2.1-or-later
*/

import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.chatqt
import org.koderoots.chatqt

Kirigami.Page {
    id: root

    Component {
        id: settingsPageComponent
        SettingsPage {
            settings: appSettings
        }
    }

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
    property var mcpFunctions: []
    property var sessionLoadingState: ({})
    property string streamingSessionId: ""
    property var sessionPromptArrays: ({})

    function initMcpServers() {
        McpOrchestrator.initMcpServers(appSettings, McpClient, McpProcessManager, initMcpServer)
    }

    function initMcpServer(server) {
        McpOrchestrator.initMcpServer(server, {
            McpClient: McpClient,
            McpProcessManager: McpProcessManager,
            i18n: i18n,
            showNotification: function(msg) { applicationWindow().showPassiveNotification(msg) }
        })
    }

    function gatherMcpFunctions() {
        return McpOrchestrator.gatherMcpFunctions(appSettings, McpClient)
    }

    function hasConnectedMcpServers() {
        return McpOrchestrator.hasConnectedMcpServers(appSettings, McpClient)
    }

    function buildProviderOptions() {
        const options = [
            { text: "Ollama", value: ProviderConstants.PROVIDERS.OLLAMA },
            { text: "OpenCode", value: ProviderConstants.PROVIDERS.OPENCODE },
            { text: "Pi", value: ProviderConstants.PROVIDERS.PI }
        ]

        if (appSettings && appSettings.openclawEnabled) {
            const instances = appSettings.getOpenClawInstances()
            for (let i = 0; i < instances.length; i++) {
                if (instances[i].enabled) {
                    options.push({
                        text: instances[i].displayName + " (OpenClaw)",
                        value: ProviderConstants.PROVIDERS.OPENCLAW + ":" + instances[i].id
                    })
                }
            }
        }

        if (appSettings && appSettings.openaiCompatibleEnabled) {
            const providers = appSettings.getOpenaiCompatibleProviders()
            for (let i = 0; i < providers.length; i++) {
                if (providers[i].enabled) {
                    options.push({
                        text: providers[i].displayName + " (OpenAI Compatible)",
                        value: ProviderConstants.PROVIDERS.OPENAI_COMPATIBLE + ":" + providers[i].id
                    })
                }
            }
        }

        return options
    }

    property var providerOptions: buildProviderOptions()

    property var enabledProviderOptions: providerOptions.filter(function(opt) {
        if (!appSettings) return true
        const baseProvider = opt.value.split(":")[0]
        switch (baseProvider) {
            case ProviderConstants.PROVIDERS.OLLAMA: return appSettings.ollamaEnabled
            case ProviderConstants.PROVIDERS.OPENCLAW: return appSettings.openclawEnabled
            case ProviderConstants.PROVIDERS.OPENAI_COMPATIBLE: return appSettings.openaiCompatibleEnabled
            case ProviderConstants.PROVIDERS.OPENCODE: return appSettings.opencodeEnabled
            case ProviderConstants.PROVIDERS.PI: return appSettings.piEnabled
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

        if (newProvider.startsWith(ProviderConstants.PROVIDERS.OPENAI_COMPATIBLE + ":")) {
            var providerId = newProvider.substring(ProviderConstants.PROVIDERS.OPENAI_COMPATIBLE.length + 1)
            appSettings.selectedOpenAICompatibleProviderId = providerId
            appSettings.provider = ProviderConstants.PROVIDERS.OPENAI_COMPATIBLE

            if (!appSettings.getSelectedOpenAICompatibleProvider()) {
                var providers = appSettings.getOpenaiCompatibleProviders()
                for (var i = 0; i < providers.length; i++) {
                    if (providers[i].enabled) {
                        appSettings.selectedOpenAICompatibleProviderId = providers[i].id
                        break
                    }
                }
            }
        } else if (newProvider.startsWith(ProviderConstants.PROVIDERS.OPENCLAW + ":")) {
            var instanceId = newProvider.substring(ProviderConstants.PROVIDERS.OPENCLAW.length + 1)
            appSettings.selectedOpenClawInstanceId = instanceId
            appSettings.provider = ProviderConstants.PROVIDERS.OPENCLAW

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

        if (newProvider === ProviderConstants.PROVIDERS.OLLAMA) {
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
        const provider = ProviderRegistry.getProvider(currentProvider);
        if (!provider) return false;
        return provider.isConfigured({
            appSettings: appSettings,
            hasLocalModel: hasLocalModel,
            PiProcessManager: PiProcessManager
        });
    }

    function getProviderNotConfiguredMessage() {
        const provider = ProviderRegistry.getProvider(currentProvider);
        if (!provider) return i18n("Provider not configured.");
        return provider.notConfiguredMessage({
            appSettings: appSettings,
            i18n: i18n,
            PiProcessManager: PiProcessManager
        });
    }

    function handleStreaming(text, oldLength, listModel, thinkingText, capturedSessionId) {
        const sessionId = capturedSessionId || currentSessionId
        StreamingHandler.handleStreaming(text, oldLength, listModel, thinkingText, sessionId, {
            currentSessionId: currentSessionId,
            disableAutoScroll: disableAutoScroll,
            listView: listView,
            SessionStore: SessionStore,
            setIsStreaming: function(v) { isStreaming = v }
        })
    }

    function handleRequestComplete(oldLength, listModel, finalText, toolCalls, capturedSessionId) {
        StreamingHandler.handleRequestComplete(oldLength, listModel, finalText, toolCalls, capturedSessionId, {
            activeXhr: activeXhr,
            currentSessionId: currentSessionId,
            currentProvider: currentProvider,
            setIsLoading: function(v) { isLoading = v },
            setIsStreaming: function(v) { isStreaming = v },
            setActiveXhr: function(v) { activeXhr = v },
            setStreamingSessionId: function(v) { streamingSessionId = v },
            sessionPromptArrays: sessionPromptArrays,
            promptArray: promptArray,
            SessionStore: SessionStore,
            refreshSessionList: refreshSessionList,
            updateSessionLoadingState: updateSessionLoadingState,
            getToolCallDepth: McpOrchestrator.getToolCallDepth,
            resetToolCallDepth: McpOrchestrator.resetToolCallDepth,
            maxToolCallDepth: McpOrchestrator.MAX_TOOL_CALL_DEPTH,
            handleMcpToolCallsWrapper: handleMcpToolCalls
        })
    }


    function handleMcpToolCalls(oldLength, listModel, finalText, toolCalls, capturedSessionId) {
        McpOrchestrator.handleMcpToolCalls(oldLength, listModel, finalText, toolCalls, capturedSessionId, {
            currentSessionId: currentSessionId,
            i18n: i18n,
            SessionStore: SessionStore,
            promptArray: promptArray,
            sessionPromptArrays: sessionPromptArrays,
            sendMcpFollowUpRequest: sendMcpFollowUpRequest
        })
    }

    function executeNextMcpToolCall(toolCalls, currentIndex, oldLength, listModel, capturedSessionId) {
        McpOrchestrator.executeNextMcpToolCall(toolCalls, currentIndex, oldLength, listModel, capturedSessionId, {
            currentSessionId: currentSessionId,
            McpClient: McpClient,
            appSettings: appSettings,
            i18n: i18n,
            promptArray: promptArray,
            SessionStore: SessionStore,
            sendMcpFollowUpRequest: sendMcpFollowUpRequest
        })
    }

    function callStdioMcpTool(serverId, toolName, arguments, toolCallId, funcName, listModel, toolCalls, currentIndex, oldLength, capturedSessionId) {
        McpOrchestrator.callStdioMcpTool(serverId, toolName, arguments, toolCallId, funcName, listModel, toolCalls, currentIndex, oldLength, capturedSessionId, {
            McpClient: McpClient,
            McpProcessManager: McpProcessManager
        })
    }


    Connections {
        target: McpProcessManager

        function onMessageReceived(serverId, jsonMessage) {
            McpOrchestrator.handleStdioMessage(serverId, jsonMessage, {
                McpClient: McpClient,
                McpProcessManager: McpProcessManager,
                currentSessionId: currentSessionId,
                i18n: i18n,
                promptArray: promptArray,
                SessionStore: SessionStore,
                showNotification: function(msg) { applicationWindow().showPassiveNotification(msg) },
                executeNextMcpToolCall: function(toolCalls, currentIndex, oldLength, listModel, sessionId, deps) {
                    McpOrchestrator.executeNextMcpToolCall(toolCalls, currentIndex, oldLength, listModel, sessionId, deps || {
                        currentSessionId: currentSessionId,
                        McpClient: McpClient,
                        appSettings: appSettings,
                        i18n: i18n,
                        promptArray: promptArray,
                        SessionStore: SessionStore,
                        sendMcpFollowUpRequest: sendMcpFollowUpRequest
                    })
                }
            })
        }

        function onProcessStatusChanged(serverId, status) {
            McpOrchestrator.handleProcessStatusChanged(serverId, status, {
                McpClient: McpClient,
                i18n: i18n,
                showNotification: function(msg) { applicationWindow().showPassiveNotification(msg) }
            })
        }

        function onProcessError(serverId, errorMessage) {
            McpOrchestrator.handleProcessError(serverId, errorMessage, {
                McpClient: McpClient,
                i18n: i18n,
                showNotification: function(msg) { applicationWindow().showPassiveNotification(msg) }
            })
        }
    }

    function sendMcpFollowUpRequest(oldLength, listModel, capturedSessionId) {
        const sessionId = capturedSessionId || currentSessionId
        const isActiveSession = sessionId === currentSessionId

        const streamingCb = isActiveSession ? handleStreaming : function() {}
        const completeCb = function(ol, lm, finalText, toolCalls) {
            handleRequestComplete(ol, lm, finalText, toolCalls, sessionId)
        }

        const mcpFuncs = gatherMcpFunctions()
        const provider = ProviderRegistry.getProvider(currentProvider);
        if (provider) {
            activeXhr = provider.sendMcpFollowUp({
                appSettings: appSettings,
                model: currentModel,
                promptArray: promptArray,
                listModel: listModel,
                onStreaming: streamingCb,
                onComplete: completeCb,
                thinkingEnabled: thinkingEnabled,
                mcpFunctions: mcpFuncs,
                ApiClient: ApiClient,
                OpenCodeClient: OpenCodeClient,
                PiClient: PiClient,
                PiProcessManager: PiProcessManager
            });
        }
    }

    function cancelRequest() {
        if (!isLoading) return "";

        const wasStreamingBeforeAbort = isStreaming;

        const provider = ProviderRegistry.getProvider(currentProvider);
        if (provider) {
            provider.abortRequest({ ApiClient: ApiClient, OpenCodeClient: OpenCodeClient, PiClient: PiClient });
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

        const provider = ProviderRegistry.getProvider(currentProvider);
        if (provider) {
            provider.abortRequest({ ApiClient: ApiClient, OpenCodeClient: OpenCodeClient, PiClient: PiClient });
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

    function buildSystemMessage() {
        var skills = SkillScanner.discoverSkills(appSettings.getSkillFolders())
        var agentContent = ""
        if (appSettings.agentFilePath && appSettings.agentFilePath !== "") {
            agentContent = SkillScanner.readFile(appSettings.agentFilePath)
        }
        return SkillScanner.buildSystemMessage(skills, agentContent || "")
    }

    function ensureSystemMessage() {
        if (promptArray.length > 0 && promptArray[0].role === "system") return

        var sysMsg = buildSystemMessage()
        if (sysMsg && sysMsg !== "") {
            promptArray.unshift({ "role": "system", "content": sysMsg })
        }
    }

    function sendMessage(prompt) {
        if (!prompt.trim() || isLoading) return;

        lastSentMessage = prompt;
        isStreaming = false;

        ensureSystemMessage()

        if (currentSessionId === "") {
            var providerName = currentProvider
            var modelName = currentModel || ""
            if (currentProvider.startsWith(ProviderConstants.PROVIDERS.OPENCLAW)) {
                var instance = appSettings.getSelectedOpenClawInstance()
                if (instance) {
                    providerName = ProviderConstants.PROVIDERS.OPENCLAW + ":" + instance.id
                    modelName = instance.displayName || "openclaw"
                }
            } else if (currentProvider.startsWith(ProviderConstants.PROVIDERS.OPENAI_COMPATIBLE + ":")) {
                var openaiProvider = appSettings.getSelectedOpenAICompatibleProvider()
                if (openaiProvider) {
                    providerName = ProviderConstants.PROVIDERS.OPENAI_COMPATIBLE + ":" + openaiProvider.id
                    modelName = openaiProvider.displayName || openaiProvider.model || "unknown"
                }
            }
            currentSessionId = SessionStore.createSession(providerName, modelName)
            var title = prompt.length > 50 ? prompt.substring(0, 50) + "…" : prompt
            SessionStore.updateSessionTitle(currentSessionId, title)
            refreshSessionList()
        }

        var capturedSessionId = currentSessionId

        SessionStore.addMessage(currentSessionId, "user", prompt, "")

        var currentProviderName = currentProvider
        var currentModelName = currentModel || ""
        if (currentProvider.startsWith(ProviderConstants.PROVIDERS.OPENCLAW)) {
            var instance = appSettings.getSelectedOpenClawInstance()
            if (instance) {
                currentProviderName = ProviderConstants.PROVIDERS.OPENCLAW + ":" + instance.id
                currentModelName = instance.displayName || "openclaw"
            }
        } else if (currentProvider.startsWith(ProviderConstants.PROVIDERS.OPENAI_COMPATIBLE + ":")) {
            var openaiProv = appSettings.getSelectedOpenAICompatibleProvider()
            if (openaiProv) {
                currentProviderName = ProviderConstants.PROVIDERS.OPENAI_COMPATIBLE + ":" + openaiProv.id
                currentModelName = openaiProv.displayName || openaiProv.model || "unknown"
            }
        }
        SessionStore.updateSessionProvider(currentSessionId, currentProviderName, currentModelName)

        listModel.append({
            "name": "User",
            "content": prompt,
            "thinkingContent": ""
        });

        promptArray.push({ "role": "user", "content": prompt, "images": [] });

        sessionPromptArrays[capturedSessionId] = promptArray.slice()

        isLoading = true;
        listView.positionViewAtEnd();
        McpOrchestrator.resetToolCallDepth()

        sessionLoadingState[capturedSessionId] = true
        streamingSessionId = capturedSessionId
        updateSessionLoadingState(capturedSessionId, true)

        mcpFunctions = gatherMcpFunctions()

        const streamingCb = function(text, ol, lm, thinking) {
            handleStreaming(text, ol, lm, thinking, capturedSessionId)
            if (capturedSessionId !== "" && !streamingSaveTimer.running) {
                streamingSaveTimer.start()
            }
        }
        const completeCb = function(ol, lm, finalText, toolCalls) {
            handleRequestComplete(ol, lm, finalText, toolCalls, capturedSessionId)
        }

        const provider = ProviderRegistry.getProvider(currentProvider);
        if (provider) {
            activeXhr = provider.sendRequest({
                appSettings: appSettings,
                model: currentModel,
                promptArray: promptArray,
                listModel: listModel,
                onStreaming: streamingCb,
                onComplete: completeCb,
                thinkingEnabled: thinkingEnabled,
                mcpFunctions: mcpFunctions,
                ApiClient: ApiClient,
                OpenCodeClient: OpenCodeClient,
                PiClient: PiClient,
                PiProcessManager: PiProcessManager
            });
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

    function updateSessionLoadingState(sessionId, loading) {
        for (var i = 0; i < sessionModel.count; i++) {
            if (sessionModel.get(i).sessionId === sessionId) {
                sessionModel.setProperty(i, "isLoading", loading)
                break
            }
        }
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
                "timestamp": timestampDisplay,
                "isLoading": sessionLoadingState[s.id] === true
            });
        }
    }

    function getProviderLabel(provider, model) {
        if (provider === ProviderConstants.PROVIDERS.OLLAMA) {
            return "Ollama · " + (model || "unknown");
        } else if (provider.startsWith(ProviderConstants.PROVIDERS.OPENCLAW + ":")) {
            return model || "OpenClaw";
        } else if (provider.startsWith(ProviderConstants.PROVIDERS.OPENAI_COMPATIBLE + ":")) {
            return model || "OpenAI Compatible";
        } else if (provider === ProviderConstants.PROVIDERS.OPENCODE) {
            return "OpenCode";
        } else if (provider === ProviderConstants.PROVIDERS.PI) {
            return "Pi";
        }
        return provider;
    }

    function loadSessionById(sessionId) {
        if (currentSessionId === sessionId) return;

        if (currentSessionId !== "" && currentSessionId !== sessionId) {
            sessionPromptArrays[currentSessionId] = promptArray.slice()
        }

        var sessionInfo = SessionStore.getSession(sessionId);
        if (!sessionInfo || !sessionInfo.id) return;

        var sessionProvider = sessionInfo.provider || ""
        var sessionModelName = sessionInfo.model || ""

        if (sessionProvider !== "") {
            switchProvider(sessionProvider)
        }

        if (currentProvider === ProviderConstants.PROVIDERS.OLLAMA && sessionModelName !== "" && sessionModelName !== currentModel) {
            currentModel = sessionModelName
        }

        listModelController.clear();
        OpenCodeClient.resetSession();

        var messages = SessionStore.loadSession(sessionId);
        for (var i = 0; i < messages.length; i++) {
            var msg = messages[i];
            var isErr = msg.role === "error" || (
                msg.role === "assistant" && msg.content && (
                    msg.content.indexOf("does not support") !== -1 ||
                    msg.content.indexOf("Ollama error") !== -1 ||
                    msg.content.startsWith('{\"error\"}')
                )
            );
            var roleName;
            if (msg.role === "user") roleName = "User";
            else if (msg.role === "tool") roleName = "Tool";
            else if (isErr) roleName = "Error";
            else roleName = "Assistant";

            listModelController.append({
                "name": roleName,
                "content": msg.content,
                "thinkingContent": msg.thinkingContent || ""
            });
        }

        promptArray = []
        for (var j = 0; j < messages.length; j++) {
            var m = messages[j]
            if (m.role === "user" || m.role === "assistant") {
                promptArray.push({ "role": m.role, "content": m.content, "images": [] })
            } else if (m.role === "tool") {
                promptArray.push({ "role": "tool", "content": m.content })
            }
        }

        currentSessionId = sessionId;
        appSettings.lastActiveSessionId = sessionId;

        var isSessionLoading = sessionLoadingState[sessionId] === true
        isLoading = isSessionLoading
        isStreaming = isSessionLoading
    }

    function openSettings() {
        applicationWindow().pageStack.pushDialogLayer(settingsPageComponent, {}, {
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
        if (currentProvider === ProviderConstants.PROVIDERS.OPENCLAW) {
            if (appSettings.selectedOpenClawInstanceId) {
                currentProvider = ProviderConstants.PROVIDERS.OPENCLAW + ":" + appSettings.selectedOpenClawInstanceId
            } else {
                var instances = appSettings.getOpenClawInstances()
                for (var i = 0; i < instances.length; i++) {
                    if (instances[i].enabled) {
                        currentProvider = ProviderConstants.PROVIDERS.OPENCLAW + ":" + instances[i].id
                        appSettings.selectedOpenClawInstanceId = instances[i].id
                        break
                    }
                }
            }
        }
        if (currentProvider === ProviderConstants.PROVIDERS.OPENAI_COMPATIBLE) {
            if (appSettings.selectedOpenAICompatibleProviderId) {
                currentProvider = ProviderConstants.PROVIDERS.OPENAI_COMPATIBLE + ":" + appSettings.selectedOpenAICompatibleProviderId
            } else {
                var providers = appSettings.getOpenaiCompatibleProviders()
                for (var i = 0; i < providers.length; i++) {
                    if (providers[i].enabled) {
                        currentProvider = ProviderConstants.PROVIDERS.OPENAI_COMPATIBLE + ":" + providers[i].id
                        appSettings.selectedOpenAICompatibleProviderId = providers[i].id
                        break
                    }
                }
            }
        }

        if (currentProvider === ProviderConstants.PROVIDERS.OLLAMA) {
            getModels();
        }

        initMcpServers()

        if (currentProvider === ProviderConstants.PROVIDERS.PI && PiProcessManager.autoStart) {
            PiProcessManager.start();
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
            var saveId = streamingSessionId || currentSessionId
            if (saveId !== "") {
                if (saveId === currentSessionId && listModelController && listModelController.count > 0) {
                    var lastIdx = listModelController.count - 1;
                    var lastItem = listModelController.get(lastIdx);
                    if (lastItem && lastItem.name === "Assistant") {
                        SessionStore.updateLastAssistantMessage(saveId, lastItem.content, lastItem.thinkingContent || "");
                    }
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
                    if (currentValue === ProviderConstants.PROVIDERS.OPENAI_COMPATIBLE && appSettings.selectedOpenAICompatibleProviderId) {
                        currentValue = ProviderConstants.PROVIDERS.OPENAI_COMPATIBLE + ":" + appSettings.selectedOpenAICompatibleProviderId
                    }
                    if (currentValue === ProviderConstants.PROVIDERS.OPENCLAW && appSettings.selectedOpenClawInstanceId) {
                        currentValue = ProviderConstants.PROVIDERS.OPENCLAW + ":" + appSettings.selectedOpenClawInstanceId
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
            visible: currentProvider === ProviderConstants.PROVIDERS.OPENCODE && !ProcessManager.running
            type: Kirigami.MessageType.Warning
            text: ProcessManager.lastError || i18n("OpenCode server is not running. Start it in Settings.")
        }

        Kirigami.InlineMessage {
            Layout.margins: Kirigami.Units.smallSpacing
            Layout.fillWidth: true
            visible: currentProvider === ProviderConstants.PROVIDERS.PI && !PiProcessManager.running
            type: Kirigami.MessageType.Warning
            text: PiProcessManager.lastError || i18n("Pi is not running. Start it in Settings.")
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
                width: listView.width - Kirigami.Units.largeSpacing - (chatScrollBar.visible ? chatScrollBar.width : 0)
                messageText: ApiClient.preprocessMarkdown(content)
                senderName: name
                thinkingText: thinkingContent || ""
                isToolMessage: name === "Tool"
                isErrorMessage: name === "Error"
            }

            Controls.ScrollBar.vertical: Controls.ScrollBar {
                id: chatScrollBar
            }
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

            visible: currentProvider === ProviderConstants.PROVIDERS.OLLAMA && hasLocalModel

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
            visible: currentProvider === ProviderConstants.PROVIDERS.OLLAMA && !hasLocalModel

            onClicked: getModels()
        }
    }
    }
}
