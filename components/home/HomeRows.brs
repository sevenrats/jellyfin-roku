sub init()
    m.top.itemComponentName = "HomeItem"
    ' how many rows are visible on the screen
    m.top.numRows = 2

    m.top.rowFocusAnimationStyle = "fixedFocusWrap"
    m.top.vertFocusAnimationStyle = "fixedFocus"

    m.top.showRowLabel = [true]
    m.top.rowLabelOffset = [0, 20]
    m.top.showRowCounter = [true]

    updateSize()

    m.top.setfocus(true)

    m.top.observeField("rowItemSelected", "itemSelected")

    ' Load the Libraries from API via task
    m.LoadLibrariesTask = createObject("roSGNode", "LoadItemsTask")
    m.LoadLibrariesTask.observeField("content", "onLibrariesLoaded")

    ' set up tesk nodes for other rows
    m.LoadContinueTask = createObject("roSGNode", "LoadItemsTask")
    m.LoadContinueTask.itemsToLoad = "continue"

    m.LoadNextUpTask = createObject("roSGNode", "LoadItemsTask")
    m.LoadNextUpTask.itemsToLoad = "nextUp"

    m.LoadOnNowTask = createObject("roSGNode", "LoadItemsTask")
    m.LoadOnNowTask.itemsToLoad = "onNow"

    m.LoadFavoritesTask = createObject("roSGNode", "LoadItemsTask")
    m.LoadFavoritesTask.itemsToLoad = "favorites"
end sub

sub loadLibraries()
    m.LoadLibrariesTask.control = "RUN"
end sub

sub updateSize()
    m.top.translation = [111, 180]
    itemHeight = 330

    'Set width of Rows to cut off at edge of Safe Zone
    m.top.itemSize = [1703, itemHeight]

    ' spacing between rows
    m.top.itemSpacing = [0, 105]

    ' spacing between items in a row
    m.top.rowItemSpacing = [20, 0]

    m.top.visible = true
end sub

sub onLibrariesLoaded()
    ' save data for other functions
    m.libraryData = m.LoadLibrariesTask.content
    m.LoadLibrariesTask.unobserveField("content")
    m.LoadLibrariesTask.content = []
    ' create My Media, Continue Watching, and Next Up rows
    content = CreateObject("roSGNode", "ContentNode")

    mediaRow = content.CreateChild("HomeRow")
    mediaRow.title = tr("My Media")

    continueRow = content.CreateChild("HomeRow")
    continueRow.title = tr("Continue Watching")

    nextUpRow = content.CreateChild("HomeRow")
    nextUpRow.title = tr("Next Up >")

    favoritesRow = content.CreateChild("HomeRow")
    favoritesRow.title = tr("Favorites")

    sizeArray = [
        [464, 311], ' My Media
        [464, 331], ' Continue Watching
        [464, 331], ' Next Up
        [464, 331] ' Favorites
    ]

    haveLiveTV = false

    ' Load the NextUp Data
    m.LoadNextUpTask.observeField("content", "updateNextUpItems")
    m.LoadNextUpTask.control = "RUN"

    ' Load the Continue Watching Data
    m.LoadContinueTask.observeField("content", "updateContinueItems")
    m.LoadContinueTask.control = "RUN"

    ' Load the Favorites Data
    m.LoadFavoritesTask.observeField("content", "updateFavoritesItems")
    m.LoadFavoritesTask.control = "RUN"

    ' validate library data
    if m.libraryData <> invalid and m.libraryData.count() > 0
        userConfig = m.top.userConfig

        ' populate My Media row
        filteredMedia = filterNodeArray(m.libraryData, "id", userConfig.MyMediaExcludes)
        for each item in filteredMedia
            mediaRow.appendChild(item)
        end for

        ' create a "Latest In" row for each library
        filteredLatest = filterNodeArray(m.libraryData, "id", userConfig.LatestItemsExcludes)
        for each lib in filteredLatest
            if lib.collectionType <> "boxsets" and lib.collectionType <> "livetv" and lib.json.CollectionType <> "Program"
                latestInRow = content.CreateChild("HomeRow")
                latestInRow.title = tr("Latest in") + " " + lib.name + " >"
                sizeArray.Push([464, 331])

                loadLatest = createObject("roSGNode", "LoadItemsTask")
                loadLatest.itemsToLoad = "latest"
                loadLatest.itemId = lib.id

                metadata = { "title": lib.name }
                metadata.Append({ "contentType": lib.json.CollectionType })
                loadLatest.metadata = metadata

                loadLatest.observeField("content", "updateLatestItems")
                loadLatest.control = "RUN"
            else if lib.collectionType = "livetv"
                ' If we have Live TV, add "On Now"
                onNowRow = content.CreateChild("HomeRow")
                onNowRow.title = tr("On Now")
                sizeArray.Push([464, 331])
                haveLiveTV = true
                ' If we have Live TV access, load "On Now" data
                if haveLiveTV
                    m.LoadOnNowTask.observeField("content", "updateOnNowItems")
                    m.LoadOnNowTask.control = "RUN"
                end if
            end if
        end for
    end if

    m.top.rowItemSize = sizeArray
    m.top.content = content
