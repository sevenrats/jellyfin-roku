function isNodeEvent(msg, field as string) as boolean
    return type(msg) = "roSGNodeEvent" and msg.getField() = field
end function


function getMsgPicker(msg, subnode = "" as string) as object
    node = msg.getRoSGNode()
    ' Subnode allows for handling alias messages
    if subnode <> ""
        node = node.findNode(subnode)
    end if
    coords = node.rowItemSelected
    target = node.content.getChild(coords[0]).getChild(coords[1])
    return target
end function

function getButton(msg, subnode = "buttons" as string) as object
    buttons = msg.getRoSGNode().findNode(subnode)
    if buttons = invalid then return invalid
    active_button = buttons.focusedChild
    return active_button
end function

function leftPad(base as string, fill as string, length as integer) as string
    while len(base) < length
        base = fill + base
    end while
    return base
end function

function ticksToHuman(ticks as longinteger) as string
    totalSeconds = int(ticks / 10000000)
    hours = stri(int(totalSeconds / 3600)).trim()
    minutes = stri(int((totalSeconds - (val(hours) * 3600)) / 60)).trim()
    seconds = stri(totalSeconds - (val(hours) * 3600) - (val(minutes) * 60)).trim()
    if val(hours) > 0 and val(minutes) < 10 then minutes = "0" + minutes
    if val(seconds) < 10 then seconds = "0" + seconds
    r = ""
    if val(hours) > 0 then r = hours + ":"
    r = r + minutes + ":" + seconds
    return r
end function

' Format time as 12 or 24 hour format based on system clock setting
function formatTime(time) as string
    hours = time.getHours()
    minHourDigits = 1
    di = CreateObject("roDeviceInfo")
    if di.GetClockFormat() = "12h"
        meridian = "AM"
        if hours = 0
            hours = 12
            meridian = "AM"
        else if hours = 12
            hours = 12
            meridian = "PM"
        else if hours > 12
            hours = hours - 12
            meridian = "PM"
        end if
    else
        ' For 24hr Clock, no meridian and pad hours to 2 digits
        minHourDigits = 2
        meridian = ""
    end if

    return Substitute("{0}:{1} {2}", leftPad(stri(hours).trim(), "0", minHourDigits), leftPad(stri(time.getMinutes()).trim(), "0", 2), meridian)

end function

function div_ceiling(a as integer, b as integer) as integer
    if a < b then return 1
    if int(a / b) = a / b
        return a / b
    end if
    return a / b + 1
end function

'Returns the item selected or -1 on backpress or other unhandled closure of dialog.
function get_dialog_result(dialog, port)
    while dialog <> invalid
        msg = wait(0, port)
        if isNodeEvent(msg, "backPressed")
            return -1
        else if isNodeEvent(msg, "itemSelected")
            return dialog.findNode("optionList").itemSelected
        end if
    end while
    'Dialog has closed outside of this loop, return -1 for failure
    return -1
end function

function lastFocusedChild(obj as object) as object
    if LCase(obj.focusedChild.focusedChild.subType()) = "tvepisodes"
        if isValid(obj?.focusedChild?.focusedChild?.lastFocus)
            return obj.focusedChild.focusedChild.lastFocus
        end if
    end if

    child = obj
    for i = 0 to obj.getChildCount()
        if obj.focusedChild <> invalid
            child = child.focusedChild
        end if
    end for
    return child
end function

function show_dialog(message as string, options = [], defaultSelection = 0) as integer
    lastFocus = lastFocusedChild(m.scene)

    dialog = createObject("roSGNode", "JFMessageDialog")
    if options.count() then dialog.options = options
    if message.len() > 0
        reg = CreateObject("roFontRegistry")
        font = reg.GetDefaultFont()
        dialog.fontHeight = font.GetOneLineHeight()
        dialog.fontWidth = font.GetOneLineWidth(message, 999999999)
        dialog.message = message
    end if

    if defaultSelection > 0
        dialog.findNode("optionList").jumpToItem = defaultSelection
    end if

    dialog.visible = true
    m.scene.appendChild(dialog)
    dialog.setFocus(true)

    port = CreateObject("roMessagePort")
    dialog.observeField("backPressed", port)
    dialog.findNode("optionList").observeField("itemSelected", port)

    result = get_dialog_result(dialog, port)

    m.scene.removeChildIndex(m.scene.getChildCount() - 1)
    lastFocus.setFocus(true)

    return result
end function

function message_dialog(message = "" as string)
    return show_dialog(message, ["OK"])
end function

function option_dialog(options, message = "", defaultSelection = 0) as integer
    return show_dialog(message, options, defaultSelection)
end function

