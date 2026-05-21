/*
    SPDX-FileCopyrightText: 2026 Denys Madureira <denys@koderoots.org>
    SPDX-License-Identifier: LGPL-2.1-or-later
*/

.pragma library

var _servers = {};
let _requestId = 1;

function getNextRequestId() {
    return _requestId++;
}

function resetRequestId() {
    _requestId = 1;
}

function createJsonRpcRequest(method, params) {
    return {
        jsonrpc: "2.0",
        id: getNextRequestId(),
        method: method,
        params: params || {}
    };
}

function createJsonRpcNotification(method, params) {
    return {
        jsonrpc: "2.0",
        method: method,
        params: params || {}
    };
}

function parseSseResponse(responseText) {
    const lines = responseText.split('\n');
    for (let i = 0; i < lines.length; i++) {
        const line = lines[i].trim();
        if (line.startsWith('data: ')) {
            const dataStr = line.substring(6).trim();
            if (dataStr === '[DONE]') continue;
            try {
                return JSON.parse(dataStr);
            } catch (e) {
                continue;
            }
        }
    }
    try {
        return JSON.parse(responseText);
    } catch (e) {
        return null;
    }
}

function extractAllSseData(responseText) {
    const results = [];
    const lines = responseText.split('\n');
    for (let i = 0; i < lines.length; i++) {
        const line = lines[i].trim();
        if (line.startsWith('data: ')) {
            const dataStr = line.substring(6).trim();
            if (dataStr === '[DONE]') continue;
            try {
                results.push(JSON.parse(dataStr));
            } catch (e) {
                continue;
            }
        }
    }
    if (results.length === 0) {
        try {
            results.push(JSON.parse(responseText));
        } catch (e) { console.warn("Failed to parse fallback response text:", e) }
    }
    return results;
}

function setupCommonHeaders(xhr, headers, sessionId) {
    xhr.setRequestHeader("Content-Type", "application/json");
    xhr.setRequestHeader("Accept", "application/json, text/event-stream");
    if (sessionId) {
        xhr.setRequestHeader("Mcp-Session-Id", sessionId);
    }
    if (headers) {
        const keys = Object.keys(headers);
        for (let i = 0; i < keys.length; i++) {
            const lk = keys[i].toLowerCase();
            if (lk !== "content-type" && lk !== "accept" && lk !== "mcp-session-id") {
                xhr.setRequestHeader(keys[i], headers[i]);
            }
        }
    }
}

function initializeServer(serverUrl, headers, onSuccess, onError) {
    const url = serverUrl.replace(/\/$/, '');
    
    const initRequest = createJsonRpcRequest("initialize", {
        protocolVersion: "2025-03-26",
        capabilities: {
            roots: { listChanged: true },
            sampling: {}
        },
        clientInfo: {
            name: "ChatQT",
            version: "1.0.0"
        }
    });

    const xhr = new XMLHttpRequest();
    xhr.open("POST", url, true);
    setupCommonHeaders(xhr, headers);
    
    xhr.onreadystatechange = function() {
        if (xhr.readyState === XMLHttpRequest.DONE) {
            if (xhr.status === 200 || xhr.status === 201 || xhr.status === 202) {
                try {
                    const response = parseSseResponse(xhr.responseText);
                    if (!response) {
                        if (typeof onError === "function") {
                            onError(-1, "Empty response from MCP server");
                        }
                        return;
                    }
                    if (response.result) {
                        const sessionId = xhr.getResponseHeader("Mcp-Session-Id") || "";
                        const serverUrl_ = url;
                        
                        const notifyXhr = new XMLHttpRequest();
                        notifyXhr.open("POST", serverUrl_, true);
                        setupCommonHeaders(notifyXhr, headers, sessionId);
                        notifyXhr.send(JSON.stringify(createJsonRpcNotification("notifications/initialized", {})));
                        
                        if (typeof onSuccess === "function") {
                            onSuccess({
                                serverInfo: response.result.serverInfo || {},
                                capabilities: response.result.capabilities || {},
                                sessionId: sessionId
                            });
                        }
                    } else if (response.error) {
                        if (typeof onError === "function") {
                            onError(response.error.code || -1, response.error.message || "MCP initialization error");
                        }
                    } else {
                        if (typeof onError === "function") {
                            onError(-1, "Unexpected MCP response format");
                        }
                    }
                } catch (e) {
                    if (typeof onError === "function") {
                        onError(-1, "Failed to parse MCP response: " + e.message);
                    }
                }
            } else {
                if (typeof onError === "function") {
                    let statusText = xhr.statusText || "UNKNOWN";
                    if (xhr.status === 0) statusText = "NETWORK_ERROR";
                    else if (xhr.status === 401) statusText = "UNAUTHORIZED";
                    else if (xhr.status === 404) statusText = "NOT_FOUND";
                    else if (xhr.status === 405) statusText = "METHOD_NOT_ALLOWED";
                    onError(xhr.status, statusText);
                }
            }
        }
    };
    
    xhr.send(JSON.stringify(initRequest));
    return xhr;
}

