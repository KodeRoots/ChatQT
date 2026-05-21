/*
    SPDX-FileCopyrightText: 2024 Denys Madureira <denysmb@zoho.com>
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

var currentSessionId = null;

function resetSession() {
    currentSessionId = null;
}

function buildBasicAuth(username, password) {
    const credentials = username + ":" + password;
    return "Basic " + Qt.btoa(credentials);
}

function createSession(baseUrl, username, password, onSuccess, onError) {
    const url = baseUrl.replace(/\/$/, '') + "/session";
    
    const xhr = new XMLHttpRequest();
    xhr.open("POST", url, true);
    xhr.setRequestHeader("Content-Type", "application/json");
    xhr.setRequestHeader("Authorization", buildBasicAuth(username, password));
    
    xhr.onreadystatechange = function() {
        if (xhr.readyState === XMLHttpRequest.DONE) {
            if (xhr.status === 200 || xhr.status === 201) {
                try {
                    const response = JSON.parse(xhr.responseText);
                    const sessionId = response.id;
                    if (sessionId) {
                        currentSessionId = sessionId;
                        if (typeof onSuccess === "function") {
                            onSuccess(sessionId);
                        }
                    } else {
                        if (typeof onError === "function") {
                            onError(xhr.status, "No session ID in response");
                        }
                    }
                } catch (e) {
                    if (typeof onError === "function") {
                        onError(xhr.status, "Invalid JSON response: " + e.message);
                    }
                }
            } else {
                if (typeof onError === "function") {
                    onError(xhr.status, xhr.statusText || "Failed to create session");
                }
            }
        }
    };
    
    xhr.onerror = function() {
        if (typeof onError === "function") {
            onError(0, "Network error");
        }
    };
    
    _activeXhr = xhr;
    xhr.send(JSON.stringify({}));
    return xhr;
}

function extractTextFromParts(parts) {
    let text = "";
    if (!parts || !Array.isArray(parts)) return text;
    
    for (let i = 0; i < parts.length; i++) {
        const part = parts[i];
        if (part.type === "text" && part.text) {
            text += part.text;
        }
    }
    return text;
}

function requestOpenCode(baseUrl, username, password, model, promptArray, listModel, onStreaming, onComplete) {
    const oldLength = listModel.count;
    
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
    
    const sendMessage = function(sessionId) {
        const url = baseUrl.replace(/\/$/, '') + "/session/" + sessionId + "/message";
        
        const requestData = {
            parts: [{
                type: "text",
                text: lastMessage
            }]
        };
        
        const xhr = new XMLHttpRequest();
        _activeXhr = xhr;
        xhr.open("POST", url, true);
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.setRequestHeader("Authorization", buildBasicAuth(username, password));
        
        let text = "";
        
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.LOADING || xhr.readyState === XMLHttpRequest.DONE) {
                try {
                    const response = JSON.parse(xhr.responseText);
                    if (response.parts) {
                        const newText = extractTextFromParts(response.parts);
                        if (newText !== text) {
                            text = newText;
                            if (typeof onStreaming === "function") {
                                onStreaming(text, oldLength, listModel);
                            }
                        }
                    }
                } catch (e) {
                    // Response not complete yet, ignore
                }
            }
            
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (typeof onComplete === "function") {
                    onComplete(oldLength, listModel);
                }
            }
        };
        
        xhr.onerror = function() {
            console.error("OpenCode request failed");
            if (typeof onComplete === "function") {
                onComplete(oldLength, listModel);
            }
        };
        
        xhr.send(JSON.stringify(requestData));
        return xhr;
    };
    
    if (!currentSessionId) {
        const sessionXhr = createSession(baseUrl, username, password, sendMessage, function(status, message) {
            console.error("OpenCode: Failed to create session:", status, message);
            if (typeof onComplete === "function") {
                onComplete(oldLength, listModel);
            }
        });
        return sessionXhr;
    } else {
        return sendMessage(currentSessionId);
    }
}
