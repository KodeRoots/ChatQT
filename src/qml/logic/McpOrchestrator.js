/*
    SPDX-FileCopyrightText: 2026 Denys Madureira <denys@koderoots.org>
    SPDX-License-Identifier: LGPL-2.1-or-later
*/

.pragma library

var _stdioPendingCalls = {};
var _mcpStartupNotifications = {};
var _toolCallDepth = 0;
const MAX_TOOL_CALL_DEPTH = 10;

function getStdioPendingCalls() {
    return _stdioPendingCalls;
}

function getMcpStartupNotifications() {
    return _mcpStartupNotifications;
}

function getToolCallDepth() {
    return _toolCallDepth;
}

function resetToolCallDepth() {
    _toolCallDepth = 0;
}

function initMcpServers(appSettings, McpClient, McpProcessManager, initSingleServer) {
    const servers = appSettings.getMcpServers();
    for (let i = 0; i < servers.length; i++) {
        if (servers[i].enabled) {
            initSingleServer(servers[i]);
        }
    }
}

function initMcpServer(server, deps) {
    const { McpClient, McpProcessManager, i18n, showNotification } = deps;

    const state = McpClient.getServerState(server.id);
    if (state && (state.status === "connected" || state.status === "connecting")) return;

    const displayName = server.displayName || server.id;
    showNotification(i18n("Connecting to %1…").arg(displayName));

    if (server.type === "stdio") {
        if (!server.command) {
            showNotification(i18n("Failed to connect to %1: no command configured").arg(displayName));
            return;
        }
        let envMap = {};
        if (server.env) {
            try { envMap = JSON.parse(server.env); }
            catch (e) { console.warn("Failed to parse MCP server env JSON:", e); }
        }
        let argsList = [];
        if (server.args) {
            argsList = server.args.split(/\s+/).filter(function(a) { return a.length > 0; });
        }
        _mcpStartupNotifications[server.id] = displayName;
        McpProcessManager.startProcess(server.id, server.command, argsList, envMap);
    } else {
        if (!server.url) {
            showNotification(i18n("Failed to connect to %1: no URL configured").arg(displayName));
            return;
        }
        let headers = {};
        if (server.token) { headers["Authorization"] = "Bearer " + server.token; }
        if (server.headers) {
            try {
                const customHeaders = JSON.parse(server.headers);
                const keys = Object.keys(customHeaders);
                for (let k = 0; k < keys.length; k++) { headers[keys[k]] = customHeaders[keys[k]]; }
            } catch (e) { console.warn("Failed to parse custom headers:", e); }
        }
        McpClient.initializeServer(
            server.url, headers,
            function(result) {
                McpClient.updateServerState(server.id, {
                    status: "connected", sessionId: result.sessionId,
                    serverInfo: result.serverInfo, capabilities: result.capabilities,
                    headers: headers, url: server.url.replace(/\/$/, ''), type: "remote"
                });
                McpClient.listTools(
                    server.url, result.sessionId, headers,
                    function(tools) {
                        McpClient.updateServerState(server.id, { tools: tools, toolCount: tools.length });
                        showNotification(i18n("Connected to %1 — %2 tool(s) available").arg(displayName).arg(tools.length));
                    },
                    function() {
                        McpClient.updateServerState(server.id, { tools: [], toolCount: 0 });
                        showNotification(i18n("Connected to %1 but failed to list tools").arg(displayName));
                    }
                );
            },
            function(code, message) {
                McpClient.updateServerState(server.id, { status: "error" });
                showNotification(i18n("Failed to connect to %1: %2").arg(displayName).arg(message));
            }
        );
    }
}

function gatherMcpFunctions(appSettings, McpClient) {
    const functions = [];
    const servers = appSettings.getEnabledMcpServers();
    for (let i = 0; i < servers.length; i++) {
        const state = McpClient.getServerState(servers[i].id);
        if (state && state.tools && state.tools.length > 0) {
            const converted = McpClient.mcpToolsToOpenAiFunctions(state.tools);
            for (let j = 0; j < converted.length; j++) {
                functions.push(converted[j]);
            }
        }
    }
    return functions;
}

