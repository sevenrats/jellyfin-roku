sub init()
    m.playbackTimer = m.top.findNode("playbackTimer")
    m.bufferCheckTimer = m.top.findNode("bufferCheckTimer")
    m.top.observeField("state", "onState")
    m.playbackTimer.observeField("fire", "ReportPlayback")
    m.bufferPercentage = 0 ' Track whether content is being loaded
    m.playReported = false
    m.top.transcodeReasons = []
    m.bufferCheckTimer.duration = 30

    if get_user_setting("ui.design.hideclock") = "true"
        clockNode = findNodeBySubtype(m.top, "clock")
        if clockNode[0] <> invalid then clockNode[0].parent.removeChild(clockNode[0].node)
    end if
    'm.trick = m.top.findNode("trickPlayBar")
    'm.top.playbackActionButtons = [
    '    { "text": tr("Guide"), "icon": "pkg:/images/icons/guide-default.png", "focusIcon": "pkg:/images/icons/guide-selected.png" },
    '    { "text": tr("Info"), "icon": "pkg:/images/icons/info-default.png", "focusIcon": "pkg:/images/icons/info-selected.png" },
    '   { "text": tr("Cast"), "icon": "pkg:/images/icons/cast-default.png", "focusIcon": "pkg:/images/icons/cast-selected.png" },
    '  { "text": tr("Loop"), "icon": "pkg:/images/icons/loop-default.png", "focusIcon": "pkg:/images/icons/loop-selected.png" },
    ' { "text": tr("Favorite"), "icon": "pkg:/images/icons/favorite.png", "focusIcon": "pkg:/images/icons/favorite_selected.png" }
    ']

    m.buttonGrp = m.top.findNode("buttons")
    m.buttonGrp.observeField("escape", "onButtonGroupEscaped")
    setupButtons()
    print m.top.content
end sub

'
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

'
' Clean up on Dialog Closed
sub dialogClosed(msg)
    sourceNode = msg.getRoSGNode()
    sourceNode.unobserveField("buttonSelected")
    sourceNode.close = true
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

' Event handler when user selected a different playback button
sub onButtonSelectedChange()
    ' Change previously selected button back to default image
    if m.previouslySelectedButtonIndex > -1
        previousSelectedButton = m.buttonGrp.getChild(m.previouslySelectedButtonIndex)
        previousSelectedButton.focus = false
        print "previous button = "m.previouslySelectedButtonIndex
    end if

    ' Change selected button image to selected image
    selectedButton = m.buttonGrp.getChild(m.top.selectedButtonIndex)
    selectedButton.focus = true
    print "Selected Button = " selectedButton
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    'castGrp = m.top.findNode("extrasGrid")
    if key = "down"
        print "button index = " m.top.selectedButtonIndex
        m.buttonGrp.setFocus(true)
        m.buttonGrp.visible = true

        print "key down"
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
                return true
            end if
        end if

        if key = "left"
            if m.top.selectedButtonIndex > 0
                m.previouslySelectedButtonIndex = m.top.selectedButtonIndex
                m.top.selectedButtonIndex = m.top.selectedButtonIndex - 1
                print "m.top.selectedButtonIndex = " m.top.selectedButtonIndex
                return true
            end if

            if press
                'selectedButton = m.buttonGrp.getChild(m.top.selectedButtonIndex)
                selectedButton = m.top.selectedButtonIndex + 1
                selectedButton.focus = false

                return true
            end if

            return false
        end if

        if key = "right"

            m.previouslySelectedButtonIndex = m.top.selectedButtonIndex
            if m.top.selectedButtonIndex < m.buttonCount - 1
                m.top.selectedButtonIndex = m.top.selectedButtonIndex + 1
            end if
            print "right m.top.selectedButtonIndex = " m.top.selectedButtonIndex
            return true

        end if
    end if

    if not press then return false

    return false
end function