end sub

sub updateHomeRows()
    if m.global.playstateTask.state = "run"
        m.global.playstateTask.observeField("state", "updateHomeRows")
    else
        m.global.playstateTask.unobserveField("state")
    end if
    m.LoadContinueTask.observeField("content", "updateContinueItems")
    m.LoadContinueTask.control = "RUN"
end sub

sub updateFavoritesItems()
    itemData = m.LoadFavoritesTask.content
    m.LoadFavoritesTask.unobserveField("content")
    m.LoadFavoritesTask.content = []

    if itemData = invalid then return

    homeRows = m.top.content
    rowIndex = getRowIndex("Favorites")

    if itemData.count() < 1
        if rowIndex <> invalid
            ' remove the row
            deleteFromSizeArray(rowIndex)
            homeRows.removeChildIndex(rowIndex)
        end if
    else
        ' remake row using the new data
        row = CreateObject("roSGNode", "HomeRow")
        row.title = tr("Favorites")
        itemSize = [464, 331]

        for each item in itemData
            usePoster = true

            if lcase(item.type) = "episode" or lcase(item.type) = "audio" or lcase(item.type) = "musicartist"
                usePoster = false
            end if

            item.usePoster = usePoster
            item.imageWidth = row.imageWidth
            row.appendChild(item)
        end for

        if rowIndex = invalid
            ' insert new row under "My Media"
            updateSizeArray(itemSize, 1)
            homeRows.insertChild(row, 1)
        else
            ' replace the old row
            homeRows.replaceChild(row, rowIndex)
        end if
    end if
end sub

sub updateContinueItems()
    itemData = m.LoadContinueTask.content
    m.LoadContinueTask.unobserveField("content")
    m.LoadContinueTask.content = []

    if itemData = invalid then return

    homeRows = m.top.content
    continueRowIndex = getRowIndex("Continue Watching")

    if itemData.count() < 1
        if continueRowIndex <> invalid
            ' remove the row
            deleteFromSizeArray(continueRowIndex)
            homeRows.removeChildIndex(continueRowIndex)
        end if
    else
        ' remake row using the new data
        row = CreateObject("roSGNode", "HomeRow")
        row.title = tr("Continue Watching")
        itemSize = [464, 331]
        for each item in itemData
            if item.json?.UserData?.PlayedPercentage <> invalid
                item.PlayedPercentage = item.json.UserData.PlayedPercentage
            end if

            item.usePoster = row.usePoster
            item.imageWidth = row.imageWidth
            row.appendChild(item)
        end for

        if continueRowIndex = invalid
            ' insert new row under "My Media"
            updateSizeArray(itemSize, 1)
            homeRows.insertChild(row, 1)
        else
            ' replace the old row
            homeRows.replaceChild(row, continueRowIndex)
        end if
    end if
end sub

sub updateNextUpItems()
    itemData = m.LoadNextUpTask.content
    m.LoadNextUpTask.unobserveField("content")
    m.LoadNextUpTask.content = []

    if itemData = invalid then return

    homeRows = m.top.content
    nextUpRowIndex = getRowIndex("Next Up >")

    if itemData.count() < 1
        if nextUpRowIndex <> invalid
            ' remove the row
            deleteFromSizeArray(nextUpRowIndex)
            homeRows.removeChildIndex(nextUpRowIndex)
        end if
    else
        ' remake row using the new data
        row = CreateObject("roSGNode", "HomeRow")
        row.title = tr("Next Up") + " >"
        itemSize = [464, 331]
        for each item in itemData
            item.usePoster = row.usePoster
            item.imageWidth = row.imageWidth
            row.appendChild(item)
        end for

        if nextUpRowIndex = invalid
            ' insert new row under "Continue Watching"
            continueRowIndex = getRowIndex("Continue Watching")
            if continueRowIndex <> invalid
                updateSizeArray(itemSize, continueRowIndex + 1)
                homeRows.insertChild(row, continueRowIndex + 1)
            else
                ' insert it under My Media
                updateSizeArray(itemSize, 1)
                homeRows.insertChild(row, 1)
            end if
        else
            ' replace the old row
            homeRows.replaceChild(row, nextUpRowIndex)
        end if
    end if

    ' consider home screen loaded when above rows are loaded
    if m.global.app_loaded = false
        m.top.signalBeacon("AppLaunchComplete") ' Roku Performance monitoring
        m.global.app_loaded = true
    end if

end sub