function hasConnectedMcpServers(appSettings, McpClient) {
    const servers = appSettings.getEnabledMcpServers();
    for (let i = 0; i < servers.length; i++) {
        const state = McpClient.getServerState(servers[i].id);
        if (state && state.status === "connected") {
            return true;
        }
    }
    return false;
}

function extractContentText(content) {
    let text = "";
    if (!content) return text;
    for (let i = 0; i < content.length; i++) {
        const item = content[i];
        if (item.type === "text") text += item.text;
        else if (item.type === "image") text += "[Image data]";
        else if (item.type === "audio") text += "[Audio data]";
        else if (item.type === "resource") text += (item.resource.text || item.resource.uri || "[Resource]");
    }
    return text;
}

function handleMcpToolCalls(oldLength, listModel, finalText, toolCalls, capturedSessionId, deps) {
    const { currentSessionId, i18n, SessionStore, promptArray, sessionPromptArrays } = deps;
    const sessionId = capturedSessionId || currentSessionId;
    const isActiveSession = sessionId === currentSessionId;
    _toolCallDepth++;

    if (isActiveSession) {
        if (listModel.count === oldLength) {
            let displayText = finalText || "";
            if (displayText === "" && toolCalls.length > 0) {
                const toolNames = [];
                for (let t = 0; t < toolCalls.length; t++) {
                    toolNames.push(toolCalls[t].function.name);
                }
                displayText = i18n("Calling tools: %1", toolNames.join(", "));
            }
            listModel.append({
                "name": "Assistant",
                "content": displayText,
                "thinkingContent": ""
            });
        } else {
            if (finalText) {
                listModel.setProperty(oldLength, "content", finalText);
            }
        }
    }

    const assistantMsg = { "role": "assistant", "content": finalText || "" };
    if (toolCalls.length > 0) {
        assistantMsg["tool_calls"] = toolCalls;
    }

    const sessionPA = sessionPromptArrays[sessionId] || promptArray;
    sessionPA.push(assistantMsg);
    sessionPromptArrays[sessionId] = sessionPA;

    if (sessionId !== "") {
        SessionStore.addMessage(sessionId, "assistant", finalText || "", "");
    }

    const pendingToolCalls = [];
    for (let i = 0; i < toolCalls.length; i++) {
        pendingToolCalls.push(toolCalls[i]);
    }

    executeNextMcpToolCall(pendingToolCalls, 0, oldLength, listModel, sessionId, deps);
}

