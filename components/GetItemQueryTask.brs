sub init()
    m.top.functionName = "GetItemQueryTask"
end sub

sub getItemQueryTask()
    if m.top.live = "true"
        m.getItemQueryTask = api_API().users.getitemsbyquery(get_setting("active_user"), {
            ids: m.top.videoID,
            fields: "Overview,People"
        })
    else
        m.getItemQueryTask = api_API().users.getprogramsbyquery({
            channelIds: m.top.videoID,
            isAiring: "true"
        })
    end if
    m.top.getItemQueryData = m.getItemQueryTask
end sub

