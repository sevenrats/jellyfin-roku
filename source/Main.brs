sub Main (args as dynamic) as void

    appInfo = CreateObject("roAppInfo")

    ' The main function that runs when the application is launched.
    m.screen = CreateObject("roSGScreen")

    ' Set global constants
    setConstants()
    ' Write screen tracker for screensaver
    WriteAsciiFile("tmp:/scene.temp", "")
    MoveFile("tmp:/scene.temp", "tmp:/scene")

    m.port = CreateObject("roMessagePort")
    m.screen.setMessagePort(m.port)
    m.scene = m.screen.CreateScene("JFScene")
    m.screen.show()

    ' Set any initial Global Variables
    m.global = m.screen.getGlobalNode()

    playstateTask = CreateObject("roSGNode", "PlaystateTask")
    playstateTask.id = "playstateTask"

    sceneManager = CreateObject("roSGNode", "SceneManager")

    m.global.addFields({ app_loaded: false, playstateTask: playstateTask, sceneManager: sceneManager })
    m.global.addFields({ queueManager: CreateObject("roSGNode", "QueueManager") })

    app_start:
    ' First thing to do is validate the ability to use the API
    if not LoginFlow() then return
    sceneManager.callFunc("clearScenes")

    ' load home page
    sceneManager.currentUser = m.user.Name
    group = CreateHomeGroup()
    group.userConfig = m.user.configuration
    group.callFunc("loadLibraries")
    sceneManager.callFunc("pushScene", group)

    m.scene.observeField("exit", m.port)

    ' Only show the Whats New popup the first time a user runs a new client version.
    if appInfo.GetVersion() <> get_setting("LastRunVersion")
        ' Ensure the user hasn't disabled Whats New popups
        if get_user_setting("load.allowwhatsnew") = "true"
            set_setting("LastRunVersion", appInfo.GetVersion())
            dialog = createObject("roSGNode", "WhatsNewDialog")
            m.scene.dialog = dialog
            m.scene.dialog.observeField("buttonSelected", m.port)
        end if
    end if

    ' Handle input messages
    input = CreateObject("roInput")
    input.SetMessagePort(m.port)

    m.device = CreateObject("roDeviceInfo")
    m.device.setMessagePort(m.port)
    m.device.EnableScreensaverExitedEvent(true)
    m.device.EnableAppFocusEvent(false)

    ' Check if we were sent content to play with the startup command (Deep Link)
    if isValidAndNotEmpty(args.mediaType) and isValidAndNotEmpty(args.contentId)
        video = CreateVideoPlayerGroup(args.contentId)

        if isValid(video) and video.errorMsg <> "introaborted"
            sceneManager.callFunc("pushScene", video)
        else
            dialog = createObject("roSGNode", "Dialog")
            dialog.id = "OKDialog"
            dialog.title = tr("Not found")
            dialog.message = tr("The requested content does not exist on the server")
            dialog.buttons = [tr("OK")]
            m.scene.dialog = dialog
            m.scene.dialog.observeField("buttonSelected", m.port)
        end if
    end if

    ' This is the core logic loop. Mostly for transitioning between scenes
    ' This now only references m. fields so could be placed anywhere, in theory
    ' "group" is always "whats on the screen"
    ' m.scene's children is the "previous view" stack
    while true
        msg = wait(0, m.port)
        if type(msg) = "roSGScreenEvent" and msg.isScreenClosed()
            print "CLOSING SCREEN"
            return
        else if isNodeEvent(msg, "exit")
            return
        else if isNodeEvent(msg, "closeSidePanel")
            group = sceneManager.callFunc("getActiveScene")
            if group.lastFocus <> invalid
                group.lastFocus.setFocus(true)
            else
                group.setFocus(true)
            end if
        else if isNodeEvent(msg, "quickPlayNode")
            group = sceneManager.callFunc("getActiveScene")
            reportingNode = msg.getRoSGNode()
            itemNode = reportingNode.quickPlayNode
            if itemNode = invalid or itemNode.id = "" then return
            if itemNode.type = "Episode" or itemNode.type = "Movie" or itemNode.type = "Video"
                if itemNode.type = "Episode" and itemNode.selectedAudioStreamIndex <> invalid and itemNode.selectedAudioStreamIndex > 1
                    video = CreateVideoPlayerGroup(itemNode.id, invalid, itemNode.selectedAudioStreamIndex)
                else
                    video = CreateVideoPlayerGroup(itemNode.id)
                end if
                if video <> invalid and video.errorMsg <> "introaborted"
                    sceneManager.callFunc("pushScene", video)
                end if

                if LCase(group.subtype()) = "tvepisodes"
                    if isValid(group.lastFocus)
                        group.lastFocus.setFocus(true)
                    end if
                end if

                reportingNode.quickPlayNode.type = ""
            end if
        else if isNodeEvent(msg, "selectedItem")
            ' If you select a library from ANYWHERE, follow this flow
            selectedItem = msg.getData()
            if not isValid(selectedItem.disabledForPlayback) or not selectedItem.disabledForPlayback

                m.selectedItemType = selectedItem.type

                if selectedItem.type = "CollectionFolder"
                    if selectedItem.collectionType = "movies"
                        group = CreateMovieLibraryView(selectedItem)
                    else if selectedItem.collectionType = "music"
                        group = CreateMusicLibraryView(selectedItem)
                    else
                        group = CreateItemGrid(selectedItem)
                    end if
                    sceneManager.callFunc("pushScene", group)
                else if selectedItem.type = "Folder" and selectedItem.json.type = "Genre"
                    ' User clicked on a genre folder
                    if selectedItem.collectionType = "movies"
                        group = CreateMovieLibraryView(selectedItem)
                    else
                        group = CreateItemGrid(selectedItem)
                    end if
                    sceneManager.callFunc("pushScene", group)
                else if selectedItem.type = "Folder" and selectedItem.json.type = "MusicGenre"
                    group = CreateMusicLibraryView(selectedItem)
                    sceneManager.callFunc("pushScene", group)
                else if selectedItem.type = "UserView" or selectedItem.type = "Folder" or selectedItem.type = "Channel" or selectedItem.type = "Boxset"
                    group = CreateItemGrid(selectedItem)
                    sceneManager.callFunc("pushScene", group)
                else if selectedItem.type = "Episode"
                    if not isValid(selectedItem.disabledForPlayback) or not selectedItem.disabledForPlayback
                        ' play episode
                        ' todo: create an episode page to link here
                        video_id = selectedItem.id
                        if selectedItem.selectedAudioStreamIndex <> invalid and selectedItem.selectedAudioStreamIndex > 1
                            video = CreateVideoPlayerGroup(video_id, invalid, selectedItem.selectedAudioStreamIndex)
                        else
                            video = CreateVideoPlayerGroup(video_id)
                        end if
                        if video <> invalid and video.errorMsg <> "introaborted"
                            sceneManager.callFunc("pushScene", video)
                        end if
                    end if
                else if selectedItem.type = "Series"
                    if not isValid(selectedItem.disabledForPlayback) or not selectedItem.disabledForPlayback
                        group = CreateSeriesDetailsGroup(selectedItem.json)
                    end if
                else if selectedItem.type = "Season"
                    group = CreateSeasonDetailsGroupByID(selectedItem.json.SeriesId, selectedItem.id)
                else if selectedItem.type = "Movie"
                    ' open movie detail page
                    print "THE MOVIE"
                    print selectedItem
                    if not isValid(selectedItem.disabledForPlayback) or not selectedItem.disabledForPlayback
                        group = CreateMovieDetailsGroup(selectedItem)
                    end if
                else if selectedItem.type = "Person"
                    if not isValid(selectedItem.disabledForPlayback) or not selectedItem.disabledForPlayback
                        CreatePersonView(selectedItem)
                    end if
                else if selectedItem.type = "TvChannel" or selectedItem.type = "Video" or selectedItem.type = "Program"
                    ' play channel feed
                    video_id = selectedItem.id

                    ' Show Channel Loading spinner
                    dialog = createObject("roSGNode", "ProgressDialog")
                    dialog.title = tr("Loading Channel Data")
                    m.scene.dialog = dialog

                    if LCase(selectedItem.subtype()) = "extrasdata"
                        video = CreateVideoPlayerGroup(video_id, invalid, 1, false, true, false)
                    else
                        video = CreateVideoPlayerGroup(video_id)
                    end if

                    dialog.close = true

                    if video <> invalid and video.errorMsg <> "introaborted"
                        sceneManager.callFunc("pushScene", video)
                    else
                        dialog = createObject("roSGNode", "Dialog")
                        dialog.id = "OKDialog"
                        dialog.title = tr("Error loading Channel Data")
                        dialog.message = tr("Unable to load Channel Data from the server")
                        dialog.buttons = [tr("OK")]
                        m.scene.dialog = dialog
                        m.scene.dialog.observeField("buttonSelected", m.port)
                    end if
                else if selectedItem.type = "Photo"
                    ' Nothing to do here, handled in ItemGrid
                else if selectedItem.type = "MusicArtist"
                    group = CreateArtistView(selectedItem.json)
                    if not isValid(group)
                        message_dialog(tr("Unable to find any albums or songs belonging to this artist"))
                    end if
                else if selectedItem.type = "MusicAlbum"
                    group = CreateAlbumView(selectedItem.json)
                else if selectedItem.type = "Audio"
                    m.global.queueManager.callFunc("clear")
                    m.global.queueManager.callFunc("push", selectedItem.json)
                    m.global.queueManager.callFunc("playQueue")
                else
                    ' TODO - switch on more node types
                    message_dialog("This type is not yet supported: " + selectedItem.type + ".")
                end if
            else
                featureDisabledDuringPlayback()
            end if
        else if isNodeEvent(msg, "movieSelected")
            ' If you select a movie from ANYWHERE, follow this flow
            node = getMsgPicker(msg, "picker")
            group = CreateMovieDetailsGroup(node)
        else if isNodeEvent(msg, "seriesSelected")
            ' If you select a TV Series from ANYWHERE, follow this flow
            node = getMsgPicker(msg, "picker")
            group = CreateSeriesDetailsGroup(node)
        else if isNodeEvent(msg, "seasonSelected")
            ' If you select a TV Season from ANYWHERE, follow this flow
            ptr = msg.getData()
            ' ptr is for [row, col] of selected item... but we only have 1 row
            series = msg.getRoSGNode()
            node = series.seasonData.items[ptr[1]]
            group = CreateSeasonDetailsGroup(series.itemContent, node)
        else if isNodeEvent(msg, "musicAlbumSelected")
            ' If you select a Music Album from ANYWHERE, follow this flow
            ptr = msg.getData()
            albums = msg.getRoSGNode()
            node = albums.musicArtistAlbumData.items[ptr]
            group = CreateAlbumView(node)
        else if isNodeEvent(msg, "appearsOnSelected")
            ' If you select a Music Album from ANYWHERE, follow this flow
            ptr = msg.getData()
            albums = msg.getRoSGNode()
            node = albums.musicArtistAppearsOnData.items[ptr]
            group = CreateAlbumView(node)
        else if isNodeEvent(msg, "playSong")
            ' User has selected audio they want us to play
            selectedIndex = msg.getData()
            screenContent = msg.getRoSGNode()

            m.global.queueManager.callFunc("clear")
            m.global.queueManager.callFunc("push", screenContent.albumData.items[selectedIndex])
            m.global.queueManager.callFunc("playQueue")
        else if isNodeEvent(msg, "playAllSelected")
            ' User has selected playlist of of audio they want us to play
            screenContent = msg.getRoSGNode()
            m.spinner = screenContent.findNode("spinner")
            m.spinner.visible = true

            m.global.queueManager.callFunc("clear")
            m.global.queueManager.callFunc("set", screenContent.albumData.items)
            m.global.queueManager.callFunc("playQueue")
        else if isNodeEvent(msg, "playArtistSelected")
            ' User has selected playlist of of audio they want us to play
            screenContent = msg.getRoSGNode()

            m.global.queueManager.callFunc("clear")
            m.global.queueManager.callFunc("set", CreateArtistMix(screenContent.pageContent.id).Items)
            m.global.queueManager.callFunc("playQueue")

        else if isNodeEvent(msg, "instantMixSelected")
            ' User has selected instant mix
            ' User has selected playlist of of audio they want us to play
            screenContent = msg.getRoSGNode()
            m.spinner = screenContent.findNode("spinner")
            if isValid(m.spinner)
                m.spinner.visible = true
            end if

            viewHandled = false

            ' Create instant mix based on selected album
            if isValid(screenContent.albumData)
                if isValid(screenContent.albumData.items)
                    if screenContent.albumData.items.count() > 0
                        m.global.queueManager.callFunc("clear")
                        m.global.queueManager.callFunc("set", CreateInstantMix(screenContent.albumData.items[0].id).Items)
                        m.global.queueManager.callFunc("playQueue")

                        viewHandled = true
                    end if
                end if
            end if

            if not viewHandled
                ' Create instant mix based on selected artist
                m.global.queueManager.callFunc("clear")
                m.global.queueManager.callFunc("set", CreateInstantMix(screenContent.pageContent.id).Items)
                m.global.queueManager.callFunc("playQueue")
            end if

        else if isNodeEvent(msg, "episodeSelected")
            ' If you select a TV Episode from ANYWHERE, follow this flow
            m.selectedItemType = "Episode"
            node = getMsgPicker(msg, "picker")
            video_id = node.id
            if node.selectedAudioStreamIndex <> invalid and node.selectedAudioStreamIndex > 1
                video = CreateVideoPlayerGroup(video_id, invalid, node.selectedAudioStreamIndex)
            else
                video = CreateVideoPlayerGroup(video_id)
            end if
            if video <> invalid and video.errorMsg <> "introaborted"
                sceneManager.callFunc("pushScene", video)
            end if
        else if isNodeEvent(msg, "search_value")
            query = msg.getRoSGNode().search_value
            group.findNode("SearchBox").visible = false
            options = group.findNode("SearchSelect")
            options.visible = true
            options.setFocus(true)

            dialog = createObject("roSGNode", "ProgressDialog")
            dialog.title = tr("Loading Search Data")
            m.scene.dialog = dialog
            results = SearchMedia(query)
            dialog.close = true
            options.itemData = results
            options.query = query
        else if isNodeEvent(msg, "itemSelected")
            ' Search item selected
            node = getMsgPicker(msg)
            ' TODO - swap this based on target.mediatype
            ' types: [ Series (Show), Episode, Movie, Audio, Person, Studio, MusicArtist ]
            m.selectedItemType = node.type
            if node.type = "Series"
                group = CreateSeriesDetailsGroup(node)
            else if node.type = "Movie"
                group = CreateMovieDetailsGroup(node)
            else if node.type = "MusicArtist"
                group = CreateArtistView(node.json)
            else if node.type = "MusicAlbum"
                group = CreateAlbumView(node.json)
            else if node.type = "Audio"
                m.global.queueManager.callFunc("clear")
                m.global.queueManager.callFunc("push", node.json)
                m.global.queueManager.callFunc("playQueue")
            else if node.type = "Person"
                group = CreatePersonView(node)
            else if node.type = "TvChannel"
                group = CreateVideoPlayerGroup(node.id)
                sceneManager.callFunc("pushScene", group)
            else if node.type = "Episode"
                group = CreateVideoPlayerGroup(node.id)
                sceneManager.callFunc("pushScene", group)
            else if node.type = "Audio"
                selectedIndex = msg.getData()
                screenContent = msg.getRoSGNode()
                m.global.queueManager.callFunc("clear")
                m.global.queueManager.callFunc("push", screenContent.albumData.items[node.id])
                m.global.queueManager.callFunc("playQueue")
            else
                ' TODO - switch on more node types
                message_dialog("This type is not yet supported: " + node.type + ".")
            end if
        else if isNodeEvent(msg, "buttonSelected")
            ' If a button is selected, we have some determining to do
            btn = getButton(msg)
            group = sceneManager.callFunc("getActiveScene")
            if btn <> invalid and btn.id = "play-button"
                ' Check if a specific Audio Stream was selected
                audio_stream_idx = 1
                if group.selectedAudioStreamIndex <> invalid
                    audio_stream_idx = group.selectedAudioStreamIndex
                end if

                ' Check to see if a specific video "version" was selected
                mediaSourceId = invalid
                if group.selectedVideoStreamId <> invalid
                    mediaSourceId = group.selectedVideoStreamId
                end if
                video_id = group.id

                video = CreateVideoPlayerGroup(video_id, mediaSourceId, audio_stream_idx)
                if video <> invalid and video.errorMsg <> "introaborted"
                    sceneManager.callFunc("pushScene", video)
                end if

                if group.lastfocus.id = "main_group"
                    buttons = group.findNode("buttons")
                    if isValid(buttons)
                        group.lastfocus = group.findNode("buttons")
                    end if
                end if

                if group.lastFocus <> invalid
                    group.lastFocus.setFocus(true)
                end if

            else if btn <> invalid and btn.id = "trailer-button"
                audio_stream_idx = 1
                mediaSourceId = invalid
                video_id = group.id

                trailerData = api_API().users.getlocaltrailers(get_setting("active_user"), group.id)

                video_id = trailerData[0].id

                video = CreateVideoPlayerGroup(video_id, mediaSourceId, audio_stream_idx, false, false)
                if video <> invalid and video.errorMsg <> "introaborted"
                    sceneManager.callFunc("pushScene", video)
                end if

                if group.lastFocus <> invalid
                    group.lastFocus.setFocus(true)
                end if
            else if btn <> invalid and btn.id = "watched-button"
                movie = group.itemContent
                if movie.watched
                    UnmarkItemWatched(movie.id)
                else
                    MarkItemWatched(movie.id)
                end if
                movie.watched = not movie.watched
            else if btn <> invalid and btn.id = "favorite-button"
                movie = group.itemContent
                if movie.favorite
                    UnmarkItemFavorite(movie.id)
                else
                    MarkItemFavorite(movie.id)
                end if
                movie.favorite = not movie.favorite
            else
                ' If there are no other button matches, check if this is a simple "OK" Dialog & Close if so
                dialog = msg.getRoSGNode()
                if dialog.id = "OKDialog"
                    dialog.unobserveField("buttonSelected")
                    dialog.close = true
                end if
            end if
        else if isNodeEvent(msg, "optionSelected")
            button = msg.getRoSGNode()
            group = sceneManager.callFunc("getActiveScene")
            if button.id = "goto_search"
                ' Exit out of the side panel
                panel = group.findNode("options")
                panel.visible = false
                if group.lastFocus <> invalid
                    group.lastFocus.setFocus(true)
                else
                    group.setFocus(true)
                end if
                group = CreateSearchPage()
                sceneManager.callFunc("pushScene", group)
                group.findNode("SearchBox").findNode("search_Key").setFocus(true)
                group.findNode("SearchBox").findNode("search_Key").active = true
            else if button.id = "change_server"
                unset_setting("server")
                unset_setting("port")
                SignOut(false)
                sceneManager.callFunc("clearScenes")
                goto app_start
            else if button.id = "sign_out"
                SignOut()
                sceneManager.callFunc("clearScenes")
                goto app_start
            else if button.id = "settings"
                ' Exit out of the side panel
                panel = group.findNode("options")
                panel.visible = false
                if group.lastFocus <> invalid
                    group.lastFocus.setFocus(true)
                else
                    group.setFocus(true)
                end if
                sceneManager.callFunc("settings")
            end if
        else if isNodeEvent(msg, "selectSubtitlePressed")
            node = m.scene.focusedChild
            if node.focusedChild <> invalid and node.focusedChild.isSubType("JFVideo")
                trackSelected = selectSubtitleTrack(node.Subtitles, node.SelectedSubtitle)
                if trackSelected <> invalid and trackSelected <> -2
                    changeSubtitleDuringPlayback(trackSelected)
                end if
            end if
        else if isNodeEvent(msg, "selectPlaybackInfoPressed")
            node = m.scene.focusedChild
            if node.focusedChild <> invalid and node.focusedChild.isSubType("JFVideo")
                info = GetPlaybackInfo()
                show_dialog(tr("Playback Information"), info)
            end if
        else if isNodeEvent(msg, "state")
            node = msg.getRoSGNode()
            if m.selectedItemType = "TvChannel" and node.state = "finished"
                video = CreateVideoPlayerGroup(node.id)
                m.global.sceneManager.callFunc("pushScene", video)
                m.global.sceneManager.callFunc("deleteSceneAtIndex", 2)
            else if node.state = "finished"
                node.control = "stop"

                ' If node allows retrying using Transcode Url, give that shot
                if isValid(node.retryWithTranscoding) and node.retryWithTranscoding
                    retryVideo = CreateVideoPlayerGroup(node.Id, invalid, node.audioIndex, true, false)
                    m.global.sceneManager.callFunc("popScene")
                    if retryVideo <> invalid
                        m.global.sceneManager.callFunc("pushScene", retryVideo)
                    end if
                else if node.showID = invalid
                    sceneManager.callFunc("popScene")
                else
                    autoPlayNextEpisode(node.id, node.showID)
                end if
            end if
        else if type(msg) = "roDeviceInfoEvent"
            event = msg.GetInfo()
            group = sceneManager.callFunc("getActiveScene")
            if event.exitedScreensaver = true
                sceneManager.callFunc("resetTime")
                if group.subtype() = "Home"
                    currentTime = CreateObject("roDateTime").AsSeconds()
                    group.timeLastRefresh = currentTime
                    group.callFunc("refresh")
                end if
                ' todo: add other screens to be refreshed - movie detail, tv series, episode list etc.
            else
                print "Unhandled roDeviceInfoEvent:"
                print msg.GetInfo()
            end if
        else if type(msg) = "roInputEvent"
            if msg.IsInput()
                info = msg.GetInfo()
                if info.DoesExist("mediatype") and info.DoesExist("contentid")
                    video = CreateVideoPlayerGroup(info.contentId)
                    if video <> invalid and video.errorMsg <> "introaborted"
                        sceneManager.callFunc("pushScene", video)
                    else
                        dialog = createObject("roSGNode", "Dialog")
                        dialog.id = "OKDialog"
                        dialog.title = tr("Not found")
                        dialog.message = tr("The requested content does not exist on the server")
                        dialog.buttons = [tr("OK")]
                        m.scene.dialog = dialog
                        m.scene.dialog.observeField("buttonSelected", m.port)
                    end if
                end if
            end if
        else
            print "Unhandled " type(msg)
            print msg
        end if
    end while

