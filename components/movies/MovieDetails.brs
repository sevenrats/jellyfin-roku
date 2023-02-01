sub init()
    m.extrasGrp = m.top.findnode("extrasGrp")
    m.extrasGrid = m.top.findNode("extrasGrid")
    m.top.optionsAvailable = false

    m.options = m.top.findNode("movieOptions")

    m.main_group = m.top.findNode("main_group")

    main = m.top.findNode("main_group")
    main.translation = [96, 175]
    overview = m.top.findNode("overview")
    overview.width = 1920 - 96 - 300 - 96 - 30

    m.details = m.top.findNode("details")
    m.tagline = m.top.findNode("tagline")

    m.buttonGrp = m.top.findNode("buttons")
    m.buttonGrp.setFocus(true)
    m.top.lastFocus = m.buttonGrp

    m.trailerButton = m.top.findNode("trailer-button")
    m.trailerButton.text = tr("Play Trailer")

    m.top.observeField("itemContent", "itemContentChanged")
end sub

sub OnScreenShown()
    ' set focus to button group
    if m.extrasGrp.opacity = 1
        m.top.lastFocus.setFocus(true)
    else
        m.buttonGrp.setFocus(true)
    end if
end sub

sub trailerAvailableChanged()
    m.trailerButton.visible = m.top.trailerAvailable
end sub

sub itemContentChanged()
    ' Updates video metadata
    item = m.top.itemContent
    itemData = item.json
    m.top.id = itemData.id
    m.top.findNode("moviePoster").uri = m.top.itemContent.posterURL

    ' Set default video source
    if itemData.MediaSources <> invalid
        m.top.selectedVideoStreamId = itemData.MediaSources[0].id
    end if
    ' Find first Audio Stream and set that as default
    SetDefaultAudioTrack(itemData)

    ' Handle all "As Is" fields
    m.top.overhangTitle = itemData.name
    setFieldText("releaseYear", itemData.productionYear)
    setFieldText("overview", itemData.overview)

    if itemData.officialRating <> invalid
        setFieldText("officialRating", itemData.officialRating)
    else
        m.top.findNode("infoGroup").removeChild(m.top.findNode("officialRating"))
    end if

    if itemData.communityRating <> invalid
        setFieldText("communityRating", int(itemData.communityRating * 10) / 10)
        m.top.findNode("star").visible = "true"
    else
        ' hide the star icon
        m.top.findNode("infoGroup").removeChild(m.top.findNode("communityRatingGroup"))
    end if

    if itemData.CriticRating <> invalid
        setFieldText("criticRatingLabel", itemData.criticRating)
        if itemData.CriticRating > 60
            tomato = "pkg:/images/fresh.png"
        else
            tomato = "pkg:/images/rotten.png"
        end if
        m.top.findNode("criticRatingIcon").uri = tomato
    else
        m.top.findNode("infoGroup").removeChild(m.top.findNode("criticRatingGroup"))
    end if

    if type(itemData.RunTimeTicks) = "LongInteger"
        setFieldText("runtime", stri(getRuntime()) + " mins")
        if get_user_setting("ui.design.hideclock") <> "true"
            setFieldText("ends-at", tr("Ends at %1").Replace("%1", getEndTime()))
        end if
    end if

    if itemData.genres.count() > 0
        setFieldText("genres", tr("Genres") + ": " + itemData.genres.join(", "))
    else
        m.top.findNode("details").removeChild(m.top.findNode("genres"))
    end if

    ' show tags if there are no genres to display
    if itemData.genres.count() = 0 and itemData.tags.count() > 0
        setFieldText("genres", tr("Tags") + ": " + itemData.tags.join(", "))
    end if

    directors = []
    for each person in itemData.people
        if person.type = "Director"
            directors.push(person.name)
        end if
    end for
    if directors.count() > 0
        setFieldText("director", tr("Director") + ": " + directors.join(", "))
    else
        m.top.findNode("details").removeChild(m.top.findNode("director"))
    end if

    if get_user_setting("ui.details.hidetagline") = "false"
        if itemData.taglines.count() > 0
            setFieldText("tagline", itemData.taglines[0])
        end if
    else
        m.details.removeChild(m.tagline)
    end if

    'set aired date if type is Episode
    if itemData.PremiereDate <> invalid and itemData.Type = "Episode"
        airDate = CreateObject("roDateTime")
        airDate.FromISO8601String(itemData.PremiereDate)
        m.top.findNode("aired").text = tr("Aired") + ": " + airDate.AsDateString("short-month-no-weekday")
        'remove movie release year label
        m.top.findNode("infoGroup").removeChild(m.top.findNode("releaseYear"))
    end if

    setFavoriteColor()
    setWatchedColor()
    SetUpVideoOptions(itemData.mediaSources)
    SetUpAudioOptions(itemData.mediaStreams)
    m.buttonGrp.visible = true
