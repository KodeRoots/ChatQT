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
    property int mcpToolCallDepth: 0
    readonly property int mcpMaxToolCallDepth: 10
    property var sessionLoadingState: ({})
    property string streamingSessionId: ""
    property var sessionPromptArrays: ({})

    function initMcpServers() {
        var servers = appSettings.getMcpServers()
        for (var i = 0; i < servers.length; i++) {
            if (servers[i].enabled) {
                initMcpServer(servers[i])
            }
        }
    }

    function initMcpServer(server) {
        var state = McpClient.getServerState(server.id)
        if (state && (state.status === "connected" || state.status === "connecting")) return

        var displayName = server.displayName || server.id
        applicationWindow().showPassiveNotification(i18n("Connecting to %1…").arg(displayName))

        if (!server.url) {
            applicationWindow().showPassiveNotification(i18n("Failed to connect to %1: no URL configured").arg(displayName))
            return
        }
        var headers = {}
        if (server.token) { headers["Authorization"] = "Bearer " + server.token }
        if (server.headers) {
            try {
                var customHeaders = JSON.parse(server.headers)
                var keys = Object.keys(customHeaders)
                    for (var k = 0; k < keys.length; k++) { headers[keys[k]] = customHeaders[keys[k]] }
                } catch (e) {}
            }
            McpClient.initializeServer(
                server.url, headers,
                function(result) {
                    McpClient.updateServerState(server.id, {
                        status: "connected", sessionId: result.sessionId,
                        serverInfo: result.serverInfo, capabilities: result.capabilities,
                        headers: headers, url: server.url.replace(/\/$/, ''), type: "remote"
                    })
                    McpClient.listTools(
                        server.url, result.sessionId, headers,
                        function(tools) {
                            McpClient.updateServerState(server.id, { tools: tools, toolCount: tools.length })
                            applicationWindow().showPassiveNotification(
                                i18n("Connected to %1 — %2 tool(s) available").arg(displayName).arg(tools.length)
                            )
                        },
                        function() {
                            McpClient.updateServerState(server.id, { tools: [], toolCount: 0 })
                            applicationWindow().showPassiveNotification(
                                i18n("Connected to %1 but failed to list tools").arg(displayName)
                            )
                        }
                    )
                },
                function(code, message) {
                    McpClient.updateServerState(server.id, { status: "error" })
                    applicationWindow().showPassiveNotification(
                        i18n("Failed to connect to %1: %2").arg(displayName).arg(message)
                    )
                }
            )
    }

    function gatherMcpFunctions() {
        var functions = []

        functions.push({
            name: "save_memory",
            description: "Save important information to remember across conversations. Call this when the user shares preferences, personal details, or context worth preserving. The content replaces all previous memory.",
            parameters: {
                type: "object",
                properties: {
                    content: {
                        type: "string",
                        description: "The full updated memory content to save"
                    }
                },
                required: ["content"]
            }
        })

        var servers = appSettings.getEnabledMcpServers()
        for (var i = 0; i < servers.length; i++) {
            var state = McpClient.getServerState(servers[i].id)
            if (state && state.tools && state.tools.length > 0) {
                var converted = McpClient.mcpToolsToOpenAiFunctions(state.tools)
                for (var j = 0; j < converted.length; j++) {
                    functions.push(converted[j])
                }
            }
        }
        return functions
    }

    function hasConnectedMcpServers() {
        var servers = appSettings.getEnabledMcpServers()
        for (var i = 0; i < servers.length; i++) {
            var state = McpClient.getServerState(servers[i].id)
            if (state && state.status === "connected") {
                return true
            }
        }
        return false
    }

    function buildProviderOptions() {
        var options = [
            { text: "Ollama", value: "ollama" },
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
        } else if (currentProvider.startsWith("openai-compatible")) {
            return i18n("OpenAI Compatible provider not configured.\nPlease configure it in settings.");
        }
        return i18n("Provider not configured.");
    }

    function handleStreaming(text, oldLength, listModel, thinkingText, capturedSessionId) {
        var sessionId = capturedSessionId || currentSessionId
        var isActiveSession = sessionId === currentSessionId

        isStreaming = isActiveSession;

        if (isActiveSession && !disableAutoScroll && listView.contentHeight > listView.height) {
            listView.positionViewAtEnd();
        }

        if (isActiveSession) {
            if (listModel.count === oldLength) {
                listModel.append({
                    "name": "Assistant",
                    "content": text,
                    "thinkingContent": thinkingText !== undefined ? thinkingText : "",
                    "isError": false
                });
                SessionStore.addMessage(sessionId, "assistant", text, thinkingText !== undefined ? thinkingText : "")
            } else {
                listModel.setProperty(oldLength, "content", text);
                if (thinkingText !== undefined) {
                    listModel.setProperty(oldLength, "thinkingContent", thinkingText);
                }
            }
        } else {
            if (SessionStore.getLastMessage(sessionId).role !== "assistant") {
                SessionStore.addMessage(sessionId, "assistant", text, thinkingText !== undefined ? thinkingText : "")
            } else {
                SessionStore.updateLastAssistantMessage(sessionId, text, thinkingText !== undefined ? thinkingText : "")
            }
        }
    }

    function handleRequestComplete(oldLength, listModel, finalText, toolCalls, capturedSessionId) {
        if (activeXhr === null && mcpToolCallDepth === 0 && !capturedSessionId) return;

        var sessionId = capturedSessionId || currentSessionId
        var isActiveSession = sessionId === currentSessionId

        var isOllamaError = currentProvider === "ollama" && finalText && (
            finalText.indexOf("does not support") !== -1 ||
            finalText.indexOf("Ollama error") !== -1 ||
            finalText.startsWith("{\"error\"")
        )

        if (isOllamaError) {
            if (isActiveSession && listModel.count > oldLength) {
                listModel.setProperty(oldLength, "isError", true);
                listModel.setProperty(oldLength, "name", "Error");
                listModel.setProperty(oldLength, "thinkingContent", "");
            }
            if (sessionId !== "") {
                SessionStore.markLastAssistantAsError(sessionId);
            }
            if (isActiveSession) {
                isLoading = false;
                isStreaming = false;
            }
            activeXhr = null;
            mcpToolCallDepth = 0;
            streamingSessionId = ""
            sessionLoadingState[sessionId] = false
            updateSessionLoadingState(sessionId, false)
            return;
        }

        if (toolCalls && toolCalls.length > 0 && mcpToolCallDepth < mcpMaxToolCallDepth) {
            handleMcpToolCalls(oldLength, listModel, finalText, toolCalls, sessionId)
            return
        }

        if (toolCalls && toolCalls.length > 0 && mcpToolCallDepth >= mcpMaxToolCallDepth) {
            console.warn("MCP tool call depth limit reached (" + mcpMaxToolCallDepth + ")")
        }

        var sessionPA = sessionPromptArrays[sessionId] || promptArray
        if (isActiveSession && listModel.count > oldLength) {
            var lastValue = listModel.get(oldLength);
            sessionPA.push({ "role": "assistant", "content": lastValue.content, "images": [] });
        } else if (!isActiveSession) {
            sessionPA.push({ "role": "assistant", "content": finalText || "", "images": [] });
        }
        sessionPromptArrays[sessionId] = sessionPA

        if (sessionId !== "") {
            var finalContent = finalText || ""
            if (isActiveSession && listModel.count > oldLength) {
                var lastMsg = listModel.get(oldLength);
                finalContent = lastMsg.content
                SessionStore.finalizeLastAssistantMessage(sessionId, finalContent, lastMsg.thinkingContent || "");
            } else {
                SessionStore.finalizeLastAssistantMessage(sessionId, finalContent, "")
            }
            refreshSessionList()
        }

        if (isActiveSession) {
            isLoading = false;
            isStreaming = false;
        }
        activeXhr = null;
        mcpToolCallDepth = 0;
        streamingSessionId = ""
        sessionLoadingState[sessionId] = false
        updateSessionLoadingState(sessionId, false)
    }

    function handleMcpToolCalls(oldLength, listModel, finalText, toolCalls, capturedSessionId) {
        var sessionId = capturedSessionId || currentSessionId
        var isActiveSession = sessionId === currentSessionId
        mcpToolCallDepth++

        if (isActiveSession) {
            if (listModel.count === oldLength) {
                var displayText = finalText || ""
                if (displayText === "" && toolCalls.length > 0) {
                    var toolNames = []
                    for (var t = 0; t < toolCalls.length; t++) {
                        toolNames.push(toolCalls[t].function.name)
                    }
                    displayText = i18n("Calling tools: %1", toolNames.join(", "))
                }

                listModel.append({
                    "name": "Assistant",
                    "content": displayText,
                    "thinkingContent": ""
                })
            } else {
                if (finalText) {
                    listModel.setProperty(oldLength, "content", finalText)
                }
            }
        }

        var assistantMsg = { "role": "assistant", "content": finalText || "" }
        if (toolCalls.length > 0) {
            assistantMsg["tool_calls"] = toolCalls
        }

        promptArray.push(assistantMsg)

        var sessionPA = sessionPromptArrays[sessionId] || promptArray
        sessionPA.push(assistantMsg)
        sessionPromptArrays[sessionId] = sessionPA

        if (sessionId !== "") {
            SessionStore.addMessage(sessionId, "assistant", finalText || "", "")
        }

        var pendingToolCalls = []
        for (var i = 0; i < toolCalls.length; i++) {
            pendingToolCalls.push(toolCalls[i])
        }

        executeNextMcpToolCall(pendingToolCalls, 0, oldLength, listModel, sessionId)
    }

    function executeNextMcpToolCall(toolCalls, currentIndex, oldLength, listModel, capturedSessionId) {
        var sessionId = capturedSessionId || currentSessionId
        var isActiveSession = sessionId === currentSessionId

        if (currentIndex >= toolCalls.length) {
            sendMcpFollowUpRequest(oldLength, listModel, sessionId)
            return
        }

        var toolCall = toolCalls[currentIndex]
        var funcName = toolCall.function.name
        var funcArgs = {}
        try {
            var rawArgs = toolCall.function.arguments
            if (typeof rawArgs === 'object' && rawArgs !== null) {
                funcArgs = rawArgs
            } else {
                funcArgs = JSON.parse(rawArgs || "{}")
            }
        } catch (e) {
            funcArgs = {}
        }

        var mcpToolName = McpClient.parseToolCallName(funcName)
        var isMcp = McpClient.isMcpToolCall(funcName)

        listModel.append({
            "name": "Tool",
            "content": i18n("Calling %1…").arg(funcName),
            "thinkingContent": ""
        })

        if (!isMcp) {
            if (funcName === "save_memory") {
                var memContent = funcArgs.content || ""
                appSettings.memoryContent = memContent

                if (isActiveSession) {
                    listModel.setProperty(listModel.count - 1, "content",
                        i18n("Memory saved"))
                }

                if (sessionId !== "") {
                    SessionStore.addMessage(sessionId, "tool",
                        i18n("save_memory: Memory saved"), "")
                }

                promptArray.push({
                    "role": "tool",
                    "tool_call_id": toolCall.id,
                    "content": "Memory saved successfully"
                })
                executeNextMcpToolCall(toolCalls, currentIndex + 1, oldLength, listModel, sessionId)
                return
            }

            var errorMsg = i18n("Tool %1 is not an MCP tool").arg(funcName)
            if (isActiveSession) listModel.setProperty(listModel.count - 1, "content", errorMsg)
            promptArray.push({
                "role": "tool",
                "tool_call_id": toolCall.id,
                "content": errorMsg
            })
            executeNextMcpToolCall(toolCalls, currentIndex + 1, oldLength, listModel, sessionId)
            return
        }

        var servers = appSettings.getEnabledMcpServers()
        var foundServer = null
        var foundTools = null

        for (var s = 0; s < servers.length; s++) {
            var state = McpClient.getServerState(servers[s].id)
            if (state && state.tools) {
                for (var t = 0; t < state.tools.length; t++) {
                    if (state.tools[t].name === mcpToolName) {
                        foundServer = servers[s]
                        foundTools = state
                        break
                    }
                }
                if (foundServer) break
            }
        }

        if (!foundServer) {
            var errorMsg2 = i18n("MCP server not found for tool %1").arg(funcName)
            if (isActiveSession) listModel.setProperty(listModel.count - 1, "content", errorMsg2)
            promptArray.push({
                "role": "tool",
                "tool_call_id": toolCall.id,
                "content": errorMsg2
            })
            executeNextMcpToolCall(toolCalls, currentIndex + 1, oldLength, listModel, sessionId)
            return
        }

        McpClient.callTool(
            foundServer.url,
            foundTools.sessionId,
            foundTools.headers,
            mcpToolName,
            funcArgs,
            function(result) {
                var resultContent = result.content || ""
                if (result.isError) {
                    resultContent = i18n("Error: %1").arg(resultContent)
                }

                if (isActiveSession) {
                    listModel.setProperty(listModel.count - 1, "content",
                        i18n("%1: %2").arg(funcName).arg(resultContent.substring(0, 500)))
                }

                if (sessionId !== "") {
                    SessionStore.addMessage(sessionId, "tool",
                        i18n("%1 result: %2").arg(funcName).arg(resultContent.substring(0, 500)), "")
                }

                promptArray.push({
                    "role": "tool",
                    "tool_call_id": toolCall.id,
                    "content": resultContent
                })

                executeNextMcpToolCall(toolCalls, currentIndex + 1, oldLength, listModel, sessionId)
            },
            function(code, message) {
                var errorMsg3 = i18n("Tool %1 failed: %2").arg(funcName).arg(message)
                if (isActiveSession) listModel.setProperty(listModel.count - 1, "content", errorMsg3)

                promptArray.push({
                    "role": "tool",
                    "tool_call_id": toolCall.id,
                    "content": errorMsg3
                })

                executeNextMcpToolCall(toolCalls, currentIndex + 1, oldLength, listModel, sessionId)
            }
        )
    }

    property var _mcpStartupNotifications: ({})

    function sendMcpFollowUpRequest(oldLength, listModel, capturedSessionId) {
        var sessionId = capturedSessionId || currentSessionId
        var isActiveSession = sessionId === currentSessionId

        var streamingCb = isActiveSession ? handleStreaming : function() {}
        var completeCb = function(ol, lm, finalText, toolCalls) {
            handleRequestComplete(ol, lm, finalText, toolCalls, sessionId)
        }

        if (currentProvider.startsWith("openai-compatible:")) {
            var provider = appSettings.getSelectedOpenAICompatibleProvider()
            if (provider) {
                var mcpFuncs = gatherMcpFunctions()
                activeXhr = ApiClient.requestOpenAICompatible(
                    provider.url,
                    provider.token,
                    provider.model,
                    promptArray,
                    thinkingEnabled,
                    null,
                    false,
                    listModel,
                    streamingCb,
                    completeCb,
                    mcpFuncs.length > 0 ? mcpFuncs : undefined
                )
            }
        } else if (currentProvider === "ollama") {
            var ollamaMcpFuncs = gatherMcpFunctions()
            activeXhr = ApiClient.requestOllama(
                currentModel,
                promptArray,
                listModel,
                streamingCb,
                completeCb,
                thinkingEnabled,
                ollamaMcpFuncs.length > 0 ? ollamaMcpFuncs : undefined
            )
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
                    streamingCb,
                    completeCb
                )
            }
        }
    }

    function cancelRequest() {
        if (!isLoading) return "";

        var wasStreamingBeforeAbort = isStreaming;

        // Abort active request based on provider
        if (currentProvider === "ollama" || currentProvider.startsWith("openclaw") || currentProvider.startsWith("openai-compatible")) {
            ApiClient.abortActiveRequest();
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
        var parts = []
        var soul = (appSettings.getEffectiveSoulContent() || "").trim()
        var memory = (appSettings.memoryContent || "").trim()

        var today = Qt.formatDateTime(new Date(), "yyyy-MM-dd (dddd)")
        parts.push("Current date: " + today)

        if (soul !== "") parts.push(soul)
        if (memory !== "") parts.push("\n# Memory\n" + memory)

        return parts.join("\n\n")
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

        var capturedSessionId = currentSessionId

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

        sessionPromptArrays[capturedSessionId] = promptArray.slice()

        isLoading = true;
        listView.positionViewAtEnd();
        mcpToolCallDepth = 0;

        sessionLoadingState[capturedSessionId] = true
        streamingSessionId = capturedSessionId
        updateSessionLoadingState(capturedSessionId, true)

        mcpFunctions = gatherMcpFunctions()

        var streamingCb = function(text, ol, lm, thinking) {
            handleStreaming(text, ol, lm, thinking, capturedSessionId)
            if (capturedSessionId !== "" && !streamingSaveTimer.running) {
                streamingSaveTimer.start()
            }
        }
        var completeCb = function(ol, lm, finalText, toolCalls) {
            handleRequestComplete(ol, lm, finalText, toolCalls, capturedSessionId)
        }

        if (currentProvider === "ollama") {
            activeXhr = ApiClient.requestOllama(
                currentModel,
                promptArray,
                listModel,
                streamingCb,
                completeCb,
                thinkingEnabled,
                mcpFunctions.length > 0 ? mcpFunctions : undefined
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
                    streamingCb,
                    completeCb
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
                    streamingCb,
                    completeCb,
                    mcpFunctions.length > 0 ? mcpFunctions : undefined
                );
            }
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
        if (provider === "ollama") {
            return "Ollama · " + (model || "unknown");
        } else if (provider.startsWith("openclaw:")) {
            return model || "OpenClaw";
        } else if (provider.startsWith("openai-compatible:")) {
            return model || "OpenAI Compatible";
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

        if (currentProvider === "ollama" && sessionModelName !== "" && sessionModelName !== currentModel) {
            currentModel = sessionModelName
        }

        listModelController.clear();
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

            var displayContent = msg.content
            if (msg.role === "assistant" && (!displayContent || displayContent.trim() === "")) {
                continue
            }

            listModelController.append({
                "name": roleName,
                "content": displayContent,
                "thinkingContent": msg.thinkingContent || ""
            });
        }

        promptArray = []
        for (var j = 0; j < messages.length; j++) {
            var m = messages[j]
            if (m.role === "user" || m.role === "assistant") {
                promptArray.push({ "role": m.role, "content": m.content, "images": [] })
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
        if (currentProvider === "openclaw") {
            if (appSettings.selectedOpenClawInstanceId) {
                currentProvider = "openclaw:" + appSettings.selectedOpenClawInstanceId
            } else {
                var instances = appSettings.getOpenClawInstances()
                for (var i = 0; i < instances.length; i++) {
                    if (instances[i].enabled) {
                        currentProvider = "openclaw:" + instances[i].id
                        appSettings.selectedOpenClawInstanceId = instances[i].id
                        break
                    }
                }
            }
        }
        if (currentProvider === "openai-compatible") {
            if (appSettings.selectedOpenAICompatibleProviderId) {
                currentProvider = "openai-compatible:" + appSettings.selectedOpenAICompatibleProviderId
            } else {
                var providers = appSettings.getOpenaiCompatibleProviders()
                for (var i = 0; i < providers.length; i++) {
                    if (providers[i].enabled) {
                        currentProvider = "openai-compatible:" + providers[i].id
                        appSettings.selectedOpenAICompatibleProviderId = providers[i].id
                        break
                    }
                }
            }
        }

        if (currentProvider === "ollama") {
            getModels();
        }

        initMcpServers()

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