end sub

function LoginFlow(startOver = false as boolean)
    'Collect Jellyfin server and user information
    start_login:

    if get_setting("server") = invalid then startOver = true

    invalidServer = true
    if not startOver
        ' Show Connecting to Server spinner
        dialog = createObject("roSGNode", "ProgressDialog")
        dialog.title = tr("Connecting to Server")
        m.scene.dialog = dialog
        invalidServer = ServerInfo().Error
        dialog.close = true
    end if

    m.serverSelection = "Saved"
    if startOver or invalidServer
        print "Get server details"
        SendPerformanceBeacon("AppDialogInitiate") ' Roku Performance monitoring - Dialog Starting
        m.serverSelection = CreateServerGroup()
        SendPerformanceBeacon("AppDialogComplete") ' Roku Performance monitoring - Dialog Closed
        if m.serverSelection = "backPressed"
            print "backPressed"
            m.global.sceneManager.callFunc("clearScenes")
            return false
        end if
        SaveServerList()
    end if

    if get_setting("active_user") = invalid
        SendPerformanceBeacon("AppDialogInitiate") ' Roku Performance monitoring - Dialog Starting
        publicUsers = GetPublicUsers()
        if publicUsers.count()
            publicUsersNodes = []
            for each item in publicUsers
                user = CreateObject("roSGNode", "PublicUserData")
                user.id = item.Id
                user.name = item.Name
                if item.PrimaryImageTag <> invalid
                    user.ImageURL = UserImageURL(user.id, { "tag": item.PrimaryImageTag })
                end if
                publicUsersNodes.push(user)
            end for
            userSelected = CreateUserSelectGroup(publicUsersNodes)
            if userSelected = "backPressed"
                SendPerformanceBeacon("AppDialogComplete") ' Roku Performance monitoring - Dialog Closed
                return LoginFlow(true)
            else
                'Try to login without password. If the token is valid, we're done
                get_token(userSelected, "")
                if get_setting("active_user") <> invalid
                    m.user = AboutMe()
                    LoadUserPreferences()
                    LoadUserAbilities(m.user)
                    SendPerformanceBeacon("AppDialogComplete") ' Roku Performance monitoring - Dialog Closed
                    return true
                end if
            end if
        else
            userSelected = ""
        end if
        passwordEntry = CreateSigninGroup(userSelected)
        SendPerformanceBeacon("AppDialogComplete") ' Roku Performance monitoring - Dialog Closed
        if passwordEntry = "backPressed"
            m.global.sceneManager.callFunc("clearScenes")
            return LoginFlow(true)
        end if
    end if

    m.user = AboutMe()
    if m.user = invalid or m.user.id <> get_setting("active_user")
        print "Login failed, restart flow"
        unset_setting("active_user")
        goto start_login
    end if

    LoadUserPreferences()
    LoadUserAbilities(m.user)
    m.global.sceneManager.callFunc("clearScenes")

    'Send Device Profile information to server
    body = getDeviceCapabilities()
    req = APIRequest("/Sessions/Capabilities/Full")
    req.SetRequest("POST")
    postJson(req, FormatJson(body))
    return true