function listTools(serverUrl, sessionId, headers, onSuccess, onError) {
    const url = serverUrl.replace(/\/$/, '');
    const request = createJsonRpcRequest("tools/list", {});
    
    const xhr = new XMLHttpRequest();
    xhr.open("POST", url, true);
    setupCommonHeaders(xhr, headers, sessionId);
    
    xhr.onreadystatechange = function() {
        if (xhr.readyState === XMLHttpRequest.DONE) {
            if (xhr.status === 200 || xhr.status === 201 || xhr.status === 202) {
                try {
                    const response = parseSseResponse(xhr.responseText);
                    if (!response) {
                        if (typeof onSuccess === "function") {
                            onSuccess([]);
                        }
                        return;
                    }
                    if (response.result && response.result.tools) {
                        if (typeof onSuccess === "function") {
                            onSuccess(response.result.tools);
                        }
                    } else if (response.error) {
                        if (typeof onError === "function") {
                            onError(response.error.code || -1, response.error.message || "MCP tools/list error");
                        }
                    } else {
                        if (typeof onSuccess === "function") {
                            onSuccess([]);
                        }
                    }
                } catch (e) {
                    if (typeof onError === "function") {
                        onError(-1, "Failed to parse tools response: " + e.message);
                    }
                }
            } else {
                if (typeof onError === "function") {
                    let statusText = xhr.statusText || "UNKNOWN";
                    if (xhr.status === 0) statusText = "NETWORK_ERROR";
                    onError(xhr.status, statusText);
                }
            }
        }
    };
    
    xhr.send(JSON.stringify(request));
    return xhr;
}

function callTool(serverUrl, sessionId, headers, toolName, arguments, onSuccess, onError) {
    const url = serverUrl.replace(/\/$/, '');
    const request = createJsonRpcRequest("tools/call", {
        name: toolName,
        arguments: arguments || {}
    });
    
    const xhr = new XMLHttpRequest();
    xhr.open("POST", url, true);
    setupCommonHeaders(xhr, headers, sessionId);
    
    let accumulatedSseData = "";
    let parsedResult = null;
    
    xhr.onreadystatechange = function() {
        if (xhr.readyState === XMLHttpRequest.LOADING || xhr.readyState === XMLHttpRequest.DONE) {
            const responseText = xhr.responseText;
            if (responseText.length > accumulatedSseData.length) {
                const newChunk = responseText.substring(accumulatedSseData.length);
                accumulatedSseData = responseText;
                
                const sseResults = extractAllSseData(newChunk);
                for (let i = 0; i < sseResults.length; i++) {
                    if (sseResults[i].result) {
                        parsedResult = sseResults[i].result;
                    }
                }
            }
        }
        
        if (xhr.readyState === XMLHttpRequest.DONE) {
            if (xhr.status === 200 || xhr.status === 201 || xhr.status === 202) {
                if (parsedResult) {
                    let resultText = "";
                    const isError = parsedResult.isError || false;
                    
                    if (parsedResult.content) {
                        for (let i = 0; i < parsedResult.content.length; i++) {
                            const item = parsedResult.content[i];
                            if (item.type === "text") {
                                resultText += item.text;
                            } else if (item.type === "image") {
                                resultText += "[Image data]";
                            } else if (item.type === "audio") {
                                resultText += "[Audio data]";
                            } else if (item.type === "resource") {
                                resultText += item.resource.text || item.resource.uri || "[Resource]";
                            }
                        }
                    }
                    
                    if (typeof onSuccess === "function") {
                        onSuccess({
                            content: resultText,
                            isError: isError
                        });
                    }
                } else {
                    try {
                        const response = parseSseResponse(xhr.responseText);
                        if (response && response.result) {
                            const res = response.result;
                            let txt = "";
                            const err = res.isError || false;
                            if (res.content) {
                                for (let j = 0; j < res.content.length; j++) {
                                    const c = res.content[j];
                                    if (c.type === "text") txt += c.text;
                                    else if (c.type === "image") txt += "[Image data]";
                                    else if (c.type === "audio") txt += "[Audio data]";
                                    else if (c.type === "resource") txt += (c.resource.text || c.resource.uri || "[Resource]");
                                }
                            }
                            if (typeof onSuccess === "function") {
                                onSuccess({ content: txt, isError: err });
                            }
                        } else if (response && response.error) {
                            if (typeof onError === "function") {
                                onError(response.error.code || -1, response.error.message || "MCP tool call error");
                            }
                        } else {
                            if (typeof onSuccess === "function") {
                                onSuccess({ content: "", isError: false });
                            }
                        }
                    } catch (e) {
                        if (typeof onError === "function") {
                            onError(-1, "Failed to parse tool call response: " + e.message);
                        }
                    }
                }
            } else {
                if (typeof onError === "function") {
                    let statusText = xhr.statusText || "UNKNOWN";
                    if (xhr.status === 0) statusText = "NETWORK_ERROR";
                    else if (xhr.status === 401) statusText = "UNAUTHORIZED";
                    else if (xhr.status === 404) statusText = "NOT_FOUND";
                    onError(xhr.status, statusText);
                }
            }
        }
    };
    
    xhr.send(JSON.stringify(request));
    return xhr;
}

function disconnectServer(serverId) {
    if (_servers[serverId]) {
        delete _servers[serverId];
    }
}

function updateServerState(serverId, state) {
    _servers[serverId] = _servers[serverId] || {};
    Object.keys(state).forEach(function(key) {
        _servers[serverId][key] = state[key];
    });
}

function getServerState(serverId) {
    return _servers[serverId] || null;
}

function mcpToolsToOpenAiFunctions(tools) {
    const functions = [];
    if (!tools || !Array.isArray(tools)) return functions;
    
    for (let i = 0; i < tools.length; i++) {
        const tool = tools[i];
        if (!tool.name) continue;
        
        const func = {
            name: "mcp__" + tool.name,
            description: tool.description || "",
            parameters: tool.inputSchema || {
                type: "object",
                properties: {}
            }
        };
        
        functions.push(func);
    }
    
    return functions;
}

function parseToolCallName(functionName) {
    if (functionName && functionName.startsWith("mcp__")) {
        return functionName.substring(5);
    }
    return functionName;
}

function isMcpToolCall(functionName) {
    return functionName && functionName.startsWith("mcp__");
}
