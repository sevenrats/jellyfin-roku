sub init()
    m.playbackTimer = m.top.findNode("playbackTimer")
    m.bufferCheckTimer = m.top.findNode("bufferCheckTimer")
    m.top.observeField("state", "onState")
    m.top.observeField("content", "onContentChange")

    m.playbackTimer.observeField("fire", "ReportPlayback")
    m.bufferPercentage = 0 ' Track whether content is being loaded
    m.playReported = false
    m.top.transcodeReasons = []
    m.bufferCheckTimer.duration = 30

    if get_user_setting("ui.design.hideclock") = "true"
        clockNode = findNodeBySubtype(m.top, "clock")
        if clockNode[0] <> invalid then clockNode[0].parent.removeChild(clockNode[0].node)
    end if

    m.buttonGrp = m.top.findNode("buttons")
    m.buttonGrp.observeField("escape", "onButtonGroupEscaped")
    m.buttonGrp.visible = false

    'Play Next Episode button
    m.nextEpisodeButton = m.top.findNode("nextEpisode")
    m.nextEpisodeButton.text = tr("Next Episode")
    m.nextEpisodeButton.setFocus(false)

    m.showNextEpisodeButtonAnimation = m.top.findNode("showNextEpisodeButton")
    m.hideNextEpisodeButtonAnimation = m.top.findNode("hideNextEpisodeButton")

    m.checkedForNextEpisode = false
    m.movieInfo = false

    m.getNextEpisodeTask = createObject("roSGNode", "GetNextEpisodeTask")
    m.getNextEpisodeTask.observeField("nextEpisodeData", "onNextEpisodeDataLoaded")

    m.getItemQueryTask = createObject("roSGNode", "GetItemQueryTask")

    m.extras = m.top.findNode("extrasGrid")
    m.extrasGrp = m.top.findnode("extrasContainer")
    m.extrasGrp.opacity = 0

    m.showGuideAnimation = m.top.findNode("showGuide")
    m.guideIntialLoad = false
end sub

'
' Runs Next Episode button animation and sets focus to button
sub shownextEpisode()
    if m.nextEpisodeButton.hasFocus() = false
        m.shownextEpisodeButtonAnimation.control = "start"
        m.nextEpisodeButton.setFocus(true)
        m.nextEpisodeButton.visible = true
    end if
end sub

' Event handler for when video content field changes
sub onContentChange()
    if not isValid(m.top.content) then return

    m.top.observeField("position", "onPositionChanged")

    ' If video content type is not episode, remove position observer
    if m.top.content.contenttype <> 4
        m.top.unobserveField("position")
    end if
end sub

sub onNextEpisodeDataLoaded()
    if m.getNextEpisodeTask.nextEpisodeData.Items.count() = 2
        m.top.observeField("position", "onPositionChanged")
        m.checkedForNextEpisode = true
    else ' No Next episode found, remove position observer
        m.top.unobserveField("position")
        m.checkedForNextEpisode = true
    end if
end sub


'
' Runs Next Episode button animation and sets focus to button
sub showNextEpisodeButton()
    if not m.nextEpisodeButton.visible
        m.showNextEpisodeButtonAnimation.control = "start"
        m.nextEpisodeButton.setFocus(true)
        m.nextEpisodeButton.visible = true
    end if
end sub

'
' Runs hide Next Episode button animation and sets focus back to video
sub hidenextEpisode()
    'm.top.trickPlayBar.unobserveField("visible")
    m.hidenextEpisodeButtonAnimation.control = "start"
    m.nextEpisodeButton.setFocus(false)
    m.top.setFocus(true)
end sub


sub handleNextEpisode()
    ' Dialog box is open
    if int(m.top.position) >= (m.top.runTime - 30)
        shownextEpisode()
        updateCount()
    else
        m.nextEpisodeButton.visible = false
        m.nextEpisodeButton.setFocus(false)
        m.top.setFocus(true)
    end if
end sub

'
'Update count down text
sub updateCount()
    m.nextEpisodeButton.text = tr("Next Episode") + " " + Int(m.top.runTime - m.top.position).toStr()
end sub

