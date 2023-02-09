function onKeyEvent(key as string, press as boolean) as boolean

    if press and key = "OK"
        m.top.getParent().focusedChild.focusedChild.control = "resume"
        m.top.close = true
        return true
    end if

    return false
end function