sub updateLatestItems(msg)
    itemData = msg.GetData()

    node = msg.getRoSGNode()
    node.unobserveField("content")
    node.content = []

    if itemData = invalid then return

    homeRows = m.top.content
    rowIndex = getRowIndex(tr("Latest in") + " " + node.metadata.title + " >")

    if itemData.count() < 1
        ' remove row
        if rowIndex <> invalid
            deleteFromSizeArray(rowIndex)
            homeRows.removeChildIndex(rowIndex)
        end if
    else
        ' remake row using new data
        row = CreateObject("roSGNode", "HomeRow")
        row.title = tr("Latest in") + " " + node.metadata.title + " >"
        row.usePoster = true
        ' Handle specific types with different item widths
        if node.metadata.contentType = "movies"
            row.imageWidth = 180
            itemSize = [188, 331]
        else if node.metadata.contentType = "music"
            row.imageWidth = 261
            itemSize = [261, 331]
        else
            row.imageWidth = 464
            itemSize = [464, 331]
        end if

        for each item in itemData
            item.usePoster = row.usePoster
            item.imageWidth = row.imageWidth
            row.appendChild(item)
        end for

        if rowIndex = invalid
            ' append new row
            updateSizeArray(itemSize)
            homeRows.appendChild(row)
        else
            ' replace the old row
            updateSizeArray(itemSize, rowIndex, "replace")
            homeRows.replaceChild(row, rowIndex)
        end if
    end if
end sub

sub updateOnNowItems()
    itemData = m.LoadOnNowTask.content
    m.LoadOnNowTask.unobserveField("content")
    m.LoadOnNowTask.content = []

    if itemData = invalid then return

    homeRows = m.top.content
    onNowRowIndex = getRowIndex("On Now")

    if itemData.count() < 1
        if onNowRowIndex <> invalid
            ' remove the row
            deleteFromSizeArray(onNowRowIndex)
            homeRows.removeChildIndex(onNowRowIndex)
        end if
    else
        ' remake row using the new data
        row = CreateObject("roSGNode", "HomeRow")
        row.title = tr("On Now")
        itemSize = [464, 331]
        for each item in itemData
            item.usePoster = row.usePoster
            item.imageWidth = row.imageWidth
            row.appendChild(item)
        end for

        if onNowRowIndex = invalid
            ' insert new row under "My Media"
            updateSizeArray(itemSize, 1)
            homeRows.insertChild(row, 1)
        else
            ' replace the old row
            homeRows.replaceChild(row, onNowRowIndex)
        end if
    end if
end sub

function getRowIndex(rowTitle as string)
    rowIndex = invalid
    for i = 1 to m.top.content.getChildCount() - 1
        ' skip row 0 since it's always "My Media"
        tmpRow = m.top.content.getChild(i)
        if tmpRow.title = rowTitle
            rowIndex = i
            exit for
        end if
    end for
    return rowIndex
end function

sub updateSizeArray(rowItemSize, rowIndex = invalid, action = "insert")
    sizeArray = m.top.rowItemSize
    ' append by default
    if rowIndex = invalid
        rowIndex = sizeArray.count()
    end if

    newSizeArray = []
    for i = 0 to sizeArray.count()
        if rowIndex = i
            if action = "replace"
                newSizeArray.Push(rowItemSize)
            else if action = "insert"
                newSizeArray.Push(rowItemSize)
                if sizeArray[i] <> invalid
                    newSizeArray.Push(sizeArray[i])
                end if
            end if
        else if sizeArray[i] <> invalid
            newSizeArray.Push(sizeArray[i])
        end if
    end for
    m.top.rowItemSize = newSizeArray
end sub

sub deleteFromSizeArray(rowIndex)
    updateSizeArray([0, 0], rowIndex, "delete")
end sub

sub itemSelected()
    m.top.selectedItem = m.top.content.getChild(m.top.rowItemSelected[0]).getChild(m.top.rowItemSelected[1])
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    handled = false
    if press
        if key = "play"
            itemToPlay = m.top.content.getChild(m.top.rowItemFocused[0]).getChild(m.top.rowItemFocused[1])
            if itemToPlay <> invalid and (itemToPlay.type = "Movie" or itemToPlay.type = "Episode")
                m.top.quickPlayNode = itemToPlay
            end if
            handled = true
        end if

        if key = "replay"
            m.top.jumpToRowItem = [m.top.rowItemFocused[0], 0]
        end if
    end if
    return handled
end function

function filterNodeArray(nodeArray as object, nodeKey as string, excludeArray as object) as object
    if excludeArray.IsEmpty() then return nodeArray

    newNodeArray = []
    for each node in nodeArray
        excludeThisNode = false
        for each exclude in excludeArray
            if node[nodeKey] = exclude
                excludeThisNode = true
            end if
        end for
        if excludeThisNode = false
            newNodeArray.Push(node)
        end if
    end for
    return newNodeArray
end function