'
' Runs hide Next Episode button animation and sets focus back to video
sub hideNextEpisodeButton()
    m.hideNextEpisodeButtonAnimation.control = "start"
    m.nextEpisodeButton.setFocus(false)
    m.top.setFocus(true)
end sub

' Checks if we need to display the Next Episode button
sub checkTimeToDisplayNextEpisode()
    if int(m.top.position) >= (m.top.runTime - 30)
        showNextEpisodeButton()
        updateCount()
        return
    end if

    if m.nextEpisodeButton.visible or m.nextEpisodeButton.hasFocus()
        m.nextEpisodeButton.visible = false
        m.nextEpisodeButton.setFocus(false)
    end if
end sub

' When Video Player state changes
sub onPositionChanged()
    ' Check if dialog is open
    m.dialog = m.top.getScene().findNode("dialogBackground")
    if not isValid(m.dialog)
        checkTimeToDisplayNextEpisode()
    end if

    m.checkedForNextEpisode = false
    m.movieInfo = false
end sub

'
' When Video Player state changes
' When Video Player state changes
sub onState(msg)
    ' When buffering, start timer to monitor buffering process
    if m.top.state = "buffering" and m.bufferCheckTimer <> invalid
        ' start timer
        m.bufferCheckTimer.control = "start"
        m.bufferCheckTimer.ObserveField("fire", "bufferCheck")
    else if m.top.state = "error"
        if not m.playReported and m.top.transcodeAvailable
            m.top.retryWithTranscoding = true ' If playback was not reported, retry with transcoding
        else
            ' If an error was encountered, Display dialog
            dialog = createObject("roSGNode", "Dialog")
            dialog.title = tr("Error During Playback")
            dialog.buttons = [tr("OK")]
            dialog.message = tr("An error was encountered while playing this item.")
            dialog.observeField("buttonSelected", "dialogClosed")
            m.top.getScene().dialog = dialog
        end if
        ' Stop playback and exit player
        m.top.control = "stop"
        m.top.backPressed = true
    else if m.top.state = "playing"

        ' Check if next episde is available
        if isValid(m.top.showID)
            if m.top.showID <> "" and not m.checkedForNextEpisode and m.top.content.contenttype = 4
                m.getNextEpisodeTask.showID = m.top.showID
                m.getNextEpisodeTask.videoID = m.top.id
                m.getNextEpisodeTask.control = "RUN"
                'remove Guide option
                m.buttonGrp.removeChild(m.top.findNode("guide"))
                setupButtons()
            end if
        end if

        ' Check if video is movie
        if m.top.content.contenttype = 1
            if m.top.videoID <> "" and not m.movieInfo and m.top.content.contenttype = 1
                m.getItemQueryTask.videoID = m.top.id
                m.getItemQueryTask.control = "RUN"
                'remove Guide option
                m.buttonGrp.removeChild(m.top.findNode("guide"))
                setupButtons()
            end if
        end if

        if m.top.content.live = true
            m.buttonGrp.removeChild(m.top.findNode("cast"))
            m.buttonGrp.removeChild(m.top.findNode("cc"))

            setupButtons()
        end if

        if m.playReported = false
            ReportPlayback("start")
            m.playReported = true
        else
            ReportPlayback()
        end if
        m.playbackTimer.control = "start"
    else if m.top.state = "paused"
        m.playbackTimer.control = "stop"
        ReportPlayback()
    else if m.top.state = "stopped"
        m.playbackTimer.control = "stop"
        ReportPlayback("stop")
        m.playReported = false
    end if
end sub

'
' Report playback to server
sub ReportPlayback(state = "update" as string)

    if m.top.position = invalid then return

    params = {
        "ItemId": m.top.id,
        "PlaySessionId": m.top.PlaySessionId,
        "PositionTicks": int(m.top.position) * 10000000&, 'Ensure a LongInteger is used
        "IsPaused": (m.top.state = "paused")
    }
    if m.top.content.live
        params.append({
            "MediaSourceId": m.top.transcodeParams.MediaSourceId,
            "LiveStreamId": m.top.transcodeParams.LiveStreamId
        })
        m.bufferCheckTimer.duration = 30
    end if

    ' Report playstate via worker task
    playstateTask = m.global.playstateTask
    playstateTask.setFields({ status: state, params: params })
    playstateTask.control = "RUN"