function executeNextMcpToolCall(toolCalls, currentIndex, oldLength, listModel, capturedSessionId, deps) {
    const { currentSessionId, McpClient, appSettings, i18n, promptArray, SessionStore } = deps;
    const sessionId = capturedSessionId || currentSessionId;
    const isActiveSession = sessionId === currentSessionId;

    if (currentIndex >= toolCalls.length) {
        deps.sendMcpFollowUpRequest(oldLength, listModel, sessionId);
        return;
    }

    const toolCall = toolCalls[currentIndex];
    const funcName = toolCall.function.name;
    let funcArgs = {};
    try {
        const rawArgs = toolCall.function.arguments;
        if (typeof rawArgs === 'object' && rawArgs !== null) {
            funcArgs = rawArgs;
        } else {
            funcArgs = JSON.parse(rawArgs || "{}");
        }
    } catch (e) {
        console.warn("Failed to parse tool call arguments:", e);
        funcArgs = {};
    }

    const mcpToolName = McpClient.parseToolCallName(funcName);
    const isMcp = McpClient.isMcpToolCall(funcName);

    listModel.append({
        "name": "Tool",
        "content": i18n("Calling %1…").arg(funcName),
        "thinkingContent": ""
    });

    if (!isMcp) {
        const errorMsg = i18n("Tool %1 is not an MCP tool").arg(funcName);
        if (isActiveSession) listModel.setProperty(listModel.count - 1, "content", errorMsg);
        promptArray.push({
            "role": "tool",
            "tool_call_id": toolCall.id,
            "content": errorMsg
        });
        executeNextMcpToolCall(toolCalls, currentIndex + 1, oldLength, listModel, sessionId, deps);
        return;
    }

    const servers = appSettings.getEnabledMcpServers();
    let foundServer = null;
    let foundTools = null;

    for (let s = 0; s < servers.length; s++) {
        const state = McpClient.getServerState(servers[s].id);
        if (state && state.tools) {
            for (let t = 0; t < state.tools.length; t++) {
                if (state.tools[t].name === mcpToolName) {
                    foundServer = servers[s];
                    foundTools = state;
                    break;
                }
            }
            if (foundServer) break;
        }
    }

    if (!foundServer) {
        const errorMsg2 = i18n("MCP server not found for tool %1").arg(funcName);
        if (isActiveSession) listModel.setProperty(listModel.count - 1, "content", errorMsg2);
        promptArray.push({
            "role": "tool",
            "tool_call_id": toolCall.id,
            "content": errorMsg2
        });
        executeNextMcpToolCall(toolCalls, currentIndex + 1, oldLength, listModel, sessionId, deps);
        return;
    }

    if (foundServer.type === "stdio" || foundTools.type === "stdio") {
        callStdioMcpTool(foundServer.id, mcpToolName, funcArgs, toolCall.id, funcName, listModel, toolCalls, currentIndex, oldLength, sessionId, deps);
        return;
    }

    McpClient.callTool(
        foundServer.url,
        foundTools.sessionId,
        foundTools.headers,
        mcpToolName,
        funcArgs,
        function(result) {
            let resultContent = result.content || "";
            if (result.isError) {
                resultContent = i18n("Error: %1").arg(resultContent);
            }
            if (isActiveSession) {
                listModel.setProperty(listModel.count - 1, "content",
                    i18n("%1: %2").arg(funcName).arg(resultContent.substring(0, 500)));
            }
            if (sessionId !== "") {
                SessionStore.addMessage(sessionId, "tool",
                    i18n("%1 result: %2").arg(funcName).arg(resultContent.substring(0, 500)), "");
            }
            promptArray.push({
                "role": "tool",
                "tool_call_id": toolCall.id,
                "content": resultContent
            });
            executeNextMcpToolCall(toolCalls, currentIndex + 1, oldLength, listModel, sessionId, deps);
        },
        function(code, message) {
            const errorMsg3 = i18n("Tool %1 failed: %2").arg(funcName).arg(message);
            if (isActiveSession) listModel.setProperty(listModel.count - 1, "content", errorMsg3);
            promptArray.push({
                "role": "tool",
                "tool_call_id": toolCall.id,
                "content": errorMsg3
            });
            executeNextMcpToolCall(toolCalls, currentIndex + 1, oldLength, listModel, sessionId, deps);
        }
    );
}

function callStdioMcpTool(serverId, toolName, arguments, toolCallId, funcName, listModel, toolCalls, currentIndex, oldLength, capturedSessionId, deps) {
    const { McpClient, McpProcessManager } = deps;

    const request = McpClient.createJsonRpcRequest("tools/call", {
        name: toolName,
        arguments: arguments
    });
    const requestId = request.id;
    const jsonStr = JSON.stringify(request);

    _stdioPendingCalls[requestId] = {
        toolCallId: toolCallId,
        funcName: funcName,
        listModel: listModel,
        toolCalls: toolCalls,
        currentIndex: currentIndex,
        oldLength: oldLength,
        capturedSessionId: capturedSessionId
    };

    McpProcessManager.sendMessage(serverId, jsonStr, requestId);
}

