/*
    SPDX-FileCopyrightText: 2023 Denys Madureira <denysmb@zoho.com>
    SPDX-License-Identifier: LGPL-2.1-or-later
*/

.pragma library

var _activeXhr = null;

function abortActiveRequest() {
    if (_activeXhr) {
        _activeXhr.onreadystatechange = function() {};
        _activeXhr.onload = function() {};
        _activeXhr.abort();
        _activeXhr = null;
        return true;
    }
    return false;
}

function requestOllama(modelsComboboxCurrentValue, promptArray, listModel, onStreaming, onComplete, thinkingEnabled) {
    const oldLength = listModel.count;
    const url = 'http://127.0.0.1:11434/api/chat';
    const data = JSON.stringify({
        "model": modelsComboboxCurrentValue,
        "keep_alive": "5m",
        "options": {},
        "think": thinkingEnabled !== false,
        "messages": promptArray
    });

    let xhr = new XMLHttpRequest();
    _activeXhr = xhr;

    xhr.open('POST', url, true);
    xhr.setRequestHeader('Content-Type', 'application/json');

    let processedLength = 0;
    let accumulatedText = '';
    let accumulatedThinking = '';

    xhr.onreadystatechange = function() {
        if (xhr.readyState === XMLHttpRequest.LOADING || xhr.readyState === XMLHttpRequest.DONE) {
            const response = xhr.responseText;

            if (response.length > processedLength) {
                const newChunk = response.substring(processedLength);
                processedLength = response.length;

                const lines = newChunk.split('\n');
                let hasUpdate = false;

                for (let i = 0; i < lines.length; i++) {
                    const line = lines[i].trim();
                    if (!line) continue;

                    try {
                        const parsedObject = JSON.parse(line);
                        const content = parsedObject?.message?.content;
                        const thinking = parsedObject?.message?.thinking;

                        // Accumulate incremental deltas
                        if (content) {
                            accumulatedText += content;
                            hasUpdate = true;
                        }
                        if (thinking) {
                            accumulatedThinking += thinking;
                            hasUpdate = true;
                        }
                    } catch (e) {
                        // Skip invalid JSON
                    }
                }

                if (hasUpdate && typeof onStreaming === 'function') {
                    onStreaming(accumulatedText, oldLength, listModel, accumulatedThinking);
                }
            }
        }
    };

    xhr.onload = function() {
        if (typeof onComplete === 'function') {
            onComplete(oldLength, listModel);
        }
    };

    xhr.send(data);
    return xhr;
}

function requestOpenAICompatible(baseUrl, token, model, promptArray, thinkingEnabled, extraHeaders, includeV1, listModel, onStreaming, onComplete, mcpFunctions) {
    const oldLength = listModel.count;
    let url = baseUrl.replace(/\/$/, '');
    if (includeV1) {
        url += '/v1';
    }
    url += '/chat/completions';

    let requestData = {
        "model": model,
        "messages": promptArray,
        "stream": true
    };

    if (!thinkingEnabled) {
        requestData["chat_template_kwargs"] = {"enable_thinking": false};
    }

    if (mcpFunctions && mcpFunctions.length > 0) {
        requestData["tools"] = mcpFunctions.map(function(f) {
            return {
                type: "function",
                function: {
                    name: f.name,
                    description: f.description,
                    parameters: f.parameters
                }
            };
        });
    }

    const data = JSON.stringify(requestData);

    let xhr = new XMLHttpRequest();
    _activeXhr = xhr;

    xhr.open('POST', url, true);
    xhr.setRequestHeader('Content-Type', 'application/json');
    xhr.setRequestHeader('Authorization', 'Bearer ' + token);

    if (extraHeaders) {
        for (const [key, value] of Object.entries(extraHeaders)) {
            xhr.setRequestHeader(key, value);
        }
    }

    let text = '';
    let thinkingText = '';
    let processedLength = 0;
    let toolCalls = {};
    let hasToolCalls = false;

    xhr.onreadystatechange = function() {
        if (xhr.readyState === XMLHttpRequest.LOADING || xhr.readyState === XMLHttpRequest.DONE) {
            const response = xhr.responseText;

            if (response.length > processedLength) {
                const newChunk = response.substring(processedLength);
                processedLength = response.length;

                const lines = newChunk.split('\n');

                for (let i = 0; i < lines.length; i++) {
                    const line = lines[i].trim();

                    if (line.startsWith('data: ')) {
                        const dataStr = line.substring(6);

                        if (dataStr === '[DONE]') {
                            continue;
                        }

                        try {
                            const parsed = JSON.parse(dataStr);
                            const choices = parsed.choices;
                            if (choices && choices.length > 0) {
                                const delta = choices[0].delta;
                                const finishReason = choices[0].finish_reason;
                                if (delta) {
                                    let hasUpdate = false;

                                    if (delta.reasoning_content) {
                                        thinkingText += delta.reasoning_content;
                                        hasUpdate = true;
                                    }

                                    if (delta.reasoning) {
                                        thinkingText += delta.reasoning;
                                        hasUpdate = true;
                                    }

                                    if (delta.content) {
                                        text += delta.content;
                                        hasUpdate = true;
                                    }

                                    if (delta.tool_calls) {
                                        hasToolCalls = true;
                                        for (var tc = 0; tc < delta.tool_calls.length; tc++) {
                                            var toolCall = delta.tool_calls[tc];
                                            var tcIndex = toolCall.index !== undefined ? toolCall.index : tc;
                                            if (!toolCalls[tcIndex]) {
                                                toolCalls[tcIndex] = {
                                                    id: toolCall.id || "",
                                                    type: "function",
                                                    function: {
                                                        name: "",
                                                        arguments: ""
                                                    }
                                                };
                                            }
                                            if (toolCall.id) {
                                                toolCalls[tcIndex].id = toolCall.id;
                                            }
                                            if (toolCall.function) {
                                                if (toolCall.function.name) {
                                                    toolCalls[tcIndex].function.name += toolCall.function.name;
                                                }
                                                if (toolCall.function.arguments) {
                                                    toolCalls[tcIndex].function.arguments += toolCall.function.arguments;
                                                }
                                            }
                                        }
                                    }

                                    if (hasUpdate && typeof onStreaming === 'function') {
                                        onStreaming(text, oldLength, listModel, thinkingText);
                                    }
                                }

                                if (finishReason === 'tool_calls') {
                                    hasToolCalls = true;
                                }
                            }
                        } catch (e) {
                            // Skip invalid JSON
                        }
                    }
                }
            }
        }

        if (xhr.readyState === XMLHttpRequest.DONE) {
            if (typeof onComplete === 'function') {
                var finalToolCalls = [];
                if (hasToolCalls) {
                    var tcKeys = Object.keys(toolCalls);
                    for (var k = 0; k < tcKeys.length; k++) {
                        finalToolCalls.push(toolCalls[tcKeys[k]]);
                    }
                }
                onComplete(oldLength, listModel, text, finalToolCalls);
            }
        }
    };

    xhr.send(data);
    return xhr;
}