end sub

'
' Check the the buffering has not hung
sub bufferCheck(msg)

    if m.top.state <> "buffering"
        ' If video is not buffering, stop timer
        m.bufferCheckTimer.control = "stop"
        m.bufferCheckTimer.unobserveField("fire")
        return
    end if
    if m.top.bufferingStatus <> invalid

        ' Check that the buffering percentage is increasing
        if m.top.bufferingStatus["percentage"] > m.bufferPercentage
            m.bufferPercentage = m.top.bufferingStatus["percentage"]
        else if m.top.content.live = true
            m.top.callFunc("refresh")
        else
            ' If buffering has stopped Display dialog
            dialog = createObject("roSGNode", "Dialog")
            dialog.title = tr("Error Retrieving Content")
            dialog.buttons = [tr("OK")]
            dialog.message = tr("There was an error retrieving the data for this item from the server.")
            dialog.observeField("buttonSelected", "dialogClosed")
            m.top.getScene().dialog = dialog

            ' Stop playback and exit player
            m.top.control = "stop"
            m.top.backPressed = true
        end if
    end if

end sub

sub setinfo()
    'episode info
    if m.getNextEpisodeTask.nextEpisodeData <> invalid
        m.info = m.getNextEpisodeTask.nextEpisodeData.Items[0].Overview
        m.content = m.getNextEpisodeTask.nextEpisodeData.Items[0]
    else if m.getItemQueryTask.getItemQueryData <> invalid 'movie info
        m.info = m.getItemQueryTask.getItemQueryData.Items.[0].Overview
        m.content = m.getItemQueryTask.getItemQueryData.Items.[0]
    else
        m.info = "No Data"
    end if
end sub

sub info()

    ' If buffering has stopped Display dialog
    dialog = createObject("roSGNode", "Dialog")
    dialog.buttons = [tr("OK")]
    dialog.message = m.info
    dialog.observeField("buttonSelected", "dialogClosed")
    m.top.getScene().dialog = dialog
    m.top.control = "pause"
end sub

'
' Clean up on Dialog Closed
sub dialogClosed(msg)
    sourceNode = msg.getRoSGNode()
    sourceNode.unobserveField("buttonSelected")
    sourceNode.close = true
    m.buttonGrp.visible = true
    '
    ' if paused and diloge closed then play video
    if m.top.control = "pause"
        m.top.control = "resume"
    end if
end sub

sub Subtitles()
    if m.top.Subtitles.count()
        m.top.selectSubtitlePressed = true
        m.buttonGrp.visible = false
        m.top.setFocus(true)
    end if
end sub

sub PlaybackInfo()
    m.top.selectPlaybackInfoPressed = true
    m.buttonGrp.visible = false
    m.top.setFocus(true)
end sub

sub onButtonGroupEscaped()
    key = m.buttonGrp.escape
    if key = "up"
        m.buttonGrp.setFocus(false)
        m.buttonGrp.visible = false
        m.top.setFocus(true)
    end if
end sub

' Setup playback buttons, default to Play button selected
sub setupButtons()
    m.buttonGrp.visible = false
    m.buttonGrp = m.top.findNode("buttons")
    m.buttonCount = m.buttonGrp.getChildCount()

    'm.previouslySelectedButtonIndex = -1
    print "Running setupButtons SUB()"
    m.top.observeField("selectedButtonIndex", "onButtonSelectedChange")
end sub

' Event handler when user selected a different playback button
sub onButtonSelectedChange()
    ' Change previously selected button back to default image
    previousSelectedButton = m.buttonGrp.getChild(m.previouslySelectedButtonIndex)
    previousSelectedButton.focus = false
    ' Change selected button image to selected image
    selectedButton = m.buttonGrp.getChild(m.top.selectedButtonIndex)
    selectedButton.focus = true
    print "button focus index:  " m.top.selectedButtonIndex
end sub