end sub


sub SetUpVideoOptions(streams)

    videos = []
    codecDetailsSet = false

    for i = 0 to streams.Count() - 1
        if streams[i].VideoType = "VideoFile"
            codec = ""
            if streams[i].mediaStreams <> invalid and streams[i].mediaStreams.Count() > 0

                ' find the first (default) video track to get the codec for the details screen
                if codecDetailsSet = false
                    for index = 0 to streams[i].mediaStreams.Count() - 1
                        if streams[i].mediaStreams[index].Type = "Video"
                            setFieldText("video_codec", tr("Video") + ": " + streams[i].mediaStreams[index].displayTitle)
                            codecDetailsSet = true
                            exit for
                        end if
                    end for
                end if

                codec = streams[i].mediaStreams[0].displayTitle
            end if

            ' Create options for user to switch between video tracks
            videos.push({
                "Title": streams[i].Name,
                "Description": tr("Video"),
                "Selected": m.top.selectedVideoStreamId = streams[i].id,
                "StreamID": streams[i].id,
                "video_codec": codec
            })
        end if
    end for

    if streams.count() > 1
        m.top.findnode("video_codec_count").text = "+" + stri(streams.Count() - 1).trim()
    end if

    options = {}
    options.videos = videos
    m.options.options = options

end sub


sub SetUpAudioOptions(streams)
    tracks = []

    for i = 0 to streams.Count() - 1
        if streams[i].Type = "Audio"
            tracks.push({ "Title": streams[i].displayTitle, "Description": streams[i].Title, "Selected": m.top.selectedAudioStreamIndex = i, "StreamIndex": i })
        end if
    end for

    if tracks.count() > 1
        m.top.findnode("audio_codec_count").text = "+" + stri(tracks.Count() - 1).trim()
    end if

    options = {}
    if m.options.options.videos <> invalid
        options.videos = m.options.options.videos
    end if
    options.audios = tracks
    m.options.options = options

end sub


sub SetDefaultAudioTrack(itemData)
    for i = 0 to itemData.mediaStreams.Count() - 1
        if itemData.mediaStreams[i].Type = "Audio"
            m.top.selectedAudioStreamIndex = i
            setFieldText("audio_codec", tr("Audio") + ": " + itemData.mediaStreams[i].displayTitle)
            exit for
        end if
    end for
end sub

sub setFieldText(field, value)
    node = m.top.findNode(field)
    if node = invalid or value = invalid then return

    ' Handle non strings... Which _shouldn't_ happen, but hey
    if type(value) = "roInt" or type(value) = "Integer"
        value = str(value)
    else if type(value) = "roFloat" or type(value) = "Float"
        value = str(value)
    else if type(value) <> "roString" and type(value) <> "String"
        value = ""
    end if

    node.text = value
end sub

function getRuntime() as integer

    itemData = m.top.itemContent.json

    ' A tick is .1ms, so 1/10,000,000 for ticks to seconds,
    ' then 1/60 for seconds to minutess... 1/600,000,000
    return round(itemData.RunTimeTicks / 600000000.0)
end function

function getEndTime() as string
    itemData = m.top.itemContent.json

    date = CreateObject("roDateTime")
    duration_s = int(itemData.RunTimeTicks / 10000000.0)
    date.fromSeconds(date.asSeconds() + duration_s)
    date.toLocalTime()

    return formatTime(date)
end function

