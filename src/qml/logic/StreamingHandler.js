/*
    SPDX-FileCopyrightText: 2026 Denys Madureira <denys@koderoots.org>
    SPDX-License-Identifier: LGPL-2.1-or-later
*/

.pragma library

const OLLAMA = "ollama";

function handleStreaming(text, oldLength, listModel, thinkingText, sessionId, deps) {
    const { currentSessionId, disableAutoScroll, listView, SessionStore, setIsStreaming } = deps;
    const isActiveSession = sessionId === currentSessionId;

    setIsStreaming(isActiveSession);

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
            SessionStore.addMessage(sessionId, "assistant", text, thinkingText !== undefined ? thinkingText : "");
        } else {
            listModel.setProperty(oldLength, "content", text);
            if (thinkingText !== undefined) {
                listModel.setProperty(oldLength, "thinkingContent", thinkingText);
            }
        }
    } else {
        if (SessionStore.getLastMessage(sessionId).role !== "assistant") {
            SessionStore.addMessage(sessionId, "assistant", text, thinkingText !== undefined ? thinkingText : "");
        } else {
            SessionStore.updateLastAssistantMessage(sessionId, text, thinkingText !== undefined ? thinkingText : "");
        }
    }
}

function handleRequestComplete(oldLength, listModel, finalText, toolCalls, capturedSessionId, deps) {
    const { activeXhr, currentSessionId, currentProvider, setIsLoading, setIsStreaming,
            setActiveXhr, setStreamingSessionId, sessionPromptArrays, promptArray,
            SessionStore, refreshSessionList, updateSessionLoadingState,
            getToolCallDepth, resetToolCallDepth, maxToolCallDepth,
            handleMcpToolCallsWrapper } = deps;

    if (activeXhr === null && getToolCallDepth() === 0 && !capturedSessionId) return;

    const sessionId = capturedSessionId || currentSessionId;
    const isActiveSession = sessionId === currentSessionId;

    const isOllamaError = currentProvider === OLLAMA && finalText && (
        finalText.indexOf("does not support") !== -1 ||
        finalText.indexOf("Ollama error") !== -1 ||
        finalText.startsWith("{\"error\"")
    );

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
            setIsLoading(false);
            setIsStreaming(false);
        }
        setActiveXhr(null);
        resetToolCallDepth();
        setStreamingSessionId("");
        updateSessionLoadingState(sessionId, false);
        return;
    }

    const toolCallDepth = getToolCallDepth();
    if (toolCalls && toolCalls.length > 0 && toolCallDepth < maxToolCallDepth) {
        handleMcpToolCallsWrapper(oldLength, listModel, finalText, toolCalls, sessionId);
        return;
    }

    if (toolCalls && toolCalls.length > 0 && toolCallDepth >= maxToolCallDepth) {
        console.warn("MCP tool call depth limit reached (" + maxToolCallDepth + ")");
    }

    let sessionPA = sessionPromptArrays[sessionId] || promptArray;
    if (isActiveSession && listModel.count > oldLength) {
        const lastValue = listModel.get(oldLength);
        sessionPA.push({ "role": "assistant", "content": lastValue.content, "images": [] });
    } else if (!isActiveSession) {
        sessionPA.push({ "role": "assistant", "content": finalText || "", "images": [] });
    }
    sessionPromptArrays[sessionId] = sessionPA;

    if (sessionId !== "") {
        let finalContent = finalText || "";
        if (isActiveSession && listModel.count > oldLength) {
            const lastMsg = listModel.get(oldLength);
            finalContent = lastMsg.content;
            SessionStore.finalizeLastAssistantMessage(sessionId, finalContent, lastMsg.thinkingContent || "");
        } else {
            SessionStore.finalizeLastAssistantMessage(sessionId, finalContent, "");
        }
        refreshSessionList();
    }

    if (isActiveSession) {
        setIsLoading(false);
        setIsStreaming(false);
    }
    setActiveXhr(null);
    resetToolCallDepth();
    setStreamingSessionId("");
    updateSessionLoadingState(sessionId, false);
}