sub showTVGuide()
    if m.guideIntialLoad = false
        m.tvGuide = createObject("roSGNode", "Schedule")
        m.tvGuide.removeChild(m.tvGuide.findNode("rec"))
        m.tvGuide.removeChild(m.tvGuide.findNode("detailsPane"))
        m.tvGuide.observeField("watchChannel", "onChannelSelected")
        m.tvGuide.visible = true
        m.tvGuide.setFocus(true)
        m.tvGuide.translation = "[0, 200]"
        m.tvGuide.lastFocus = "videoPlayer"
    end if
    m.top.appendChild(m.tvGuide)
    m.buttonGrp.setFocus(false)
    m.buttonGrp.visible = false
    m.showGuideAnimation.control = "start"

end sub

sub onChannelSelected(msg)
    node = msg.getRoSGNode()
    m.top.lastFocus = lastFocusedChild(node)
    if node.watchChannel <> invalid
        m.top.selectedItem = node.watchChannel.id
        m.top.control = "stop"
    end if
end sub



function onKeyEvent(key as string, press as boolean) as boolean
    'castGrp = m.top.findNode("extrasGrid")
    if key = "back" and m.top.control = "pause"
        m.top.control = "resume"
        return true
    end if
    if key = "back" and m.tvGuide?.visible = true
        m.top.removeChild(m.tvGuide)
        'm.tvGuide.visible = false
        m.tvGuide.setFocus(false)
        m.top.setFocus(true)
        return true
    end if

    if key = "OK" and m.nextEpisodeButton.isinfocuschain() and m.top.trickPlayMode = "play"
        m.top.state = "finished"
        return true
    else
        'Hide Next Episode Button
        m.nextEpisodeButton.visible = false
        m.nextEpisodeButton.setFocus(false)
        m.top.setFocus(true)
    end if
    if key = "down" and m.top.hasFocus()
        setinfo()
        m.buttonGrp.setFocus(true)
        m.buttonGrp.visible = true
        return true
    end if

    if (key = "down" or key = "back") and m.extras.hasFocus()
        m.extras.setFocus(false)
        m.top.findNode("VertSlider").reverse = true
        m.top.findNode("extrasFader").reverse = true
        m.top.findNode("pplAnime").control = "start"
        m.buttonGrp.setFocus(true)
        m.top.control = "resume"
        m.extrasGrp.opacity = 0

    end if

    if m.buttonGrp.visible = true
        print "button visible"
        'make first button highlighted
        selectedButton = m.buttonGrp.getChild(m.top.selectedButtonIndex)
        selectedButton.focus = true
        if key = "OK"
            if press
                selectedButton = m.buttonGrp.getChild(m.top.selectedButtonIndex)
                selectedButton.selected = not selectedButton.selected
                if selectedButton.id = "guide"
                    showTVGuide()
                    m.guideIntialLoad = true
                    return true
                end if
                if selectedButton.id = "cc"
                    Subtitles()
                end if
                if selectedButton.id = "playbackInfo"
                    PlaybackInfo()
                    m.top.control = "pause"
                end if
                if selectedButton.id = "info"
                    info()
                    m.top.control = "pause"
                    return true
                end if
                if selectedButton.id = "cast"
                    m.top.control = "pause"
                    m.extrasGrp.opacity = 1
                    m.extras.setFocus(true)
                    m.top.findNode("VertSlider").reverse = false
                    m.top.findNode("extrasFader").reverse = false
                    m.top.findNode("pplAnime").control = "start"
                    return true
                end if
            end if
        end if

        if key = "left"
            if m.top.selectedButtonIndex > 0
                m.previouslySelectedButtonIndex = m.top.selectedButtonIndex
                m.top.selectedButtonIndex = m.top.selectedButtonIndex - 1
            end if
            return true
        else if key = "right"
            m.previouslySelectedButtonIndex = m.top.selectedButtonIndex
            if m.top.selectedButtonIndex < m.buttonCount - 1 then m.top.selectedButtonIndex = m.top.selectedButtonIndex + 1
            return true
        end if
        return false
    end if

    if not press then return false

    return false
end function
