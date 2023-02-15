sub init()
    m.top.functionName = "GetItemQueryTask"
end sub

sub getItemQueryTask()
    if not m.top.live = "true"
        m.getItemQueryTask = api_API().users.getitemsbyquery(get_setting("active_user"), {
            ids: m.top.videoID,
            fields: "Overview,People"
        })
    else
        m.getItemQueryTask = api_API().livetv.getprograms({
            channelIds: m.top.videoID,
            isAiring: "true",
            fields: "People,Overview"
        })
    end if
    m.top.getItemQueryData = m.getItemQueryTask
end sub

