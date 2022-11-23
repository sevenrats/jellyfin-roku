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

    'Play Next Episode button
    m.nextEpisodeButton = m.top.findNode("nextEpisode")
    m.nextEpisodeButton.text = tr("Next Episode")
    m.nextEpisodeButton.setFocus(false)

    m.showNextEpisodeButtonAnimation = m.top.findNode("showNextEpisodeButton")
    m.hideNextEpisodeButtonAnimation = m.top.findNode("hideNextEpisodeButton")

    m.checkedForNextEpisode = false
    m.getNextEpisodeTask = createObject("roSGNode", "GetNextEpisodeTask")
    m.getNextEpisodeTask.observeField("nextEpisodeData", "onNextEpisodeDataLoaded")

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
    m.checkedForNextEpisode = true

    m.top.observeField("position", "onPositionChanged")

    if m.getNextEpisodeTask.nextEpisodeData.Items.count() <> 2
        m.top.unobserveField("position")
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

    m.buttonGrp = m.top.findNode("buttons")
    m.buttonGrp.observeField("escape", "onButtonGroupEscaped")
    m.buttonGrp.visible = false

    m.checkedForNextEpisode = false
    m.movieInfo = false
    m.getNextEpisodeTask = createObject("roSGNode", "GetNextEpisodeTask")
    m.getNextEpisodeTask.observeField("nextEpisodeData", "onNextEpisodeDataLoaded")

    m.getItemQueryTask = createObject("roSGNode", "GetItemQueryTask")
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

sub info()
    'episode info
    if m.getNextEpisodeTask.nextEpisodeData <> invalid
        m.info = m.getNextEpisodeTask.nextEpisodeData.Items[0].Overview
    else if m.getItemQueryTask.getItemQueryData <> invalid 'movie info
        m.info = m.getItemQueryTask.getItemQueryData.Items.[0].Overview
    else
        m.info = "No Data"
    end if

    'movie info

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
    end if
end sub

sub PlaybackInfo()
    m.top.selectPlaybackInfoPressed = true
    m.buttonGrp.visible = false
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

    m.previouslySelectedButtonIndex = -1

    m.top.observeField("selectedButtonIndex", "onButtonSelectedChange")
    m.top.selectedButtonIndex = 0
end sub



function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false

    if m.top.Subtitles.count() and key = "down"
        m.top.selectSubtitlePressed = true
        return true
    end if

    if m.buttonGrp.isInFocusChain()
        if key = "OK"
            if press
                selectedButton = m.buttonGrp.getChild(m.top.selectedButtonIndex)
                selectedButton.selected = not selectedButton.selected
                if selectedButton.id = "cc"
                    Subtitles()
                end if
                if selectedButton.id = "playbackInfo"
                    PlaybackInfo()
                end if
                if selectedButton.id = "info"
                    info()
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
        end if
        if key = "right"
            m.previouslySelectedButtonIndex = m.top.selectedButtonIndex
            if m.top.selectedButtonIndex < m.buttonCount - 1 then m.top.selectedButtonIndex = m.top.selectedButtonIndex + 1
            return true
        end if
    end if

    if not press then return false

    return false
end function
