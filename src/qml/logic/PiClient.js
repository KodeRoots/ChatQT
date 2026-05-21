/*
    SPDX-FileCopyrightText: 2026 Denys Madureira <denys@koderoots.org>
    SPDX-License-Identifier: LGPL-2.1-or-later
*/

.pragma library

var _isRequesting = false;
var _processManager = null;

function abortActiveRequest() {
    if (_isRequesting && _processManager) {
        _processManager.sendCommand(JSON.stringify({"type": "abort"}));
    }
    _isRequesting = false;
    return true;
}

function requestPi(processManager, promptArray, listModel, onStreaming, onComplete) {
    const oldLength = listModel.count;

    _processManager = processManager;

    let lastMessage = "";
    for (let i = promptArray.length - 1; i >= 0; i--) {
        if (promptArray[i].role === "user") {
            lastMessage = promptArray[i].content;
            break;
        }
    }

    if (!lastMessage) {
        if (typeof onComplete === "function") {
            onComplete(oldLength, listModel);
        }
        return;
    }

    if (!processManager.running) {
        if (typeof onComplete === "function") {
            onComplete(oldLength, listModel);
        }
        return;
    }

    _isRequesting = true;

    let text = "";
    let thinkingText = "";
    let currentToolCalls = [];

    function handleEvent(jsonLine) {
        let event;
        try {
            event = JSON.parse(jsonLine);
        } catch (e) {
            return;
        }

        if (event.type === "message_update") {
            const delta = event.assistantMessageEvent;
            if (!delta) return;

            if (delta.type === "text_delta") {
                text += delta.delta;
                if (typeof onStreaming === "function") {
                    onStreaming(text, oldLength, listModel, thinkingText);
                }
            } else if (delta.type === "thinking_delta") {
                thinkingText += delta.delta;
                if (typeof onStreaming === "function") {
                    onStreaming(text, oldLength, listModel, thinkingText);
                }
            } else if (delta.type === "toolcall_start") {
                const tc = {
                    id: "",
                    type: "function",
                    function: {
                        name: "",
                        arguments: ""
                    }
                };
                if (delta.toolCall) {
                    tc.id = delta.toolCall.id || "";
                    tc.function.name = delta.toolCall.name || "";
                }
                currentToolCalls.push(tc);
            } else if (delta.type === "toolcall_delta") {
                if (currentToolCalls.length > 0) {
                    currentToolCalls[currentToolCalls.length - 1].function.arguments += (delta.delta || "");
                }
            } else if (delta.type === "toolcall_end") {
                if (delta.toolCall) {
                    let found = false;
                    for (let t = 0; t < currentToolCalls.length; t++) {
                        if (currentToolCalls[t].id === delta.toolCall.id) {
                            currentToolCalls[t].function.name = delta.toolCall.name || currentToolCalls[t].function.name;
                            if (delta.toolCall.arguments) {
                                currentToolCalls[t].function.arguments = typeof delta.toolCall.arguments === "string"
                                    ? delta.toolCall.arguments
                                    : JSON.stringify(delta.toolCall.arguments);
                            }
                            found = true;
                            break;
                        }
                    }
                    if (!found) {
                        const newTc = {
                            id: delta.toolCall.id || "",
                            type: "function",
                            function: {
                                name: delta.toolCall.name || "",
                                arguments: typeof delta.toolCall.arguments === "string"
                                    ? delta.toolCall.arguments
                                    : JSON.stringify(delta.toolCall.arguments || {})
                            }
                        };
                        currentToolCalls.push(newTc);
                    }
                }
            } else if (delta.type === "done") {
                // message complete
            }
        } else if (event.type === "agent_end") {
            cleanup();
            const finalToolCalls = currentToolCalls.length > 0 ? currentToolCalls : undefined;
            if (typeof onComplete === "function") {
                onComplete(oldLength, listModel, text, finalToolCalls);
            }
        } else if (event.type === "response") {
            if (!event.success && event.command === "prompt") {
                cleanup();
                if (typeof onComplete === "function") {
                    onComplete(oldLength, listModel);
                }
            }
        }
    }

    const eventHandler = (jsonLine) => {
        handleEvent(jsonLine);
    };

    processManager.eventReceived.connect(eventHandler);

    function cleanup() {
        _isRequesting = false;
        processManager.eventReceived.disconnect(eventHandler);
    }

    const promptCommand = JSON.stringify({
        "type": "prompt",
        "message": lastMessage
    });

    processManager.sendCommand(promptCommand);

    return true;
}