function handleStdioMessage(serverId, jsonMessage, deps) {
    const { McpClient, McpProcessManager, currentSessionId, i18n, promptArray, SessionStore, showNotification } = deps;

    try {
        const response = JSON.parse(jsonMessage);

        if (response.result && response.result.tools) {
            McpClient.updateServerState(serverId, {
                status: "connected",
                tools: response.result.tools,
                toolCount: response.result.tools.length,
                type: "stdio",
                serverId: serverId
            });
            if (_mcpStartupNotifications[serverId]) {
                showNotification(
                    i18n("Connected to %1 — %2 tool(s) available").arg(_mcpStartupNotifications[serverId]).arg(response.result.tools.length)
                );
                delete _mcpStartupNotifications[serverId];
            }
        }

        if (response.method === "notifications/tools/list_changed") {
            const requestId = McpClient.getNextRequestId();
            const toolsRequest = McpClient.createJsonRpcRequest("tools/list", {});
            McpProcessManager.sendMessage(serverId, JSON.stringify(toolsRequest), requestId);
        }

        if (!response.id || !_stdioPendingCalls[response.id]) return;

        const pending = _stdioPendingCalls[response.id];
        delete _stdioPendingCalls[response.id];

        if (response.result) {
            let resultText = extractContentText(response.result.content);
            const isError = response.result.isError || false;

            if (isError) {
                resultText = i18n("Error: %1").arg(resultText);
            }

            const stdioSessionId = pending.capturedSessionId || currentSessionId;
            const stdioIsActive = stdioSessionId === currentSessionId;

            if (stdioIsActive) {
                pending.listModel.setProperty(pending.listModel.count - 1, "content",
                    i18n("%1: %2").arg(pending.funcName).arg(resultText.substring(0, 500)));
            }

            if (stdioSessionId !== "") {
                SessionStore.addMessage(stdioSessionId, "tool",
                    i18n("%1 result: %2").arg(pending.funcName).arg(resultText.substring(0, 500)), "");
            }

            promptArray.push({
                "role": "tool",
                "tool_call_id": pending.toolCallId,
                "content": resultText
            });

            executeNextMcpToolCall(pending.toolCalls, pending.currentIndex + 1, pending.oldLength, pending.listModel, stdioSessionId, deps);
        } else if (response.error) {
            const errorMsg = i18n("Tool %1 failed: %2").arg(pending.funcName).arg(response.error.message || "Unknown error");
            const errSessionId = pending.capturedSessionId || currentSessionId;
            const errIsActive = errSessionId === currentSessionId;

            if (errIsActive) {
                pending.listModel.setProperty(pending.listModel.count - 1, "content", errorMsg);
            }

            promptArray.push({
                "role": "tool",
                "tool_call_id": pending.toolCallId,
                "content": errorMsg
            });

            executeNextMcpToolCall(pending.toolCalls, pending.currentIndex + 1, pending.oldLength, pending.listModel, errSessionId, deps);
        }
    } catch (e) {
        console.warn("Failed to process stdio MCP response:", e);
    }
}

function handleProcessStatusChanged(serverId, status, deps) {
    const { McpClient, i18n, showNotification } = deps;

    if (status === "connected") {
        McpClient.updateServerState(serverId, { status: "connected" });
    } else if (status === "disconnected") {
        McpClient.updateServerState(serverId, { status: "disconnected", tools: [], toolCount: 0 });
        if (_mcpStartupNotifications[serverId]) {
            showNotification(i18n("%1 disconnected").arg(_mcpStartupNotifications[serverId]));
            delete _mcpStartupNotifications[serverId];
        }
    } else if (status === "error") {
        McpClient.updateServerState(serverId, { status: "error", tools: [], toolCount: 0 });
        if (_mcpStartupNotifications[serverId]) {
            showNotification(i18n("Failed to start %1").arg(_mcpStartupNotifications[serverId]));
            delete _mcpStartupNotifications[serverId];
        }
    }
}

function handleProcessError(serverId, errorMessage, deps) {
    const { McpClient, i18n, showNotification } = deps;

    McpClient.updateServerState(serverId, { status: "error" });
    if (_mcpStartupNotifications[serverId]) {
        showNotification(i18n("Failed to start %1: %2").arg(_mcpStartupNotifications[serverId]).arg(errorMessage));
        delete _mcpStartupNotifications[serverId];
    }
}
