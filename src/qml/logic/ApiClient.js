/*
    SPDX-FileCopyrightText: 2023 Denys Madureira <denysmb@zoho.com>
    SPDX-License-Identifier: LGPL-2.1-or-later
*/

.pragma library

var _activeXhr = null;

function _mapErrorStatus(status, statusText) {
    if (status === 0) return "NETWORK_ERROR";
    if (status === 401) return "UNAUTHORIZED";
    if (status === 404) return "NOT_FOUND";
    return statusText || "UNKNOWN";
}

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

function buildToolsPayload(mcpFunctions) {
    if (!mcpFunctions || mcpFunctions.length === 0) return undefined;
    return mcpFunctions.map(function(f) {
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

function buildOllamaRequestData(model, promptArray, thinkingEnabled, mcpFunctions) {
    const requestData = {
        "model": model,
        "keep_alive": "5m",
        "stream": true,
        "options": {},
        "messages": promptArray
    };

    if (thinkingEnabled === true) {
        requestData["think"] = true;
    }

    const tools = buildToolsPayload(mcpFunctions);
    if (tools) {
        requestData["tools"] = tools;
    }

    return requestData;
}

function parseOllamaChunk(parsedObject, state) {
    if (parsedObject.error) {
        state.errorDetected = true;
        state.accumulatedText = parsedObject.error;
        state.hasUpdate = true;
        return;
    }

    const content = parsedObject?.message?.content;
    const thinking = parsedObject?.message?.thinking;
    const msgToolCalls = parsedObject?.message?.tool_calls;
    const doneReason = parsedObject?.done_reason;

    if (content) {
        state.accumulatedText += content;
        state.hasUpdate = true;
    }
    if (thinking) {
        state.accumulatedThinking += thinking;
        state.hasUpdate = true;
    }
    if (msgToolCalls && msgToolCalls.length > 0) {
        state.hasToolCalls = true;
        for (let tc = 0; tc < msgToolCalls.length; tc++) {
            const tcItem = msgToolCalls[tc];
            const tcIndex = tc;
            if (!state.toolCalls[tcIndex]) {
                state.toolCalls[tcIndex] = {
                    id: tcItem.id || ("ollama_tc_" + tcIndex),
                    type: "function",
                    function: { name: "", arguments: "" }
                };
            }
            if (tcItem.id) {
                state.toolCalls[tcIndex].id = tcItem.id;
            }
            if (tcItem.function) {
                if (tcItem.function.name) {
                    state.toolCalls[tcIndex].function.name = tcItem.function.name;
                }
                if (tcItem.function.arguments) {
                    if (typeof tcItem.function.arguments === 'string') {
                        state.toolCalls[tcIndex].function.arguments += tcItem.function.arguments;
                    } else {
                        state.toolCalls[tcIndex].function.arguments = tcItem.function.arguments;
                    }
                }
            }
        }
    }
    if (doneReason === 'tool_calls') {
        state.hasToolCalls = true;
    }
}

function buildOllamaFinalResult(state, xhrStatus, xhrResponseText) {
    if (xhrStatus !== 200 && !state.errorDetected && state.accumulatedText === '') {
        state.accumulatedText = 'Ollama error: HTTP ' + xhrStatus;
        if (xhrResponseText) {
            try {
                const errObj = JSON.parse(xhrResponseText);
                if (errObj.error) {
                    state.accumulatedText = errObj.error;
                }
            } catch (e) { console.warn("Failed to parse Ollama error response:", e) }
        }
    }

    const finalToolCalls = [];
    if (state.hasToolCalls && !state.errorDetected) {
        const tcKeys = Object.keys(state.toolCalls);
        for (let k = 0; k < tcKeys.length; k++) {
            finalToolCalls.push(state.toolCalls[tcKeys[k]]);
        }
    }

    return { text: state.accumulatedText, toolCalls: finalToolCalls };
}

function requestOllama(modelsComboboxCurrentValue, promptArray, listModel, onStreaming, onComplete, thinkingEnabled, mcpFunctions) {
    const oldLength = listModel.count;
    const url = 'http://127.0.0.1:11434/api/chat';
    const requestData = buildOllamaRequestData(modelsComboboxCurrentValue, promptArray, thinkingEnabled, mcpFunctions);
    const data = JSON.stringify(requestData);

    const xhr = new XMLHttpRequest();
    _activeXhr = xhr;

    xhr.open('POST', url, true);
    xhr.setRequestHeader('Content-Type', 'application/json');

    let processedLength = 0;
    const state = {
        accumulatedText: '',
        accumulatedThinking: '',
        toolCalls: {},
        hasToolCalls: false,
        hasUpdate: false,
        errorDetected: false
    };

    xhr.onreadystatechange = function() {
        if (xhr.readyState === XMLHttpRequest.LOADING || xhr.readyState === XMLHttpRequest.DONE) {
            const response = xhr.responseText;
            if (response.length > processedLength) {
                const newChunk = response.substring(processedLength);
                processedLength = response.length;
                const lines = newChunk.split('\n');
                state.hasUpdate = false;

                for (let i = 0; i < lines.length; i++) {
                    const line = lines[i].trim();
                    if (!line) continue;
                    try {
                        const parsedObject = JSON.parse(line);
                        parseOllamaChunk(parsedObject, state);
                    } catch (e) {
                        console.warn("Skipping invalid JSON chunk in Ollama stream:", e)
                    }
                }

                if (state.hasUpdate && typeof onStreaming === 'function') {
                    onStreaming(state.accumulatedText, oldLength, listModel, state.accumulatedThinking);
                }
            }
        }

        if (xhr.readyState === XMLHttpRequest.DONE) {
            if (typeof onComplete === 'function') {
                const result = buildOllamaFinalResult(state, xhr.status, xhr.responseText);
                onComplete(oldLength, listModel, result.text, result.toolCalls);
            }
        }
    };

    xhr.send(data);
    return xhr;
}

function parseOpenAIChunk(parsed, state) {
    const choices = parsed.choices;
    if (!choices || choices.length === 0) return;

    const delta = choices[0].delta;
    const finishReason = choices[0].finish_reason;

    if (delta) {
        if (delta.reasoning_content) {
            state.text += delta.reasoning_content;
            state.hasUpdate = true;
        }
        if (delta.reasoning) {
            state.text += delta.reasoning;
            state.hasUpdate = true;
        }
        if (delta.content) {
            state.text += delta.content;
            state.hasUpdate = true;
        }

        if (delta.tool_calls) {
            state.hasToolCalls = true;
            for (let tc = 0; tc < delta.tool_calls.length; tc++) {
                const toolCall = delta.tool_calls[tc];
                const tcIndex = toolCall.index !== undefined ? toolCall.index : tc;
                if (!state.toolCalls[tcIndex]) {
                    state.toolCalls[tcIndex] = {
                        id: toolCall.id || "",
                        type: "function",
                        function: { name: "", arguments: "" }
                    };
                }
                if (toolCall.id) {
                    state.toolCalls[tcIndex].id = toolCall.id;
                }
                if (toolCall.function) {
                    if (toolCall.function.name) {
                        state.toolCalls[tcIndex].function.name += toolCall.function.name;
                    }
                    if (toolCall.function.arguments) {
                        state.toolCalls[tcIndex].function.arguments += toolCall.function.arguments;
                    }
                }
            }
        }

        if (state.hasUpdate && typeof state.onStreaming === 'function') {
            state.onStreaming(state.text, state.oldLength, state.listModel, state.thinkingText);
        }
    }

    if (finishReason === 'tool_calls') {
        state.hasToolCalls = true;
    }
}

function buildOpenAIFinalResult(state) {
    const finalToolCalls = [];
    if (state.hasToolCalls) {
        const tcKeys = Object.keys(state.toolCalls);
        for (let k = 0; k < tcKeys.length; k++) {
            finalToolCalls.push(state.toolCalls[tcKeys[k]]);
        }
    }
    return { text: state.text, toolCalls: finalToolCalls };
}

function requestOpenAICompatible(baseUrl, token, model, promptArray, thinkingEnabled, extraHeaders, includeV1, listModel, onStreaming, onComplete, mcpFunctions) {
    const oldLength = listModel.count;
    let url = baseUrl.replace(/\/$/, '');
    if (includeV1) {
        url += '/v1';
    }
    url += '/chat/completions';

    const requestData = {
        "model": model,
        "messages": promptArray,
        "stream": true
    };

    if (!thinkingEnabled) {
        requestData["chat_template_kwargs"] = {"enable_thinking": false};
    }

    const tools = buildToolsPayload(mcpFunctions);
    if (tools) {
        requestData["tools"] = tools;
    }

    const data = JSON.stringify(requestData);

    const xhr = new XMLHttpRequest();
    _activeXhr = xhr;

    xhr.open('POST', url, true);
    xhr.setRequestHeader('Content-Type', 'application/json');
    xhr.setRequestHeader('Authorization', 'Bearer ' + token);

    if (extraHeaders) {
        for (const [key, value] of Object.entries(extraHeaders)) {
            xhr.setRequestHeader(key, value);
        }
    }

    let processedLength = 0;
    const state = {
        text: '',
        thinkingText: '',
        toolCalls: {},
        hasToolCalls: false,
        hasUpdate: false,
        onStreaming: onStreaming,
        oldLength: oldLength,
        listModel: listModel
    };

    xhr.onreadystatechange = function() {
        if (xhr.readyState === XMLHttpRequest.LOADING || xhr.readyState === XMLHttpRequest.DONE) {
            const response = xhr.responseText;
            if (response.length > processedLength) {
                const newChunk = response.substring(processedLength);
                processedLength = response.length;
                const lines = newChunk.split('\n');

                for (let i = 0; i < lines.length; i++) {
                    const line = lines[i].trim();
                    if (!line.startsWith('data: ')) continue;

                    const dataStr = line.substring(6);
                    if (dataStr === '[DONE]') continue;

                    try {
                        const parsed = JSON.parse(dataStr);
                        state.hasUpdate = false;
                        parseOpenAIChunk(parsed, state);
                    } catch (e) {
                        console.warn("Skipping invalid JSON chunk in OpenAI stream:", e)
                    }
                }
            }
        }

        if (xhr.readyState === XMLHttpRequest.DONE) {
            if (typeof onComplete === 'function') {
                const result = buildOpenAIFinalResult(state);
                onComplete(oldLength, listModel, result.text, result.toolCalls);
            }
        }
    };

    xhr.send(data);
    return xhr;
}

function getOllamaModels(onSuccess, onError) {
    const url = 'http://127.0.0.1:11434/api/tags';
    const xhr = new XMLHttpRequest();

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
    const cleanUrl = baseUrl.replace(/\/$/, '');

    if (providerType === "ollama") {
        const url = cleanUrl + "/api/tags";
        const xhr = new XMLHttpRequest();
        xhr.open("GET", url, true);
        xhr.setRequestHeader("Content-Type", "application/json");

        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    try {
                        const response = JSON.parse(xhr.responseText);
                        const modelCount = response.models ? response.models.length : 0;
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
                        const statusText = _mapErrorStatus(xhr.status, xhr.statusText);
                        onError({ status: xhr.status, statusText: statusText });
                    }
                }
            }
        };

        xhr.send();
        return xhr;
    }

    let url = cleanUrl;
    if (includeV1 && !cleanUrl.endsWith("/v1")) {
        url = cleanUrl + "/v1";
    }
    url += "/chat/completions";

    const data = JSON.stringify({
        "model": model,
        "messages": [{"role": "user", "content": "hi"}],
        "max_tokens": 1
    });

    const xhr = new XMLHttpRequest();
    xhr.open("POST", url, true);
    xhr.setRequestHeader("Content-Type", "application/json");
    if (token) {
        xhr.setRequestHeader("Authorization", "Bearer " + token);
    }

    if (extraHeaders) {
        const keys = Object.keys(extraHeaders);
        for (let i = 0; i < keys.length; i++) {
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
                    const statusText = _mapErrorStatus(xhr.status, xhr.statusText);
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