'
' Take a jellyfin hostname and ensure it's a full url.
' prepend http or https and append default ports, and remove excess slashes
'
function standardize_jellyfin_url(url as string)
    'Append default ports
    maxSlashes = 0
    if left(url, 8) = "https://" or left(url, 7) = "http://"
        maxSlashes = 2
    end if
    'Check to make sure entry has no extra slashes before adding default ports.
    if Instr(0, url, "/") = maxSlashes
        if url.len() > 5 and mid(url, url.len() - 4, 1) <> ":" and mid(url, url.len() - 5, 1) <> ":"
            if left(url, 5) = "https"
                url = url + ":8920"
            else
                url = url + ":8096"
            end if
        end if
    end if
    'Append http:// to server
    if left(url, 4) <> "http"
        url = "http://" + url
    end if
    return url
end function

sub setFieldTextValue(field, value)
    node = m.top.findNode(field)
    if node = invalid or value = invalid then return

    ' Handle non strings... Which _shouldn't_ happen, but hey
    if type(value) = "roInt" or type(value) = "Integer"
        value = str(value).trim()
    else if type(value) = "roFloat" or type(value) = "Float"
        value = str(value).trim()
    else if type(value) <> "roString" and type(value) <> "String"
        value = ""
    end if

    node.text = value
end sub

' Returns whether or not passed value is valid
function isValid(input) as boolean
    return input <> invalid
end function

' Returns whether or not passed value is valid and not empty
' Accepts a string, or any countable type (arrays and lists)
function isValidAndNotEmpty(input) as boolean
    if not isValid(input) then return false
    ' Use roAssociativeArray instead of list so we get access to the doesExist() method
    countableTypes = { "array": 1, "list": 1, "roarray": 1, "roassociativearray": 1, "rolist": 1 }
    inputType = LCase(type(input))
    if inputType = "string" or inputType = "rostring"
        trimmedInput = input.trim()
        return trimmedInput <> ""
    else if countableTypes.doesExist(inputType)
        return input.count() > 0
    else
        print "Called isValidAndNotEmpty() with invalid type: ", inputType
        return false
    end if
end function

' Rounds number to nearest integer
function roundNumber(f as float) as integer
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

' Converts ticks to minutes
function getMinutes(ticks) as integer
    ' A tick is .1ms, so 1/10,000,000 for ticks to seconds,
    ' then 1/60 for seconds to minutes... 1/600,000,000
    return roundNumber(ticks / 600000000.0)
end function

'
' Returns whether or not a version number (e.g. 10.7.7) is greater or equal
' to some minimum version allowed (e.g. 10.8.0)
function versionChecker(versionToCheck as string, minVersionAccepted as string)
    leftHand = CreateObject("roLongInteger")
    rightHand = CreateObject("roLongInteger")

    regEx = CreateObject("roRegex", "\.", "")
    version = regEx.Split(versionToCheck)
    if version.Count() < 3
        for i = version.Count() to 3 step 1
            version.AddTail("0")
        end for
    end if

    minVersion = regEx.Split(minVersionAccepted)
    if minVersion.Count() < 3
        for i = minVersion.Count() to 3 step 1
            minVersion.AddTail("0")
        end for
    end if

    leftHand = (version[0].ToInt() * 10000) + (version[1].ToInt() * 100) + (version[2].ToInt() * 10)
    rightHand = (minVersion[0].ToInt() * 10000) + (minVersion[1].ToInt() * 100) + (minVersion[2].ToInt() * 10)

    return leftHand >= rightHand
end function

function findNodeBySubtype(node, subtype)
    foundNodes = []

    for each child in node.getChildren(-1, 0)
        if lcase(child.subtype()) = "group"
            return findNodeBySubtype(child, subtype)
        end if

        if lcase(child.subtype()) = lcase(subtype)
            foundNodes.push({
                node: child,
                parent: node
            })
        end if
    end for

    return foundNodes
end function

sub startLoadingSpinner()
    m.spinner = createObject("roSGNode", "Spinner")
    m.spinner.translation = "[900, 450]"
    m.scene.appendChild(m.spinner)
    dialog = createObject("roSGNode", "ProgressDialog")
    dialog.id = "invisibiledialog"
    dialog.visible = false
    m.scene.dialog = dialog
end sub

sub stopLoadingSpinner()
    if isValid(m.spinner)
        m.spinner.visible = false
    end if
    if isValid(m.scene.dialog)
        m.scene.dialog.close = true
    end if
end sub

sub playbackErrorDialog(node)
    dialog = createObject("roSGNode", "Dialog")
    dialog.title = tr("Error During Playback")
    dialog.buttons = [tr("OK")]
    dialog.message = tr("An error was encountered while playing this item.")
    dialog.visible = true
    m.scene.dialog = dialog
    port = CreateObject("roMessagePort")
    dialog.observeField("buttonSelected", port)
    wait(0, port)
    dialog.close = true
    m.spinner.visible = false
    node.control = "stop"
    node.backPressed = true
    'm.global.SceneManager.callFunc("popscene")
end sub