function getOllamaModels(onSuccess, onError) {
    const url = 'http://127.0.0.1:11434/api/tags';

    let xhr = new XMLHttpRequest();

    xhr.open('GET', url);
    xhr.setRequestHeader('Content-Type', 'application/json');

    xhr.onreadystatechange = function() {
        if (xhr.readyState === XMLHttpRequest.DONE) {
            if (xhr.status === 200) {
                const objects = JSON.parse(xhr.responseText).models;
                const models = objects.map(object => object.model);
                if (typeof onSuccess === 'function') {
                    onSuccess(models);
                }
            } else {
                if (typeof onError === 'function') {
                    onError(xhr.status, xhr.statusText);
                }
            }
        }
    };

    xhr.send();
}

function preprocessMarkdown(text) {
    return text
        .replace(/^#{1,6}\s+(.+)$/gm, '**$1**')
        .replace(/\*\*\*([^*]+)\*\*\*/g, '**$1**')
        .replace(/___([^_]+)___/g, '*$1*');
}

function testConnection(providerType, baseUrl, token, model, extraHeaders, includeV1, onSuccess, onError) {
    var cleanUrl = baseUrl.replace(/\/$/, '');

    if (providerType === "ollama") {
        var url = cleanUrl + "/api/tags";
        var xhr = new XMLHttpRequest();
        xhr.open("GET", url, true);
        xhr.setRequestHeader("Content-Type", "application/json");

        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    try {
                        var response = JSON.parse(xhr.responseText);
                        var modelCount = response.models ? response.models.length : 0;
                        if (typeof onSuccess === "function") {
                            onSuccess({ modelCount: modelCount });
                        }
                    } catch (e) {
                        if (typeof onSuccess === "function") {
                            onSuccess({ modelCount: 0 });
                        }
                    }
                } else {
                    if (typeof onError === "function") {
                        var statusText = xhr.statusText || "UNKNOWN";
                        if (xhr.status === 0) statusText = "NETWORK_ERROR";
                        else if (xhr.status === 401) statusText = "UNAUTHORIZED";
                        else if (xhr.status === 404) statusText = "NOT_FOUND";
                        onError({ status: xhr.status, statusText: statusText });
                    }
                }
            }
        };

        xhr.send();
        return xhr;
    }

    var url = cleanUrl;
    if (includeV1 && !cleanUrl.endsWith("/v1")) {
        url = cleanUrl + "/v1";
    }
    url += "/chat/completions";

    var data = JSON.stringify({
        "model": model,
        "messages": [{"role": "user", "content": "hi"}],
        "max_tokens": 1
    });

    var xhr = new XMLHttpRequest();
    xhr.open("POST", url, true);
    xhr.setRequestHeader("Content-Type", "application/json");
    if (token) {
        xhr.setRequestHeader("Authorization", "Bearer " + token);
    }

    if (extraHeaders) {
        var keys = Object.keys(extraHeaders);
        for (var i = 0; i < keys.length; i++) {
            xhr.setRequestHeader(keys[i], extraHeaders[i]);
        }
    }

    xhr.onreadystatechange = function() {
        if (xhr.readyState === XMLHttpRequest.DONE) {
            if (xhr.status === 200) {
                if (typeof onSuccess === "function") {
                    onSuccess({ modelCount: 0 });
                }
            } else {
                if (typeof onError === "function") {
                    var statusText = xhr.statusText || "UNKNOWN";
                    if (xhr.status === 0) statusText = "NETWORK_ERROR";
                    else if (xhr.status === 401) statusText = "UNAUTHORIZED";
                    else if (xhr.status === 404) statusText = "NOT_FOUND";
                    onError({ status: xhr.status, statusText: statusText });
                }
            }
        }
    };

    xhr.send(data);
    return xhr;
}

function parseTextToComboBox(text) {
    return text
        .replace(/-/g, ' ')
        .replace(/:(.+)/, ' ($1)')
        .split(' ')
        .map(word => {
            if (word.startsWith('(')) {
                return word.charAt(0) + word.charAt(1).toUpperCase() + word.slice(2);
            }
            return word.charAt(0).toUpperCase() + word.slice(1);
        })
        .join(' ');
}