end function

sub SaveServerList()
    'Save off this server to our list of saved servers for easier navigation between servers
    server = get_setting("server")
    saved = get_setting("saved_servers")
    if server <> invalid
        server = LCase(server)'Saved server data is always lowercase
    end if
    entryCount = 0
    addNewEntry = true
    savedServers = { serverList: [] }
    if saved <> invalid
        savedServers = ParseJson(saved)
        entryCount = savedServers.serverList.Count()
        if savedServers.serverList <> invalid and entryCount > 0
            for each item in savedServers.serverList
                if item.baseUrl = server
                    addNewEntry = false
                    exit for
                end if
            end for
        end if
    end if

    if addNewEntry
        if entryCount = 0
            set_setting("saved_servers", FormatJson({ serverList: [{ name: m.serverSelection, baseUrl: server, iconUrl: "pkg:/images/logo-icon120.jpg", iconWidth: 120, iconHeight: 120 }] }))
        else
            savedServers.serverList.Push({ name: m.serverSelection, baseUrl: server, iconUrl: "pkg:/images/logo-icon120.jpg", iconWidth: 120, iconHeight: 120 })
            set_setting("saved_servers", FormatJson(savedServers))
        end if
    end if
end sub

sub DeleteFromServerList(urlToDelete)
    saved = get_setting("saved_servers")
    if urlToDelete <> invalid
        urlToDelete = LCase(urlToDelete)
    end if
    if saved <> invalid
        savedServers = ParseJson(saved)
        newServers = { serverList: [] }
        for each item in savedServers.serverList
            if item.baseUrl <> urlToDelete
                newServers.serverList.Push(item)
            end if
        end for
        set_setting("saved_servers", FormatJson(newServers))
    end if
end sub

sub RunScreenSaver()
    print "Starting screensaver..."

    scene = ReadAsciiFile("tmp:/scene")
    if scene = "nowplaying" then return

    screen = createObject("roSGScreen")
    m.port = createObject("roMessagePort")
    screen.setMessagePort(m.port)

    screen.createScene("Screensaver")
    screen.Show()

    while true
        msg = wait(8000, m.port)
        if msg <> invalid
            msgType = type(msg)
            if msgType = "roSGScreenEvent"
                if msg.isScreenClosed() then return
            end if
        end if
    end while

end sub

' Roku Performance monitoring
sub SendPerformanceBeacon(signalName as string)
    if m.global.app_loaded = false
        m.scene.signalBeacon(signalName)
    end if
end sub

sub featureDisabledDuringPlayback()
    port = CreateObject("roMessagePort")
    dialog = createObject("roSGNode", "Dialog")
    dialog.message = tr("Feature not available during playback.")
    dialog.buttons = [tr("OK")]
    m.scene.dialog = dialog
    m.scene.dialog.observeField("buttonSelected", port)
    wait(0, port)
    m.scene.dialog.close = true
end sub
