/*
    SPDX-FileCopyrightText: 2026 Denys Madureira <denys@koderoots.org>
    SPDX-License-Identifier: LGPL-2.1-or-later
*/

.pragma library

function discoverSkills(folders) {
    if (!folders || folders.length === 0) {
        return [];
    }

    var folderList = [];
    if (typeof folders === "string") {
        try {
            folderList = JSON.parse(folders);
        } catch (e) {
            return [];
        }
    } else {
        folderList = folders;
    }

    var result = SkillScanner.discoverSkills(folderList);
    if (typeof result === "string") {
        try {
            return JSON.parse(result);
        } catch (e) {
            return [];
        }
    }

    if (result instanceof Array) {
        return result;
    }

    try {
        return Array.from(result);
    } catch (e) {
        return [];
    }
}

function readAgentFile(filePath) {
    if (!filePath || filePath === "") {
        return "";
    }
    return SkillScanner.readFile(filePath);
}

function buildSystemMessage(skills, agentContent) {
    return SkillScanner.buildSystemMessage(skills, agentContent || "");
}
