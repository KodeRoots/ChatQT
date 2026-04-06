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

// Session cache: stores session ID for the current conversation
var currentSessionId = null;

/**
 * Reset session state (call when starting a new chat)
 */
function resetSession() {
    currentSessionId = null;
}

/**
 * Build HTTP Basic Auth header value
 * @param {string} username - OpenCode username
 * @param {string} password - OpenCode password
 * @returns {string} Base64-encoded Basic Auth header
 */
function buildBasicAuth(username, password) {
    var credentials = username + ":" + password;
    return "Basic " + Qt.btoa(credentials);
}

/**
 * Create a new session
 * @param {string} baseUrl - OpenCode server URL
 * @param {string} username - Authentication username
 * @param {string} password - Authentication password
 * @param {function} onSuccess - Callback(sessionId) on success
 * @param {function} onError - Callback(status, message) on error
 */
function createSession(baseUrl, username, password, onSuccess, onError) {
    var url = baseUrl.replace(/\/$/, '') + "/session";
    
    var xhr = new XMLHttpRequest();
    xhr.open("POST", url, true);
    xhr.setRequestHeader("Content-Type", "application/json");
    xhr.setRequestHeader("Authorization", buildBasicAuth(username, password));
    
    xhr.onreadystatechange = function() {
        if (xhr.readyState === XMLHttpRequest.DONE) {
            if (xhr.status === 200 || xhr.status === 201) {
                try {
                    var response = JSON.parse(xhr.responseText);
                    var sessionId = response.id;
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

/**
 * Extract text content from OpenCode response parts
 * @param {Array} parts - Array of part objects
 * @returns {string} Combined text from all text parts
 */
function extractTextFromParts(parts) {
    var text = "";
    if (!parts || !Array.isArray(parts)) return text;
    
    for (var i = 0; i < parts.length; i++) {
        var part = parts[i];
        if (part.type === "text" && part.text) {
            text += part.text;
        }
    }
    return text;
}

/**
 * Send a chat request to OpenCode
 * @param {string} baseUrl - OpenCode server URL
 * @param {string} username - Authentication username
 * @param {string} password - Authentication password
 * @param {string} model - Model identifier (not currently used by OpenCode)
 * @param {Array} promptArray - Conversation history (we only use the last message)
 * @param {Object} listModel - QML ListModel for messages
 * @param {function} onStreaming - Callback for streaming updates
 * @param {function} onComplete - Callback when request completes
 */
function requestOpenCode(baseUrl, username, password, model, promptArray, listModel, onStreaming, onComplete) {
    var oldLength = listModel.count;
    
    // Get the last user message
    var lastMessage = "";
    for (var i = promptArray.length - 1; i >= 0; i--) {
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
    
    // Function to send message to session
    var sendMessage = function(sessionId) {
        var url = baseUrl.replace(/\/$/, '') + "/session/" + sessionId + "/message";
        
        var requestData = {
            parts: [{
                type: "text",
                text: lastMessage
            }]
        };
        
        var xhr = new XMLHttpRequest();
        _activeXhr = xhr;
        xhr.open("POST", url, true);
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.setRequestHeader("Authorization", buildBasicAuth(username, password));
        
        var text = "";
        
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.LOADING || xhr.readyState === XMLHttpRequest.DONE) {
                try {
                    var response = JSON.parse(xhr.responseText);
                    if (response.parts) {
                        var newText = extractTextFromParts(response.parts);
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
    
    // Create session if needed, then send message
    if (!currentSessionId) {
        var sessionXhr = createSession(baseUrl, username, password, sendMessage, function(status, message) {
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