sub setFavoriteColor()
    fave = m.top.itemContent.favorite
    fave_button = m.top.findNode("favorite-button")
    if fave <> invalid and fave
        fave_button.textColor = "#00ff00ff"
        fave_button.focusedTextColor = "#269926ff"
        fave_button.text = tr("Favorite")
    else
        fave_button.textColor = "0xddddddff"
        fave_button.focusedTextColor = "#262626ff"
        fave_button.text = tr("Set Favorite")
    end if
end sub

sub setWatchedColor()
    watched = m.top.itemContent.watched
    watched_button = m.top.findNode("watched-button")
    if watched
        watched_button.textColor = "#ff0000ff"
        watched_button.focusedTextColor = "#992626ff"
        watched_button.text = tr("Watched")
    else
        watched_button.textColor = "0xddddddff"
        watched_button.focusedTextColor = "#262626ff"
        watched_button.text = tr("Set Watched")
    end if
end sub

function round(f as float) as integer
    ' BrightScript only has a "floor" round
    ' This compares floor to floor + 1 to find which is closer
    m = int(f)
    n = m + 1
    x = abs(f - m)
    y = abs(f - n)
    if y > x
        return m
    else
        return n
    end if
end function

'
'Check if options updated and any reloading required
sub audioOptionsClosed()
    if m.options.audioStreamIndex <> m.top.selectedAudioStreamIndex
        m.top.selectedAudioStreamIndex = m.options.audioStreamIndex
        setFieldText("audio_codec", tr("Audio") + ": " + m.top.itemContent.json.mediaStreams[m.top.selectedAudioStreamIndex].displayTitle)
    end if
    m.top.findNode("buttons").setFocus(true)
end sub

'
' Check if options were updated and if any reloding is needed...
sub videoOptionsClosed()
    if m.options.videoStreamId <> m.top.selectedVideoStreamId
        m.top.selectedVideoStreamId = m.options.videoStreamId
        setFieldText("video_codec", tr("Video") + ": " + m.options.video_codec)
        ' Because the video stream has changed (i.e. the actual video)... we need to reload the audio stream choices for that video
        m.top.unobservefield("itemContent")
        itemData = m.top.itemContent.json
        for each mediaSource in itemData.mediaSources
            if mediaSource.id = m.top.selectedVideoStreamId
                itemData.mediaStreams = []
                for i = 0 to mediaSource.mediaStreams.Count() - 1
                    itemData.mediaStreams.push(mediaSource.mediaStreams[i])
                end for
                SetDefaultAudioTrack(itemData)
                SetUpAudioOptions(itemData.mediaStreams)
                exit for
            end if
        end for
        m.top.itemContent.json = itemData
        m.top.observeField("itemContent", "itemContentChanged")
    end if
    m.top.findNode("buttons").setFocus(true)
end sub

function onKeyEvent(key as string, press as boolean) as boolean

    ' Due to the way the button pressed event works, need to catch the release for the button as the press is being sent
    ' directly to the main loop.  Will get this sorted in the layout update for Movie Details
    if key = "OK" and m.top.findNode("options-button").isInFocusChain()
        m.options.visible = true
        m.options.setFocus(true)
    end if

    if key = "down" and m.buttonGrp.isInFocusChain()
        m.top.lastFocus = m.extrasGrid
        m.extrasGrid.setFocus(true)
        m.top.findNode("VertSlider").reverse = false
        m.top.findNode("extrasFader").reverse = false
        m.top.findNode("pplAnime").control = "start"
        return true
    end if

    if key = "up" and m.top.findNode("extrasGrid").isInFocusChain()
        if m.extrasGrid.itemFocused = 0
            m.top.lastFocus = m.buttonGrp
            m.top.findNode("VertSlider").reverse = true
            m.top.findNode("extrasFader").reverse = true
            m.top.findNode("pplAnime").control = "start"
            m.buttonGrp.setFocus(true)
            return true
        end if
    end if

    if not press then return false

    if key = "back"
        if m.options.visible = true
            m.options.visible = false
            videoOptionsClosed()
            audioOptionsClosed()
            return true
        end if
    end if
    return false
end function
