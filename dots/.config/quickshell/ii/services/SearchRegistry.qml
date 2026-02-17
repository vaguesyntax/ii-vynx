pragma Singleton

import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property list<var> sections: []

    property string currentSearch: ""
    onCurrentSearchChanged: {
        console.log("Current found search result string:", currentSearch)
    }

    function startIndexing() {
        sections = []
        pageFile.start([
            Directories.generalConfigPath,
            Directories.barConfigPath,
            Directories.backgroundConfigPath,
            Directories.interfaceConfigPath,
            Directories.servicesConfigPath,
            Directories.advancedConfigPath
        ])
    }

    Component.onCompleted: startIndexing()

    Connections {
        target: Translation
        function onLanguageCodeChanged() {
            startIndexing()
        }
    }

    FileView {
        id: pageFile
        blockLoading: true

        property var files: []
        property int currentIndex: 0

        function start(filesArray) {
            files = filesArray
            currentIndex = 0
            loadNext()
        }

        function loadNext() {
            if (currentIndex >= files.length)
                return

            path = files[currentIndex]
        }

        onLoaded: {
            root.indexQmlFile(text())

            currentIndex++

            Qt.callLater(() => loadNext())
        }
    }


    // Fetches the needed string like text, title from the qml file

    function indexQmlFile(qmlText) {
        if (!qmlText)
            return

        let sections = extractBlocks(qmlText, "ContentSection")

        for (let sectionBlock of sections) {

            let title = extractProperty(sectionBlock, "title")

            let searchStrings = []
            if (title)
                searchStrings.push(title)

            // subsections
            let subsections = extractBlocks(sectionBlock, "ContentSubsection")
            for (let subBlock of subsections) {
                let subTitle = extractProperty(subBlock, "title")
                if (subTitle)
                    searchStrings.push(subTitle)
            }

            // switches
            let switches = extractBlocks(sectionBlock, "ConfigSwitch")
            for (let swBlock of switches) {
                let text = extractProperty(swBlock, "text")
                if (text)
                    searchStrings.push(text)
            }

            // spinbox
            let spins = extractBlocks(sectionBlock, "ConfigSpinBox")
            for (let spBlock of spins) {
                let text = extractProperty(spBlock, "text")
                if (text)
                    searchStrings.push(text)
            }

            //console.log("[SearchRegistry] Indexed:", title, searchStrings)

            let pageIndex = extractPageIndex(qmlText)

            registerSection({
                pageIndex: pageIndex,
                title: title || "Unknown",
                searchStrings: searchStrings
            })
        }

        console.log("[SearchRegistry] Indexed", sections.length, "sections", "| Language:", Translation.languageCode)
    }

    // Helper function for indexQmlFile(), extracts blocks from the qml file

    function extractBlocks(text, type) {
        let results = []
        let i = 0

        while (i < text.length) {
            let index = text.indexOf(type, i)
            if (index === -1)
                break

            let braceStart = text.indexOf("{", index)
            if (braceStart === -1)
                break

            let depth = 1
            let j = braceStart + 1
            let inString = false
            let stringChar = ""

            while (j < text.length && depth > 0) {
                let ch = text[j]

                if (!inString && (ch === '"' || ch === "'")) {
                    inString = true
                    stringChar = ch
                } else if (inString && ch === stringChar) {
                    inString = false
                } else if (!inString) {
                    if (ch === "{") depth++
                    else if (ch === "}") depth--
                }

                j++
            }

            let block = text.substring(braceStart + 1, j - 1)
            results.push(block)

            i = j
        }

        return results
    }

    // Helper function for indexQmlFile(), extracts properties from the qml file

    function extractProperty(block, prop) {
        let m

        // Translation.tr("") or Translation.tr('')
        m = block.match(new RegExp(prop + "\\s*:\\s*Translation\\.tr\\(\\s*[\"']([^\"']+)[\"']\\s*\\)"))
        if (m) return m[1]

        // ""
        m = block.match(new RegExp(prop + "\\s*:\\s*\"([^\"]+)\""))
        if (m) return m[1]

        // ''
        m = block.match(new RegExp(prop + "\\s*:\\s*'([^']+)'"))
        if (m) return m[1]

        return ""
    }

    // Helper function for indexQmlFile(), extracts the page index
    
    function extractPageIndex(qmlText) {
        let m = qmlText.match(/readonly\s+property\s+int\s+index\s*:\s*(\d+)/)
        return m ? parseInt(m[1]) : -1
    }

    function tokenize(text) {
        if (!text || typeof text !== "string")
            return []

        return text
            .toLowerCase()
            .replace(/[^a-z0-9\sğüşöçıİ_\-\.]/g, " ")
            .split(/[\s_\-\.]+/)
            .filter(function(t) { return t.length > 1 })
    }

    function fuzzyMatch(word, query) {
        let wi = 0
        let qi = 0
        let score = 0

        word = word.toLowerCase()
        query = query.toLowerCase()

        while (wi < word.length && qi < query.length) {
            if (word[wi] === query[qi]) {
                score += 10
                qi++
            }
            wi++
        }

        if (qi === query.length)
            return score

        return 0
    }

    function registerSection(data) {
        const titleKey = data.title
        const searchStringsKeys = [...data.searchStrings]

        // Apply translations
        data.title = Translation.tr(titleKey)
        data.searchStrings = searchStringsKeys.map(s => Translation.tr(s))

        let combined = (titleKey + " " + searchStringsKeys.join(" ") + " " + data.title + " " + data.searchStrings.join(" ")).toLowerCase()
        
        data._tokens = tokenize(combined)
        data._searchText = combined
        
        sections.push(data)
        
        // console.log("[SearchRegistry] Registered section:", data.title, "with strings:", data.searchStrings)
    }

    function getBestResult(text) {
        let results = getSearchResult(text)
        if (results.length === 0)
            return null

        results.sort((a, b) => b.score - a.score)
        return results[0]
    }

    function getResultsRanked(text) {
        let results = getSearchResult(text)
        results.sort((a, b) => b.score - a.score)
        return results
    }

    function getSearchResult(query) {
        if (!query || query.trim() === "") return []

        query = query.toLowerCase().trim()
        let queryTokens = tokenize(query)
        let results = []

        for (let section of sections) {
            let totalScore = 0
            let bestMatch = "" 
            let bestMatchScore = 0
            let bestMatchSource = "" 
            
            // direct match in title
            if (section.title.toLowerCase().includes(query)) {
                totalScore += 1000
                if (bestMatchScore < 1000) {
                    bestMatch = section.title
                    bestMatchSource = section.title
                    bestMatchScore = 1000
                }
            }
            
            // direct match in searchStrings
            for (let searchStr of section.searchStrings) {
                let lowerStr = searchStr.toLowerCase()
                if (lowerStr.includes(query)) {
                    let score = lowerStr === query ? 800 : 500
                    totalScore += score
                    if (score > bestMatchScore) {
                        bestMatch = searchStr
                        bestMatchSource = searchStr
                        bestMatchScore = score
                    }
                }
            }
            
            for (let searchStr of section.searchStrings) {
                let searchStrLower = searchStr.toLowerCase()
                let searchTokens = tokenize(searchStrLower)
                let matchedTokenCount = 0
                let tokenScore = 0
                
                for (let qToken of queryTokens) {
                    for (let sToken of searchTokens) {
                        let score = 0
                        if (sToken.startsWith(qToken)) {
                            score = 200
                            matchedTokenCount++
                        } else if (sToken.includes(qToken)) {
                            score = 100
                            matchedTokenCount++
                        } else {
                            let fuzzyScore = fuzzyMatch(sToken, qToken)
                            if (fuzzyScore > 0) {
                                score = fuzzyScore
                                matchedTokenCount++
                            }
                        }
                        
                        if (score > 0) {
                            tokenScore += score
                        }
                    }
                }
                
                if (tokenScore > 0) {
                    totalScore += tokenScore
                    if (tokenScore > bestMatchScore && matchedTokenCount > 0) {
                        bestMatch = searchStr
                        bestMatchSource = searchStr
                        bestMatchScore = tokenScore
                    }
                }
            }
            
            if (totalScore > 0) {
                results.push({
                    pageIndex: section.pageIndex,
                    title: section.title,
                    keyword: section._searchText,
                    matchedString: bestMatch || section.title,
                    yPos: section.yPos,
                    score: totalScore
                })
            }
        }
        
        return results
    }

    function scoreResult(result, text) {
        return result.score
    }

    // Debug
    function listAllSections() {
        console.log("=== Registered Sections ===")
        for (let i = 0; i < sections.length; i++) {
            console.log(i + ":", sections[i].title, "tokens:", sections[i]._tokens)
        }
    }
}