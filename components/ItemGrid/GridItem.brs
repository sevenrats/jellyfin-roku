sub init()
    m.posterMask = m.top.findNode("posterMask")
    m.itemPoster = m.top.findNode("itemPoster")
    m.itemIcon = m.top.findNode("itemIcon")
    m.posterText = m.top.findNode("posterText")
    m.itemText = m.top.findNode("itemText")
    m.backdrop = m.top.findNode("backdrop")

    m.itemPoster.observeField("loadStatus", "onPosterLoadStatusChanged")

    m.unplayedCount = m.top.findNode("unplayedCount")
    m.unplayedEpisodeCount = m.top.findNode("unplayedEpisodeCount")

    m.itemText.translation = [0, m.itemPoster.height + 7]

    m.gridTitles = get_user_setting("itemgrid.gridTitles")
    m.itemText.visible = m.gridTitles = "showalways"

    ' Add some padding space when Item Titles are always showing
    if m.itemText.visible then m.itemText.maxWidth = 250

    'Parent is MarkupGrid and it's parent is the ItemGrid
    m.topParent = m.top.GetParent().GetParent()
    'Get the imageDisplayMode for these grid items
    if m.topParent.imageDisplayMode <> invalid
        m.itemPoster.loadDisplayMode = m.topParent.imageDisplayMode
    end if

end sub

sub itemContentChanged()

    ' Set Random background colors from pallet
    posterBackgrounds = m.global.constants.poster_bg_pallet
    m.backdrop.blendColor = posterBackgrounds[rnd(posterBackgrounds.count()) - 1]

    itemData = m.top.itemContent

    if itemData = invalid then return

    if itemData.type = "Movie"
        m.itemPoster.uri = itemData.PosterUrl
        m.itemIcon.uri = itemData.iconUrl
        m.itemText.text = itemData.Title
    else if itemData.type = "Series"
        if itemData?.json?.UserData?.UnplayedItemCount <> invalid
            if itemData.json.UserData.UnplayedItemCount > 0
                m.unplayedCount.visible = true
                m.unplayedEpisodeCount.text = itemData.json.UserData.UnplayedItemCount
            end if
        end if

        m.itemPoster.uri = itemData.PosterUrl
        m.itemIcon.uri = itemData.iconUrl
        m.itemText.text = itemData.Title
    else if itemData.type = "Boxset"
        m.itemPoster.uri = itemData.PosterUrl
        m.itemIcon.uri = itemData.iconUrl
        m.itemText.text = itemData.Title
    else if itemData.type = "TvChannel"
        m.itemPoster.uri = itemData.PosterUrl
        m.itemIcon.uri = itemData.iconUrl
        m.itemText.text = itemData.Title
    else if itemData.type = "Folder"
        m.itemPoster.uri = itemData.PosterUrl
        'm.itemIcon.uri = itemData.iconUrl
        m.itemText.text = itemData.Title
        m.itemPoster.loadDisplayMode = m.topParent.imageDisplayMode
    else if itemData.type = "Video"
        m.itemPoster.uri = itemData.PosterUrl
        m.itemIcon.uri = itemData.iconUrl
        m.itemText.text = itemData.Title
    else if itemData.type = "Photo"
        m.itemPoster.uri = itemData.PosterUrl
        m.itemIcon.uri = itemData.iconUrl
        m.itemText.text = itemData.Title
    else if itemData.type = "Episode"
        m.itemPoster.uri = itemData.PosterUrl
        m.itemIcon.uri = itemData.iconUrl
        m.itemText.text = itemData.json.SeriesName + " - " + itemData.Title
    else if itemData.type = "MusicArtist"
        m.itemPoster.uri = itemData.PosterUrl
        m.itemText.text = itemData.Title

        m.itemPoster.height = 290
        m.itemPoster.width = 290

        m.itemText.translation = [0, m.itemPoster.height + 7]

        m.backdrop.height = 290
        m.backdrop.width = 290

        m.posterText.height = 200
        m.posterText.width = 280
    else if itemData.json.type = "MusicAlbum"
        m.itemPoster.uri = itemData.PosterUrl
        m.itemText.text = itemData.Title

        m.itemPoster.height = 290
        m.itemPoster.width = 290

        m.itemText.translation = [0, m.itemPoster.height + 7]

        m.backdrop.height = 290
        m.backdrop.width = 290

        m.posterText.height = 200
        m.posterText.width = 280
    else
        print "Unhandled Grid Item Type: " + itemData.type
    end if

    'If Poster not loaded, ensure "blue box" is shown until loaded
    if m.itemPoster.loadStatus <> "ready"
        m.backdrop.visible = true
        m.posterText.visible = true
    end if

    m.posterText.text = m.itemText.text

end sub

'
'Use FocusPercent to animate scaling of Poser Image
sub focusChanging()
    scaleFactor = 0.85 + (m.top.focusPercent * 0.15)
    m.posterMask.scale = [scaleFactor, scaleFactor]
end sub

'
'Display or hide title Visibility on focus change
sub focusChanged()
    if m.top.itemHasFocus = true
        m.itemText.repeatCount = -1
        m.posterMask.scale = [1, 1]
    else
        m.itemText.repeatCount = 0
        if m.topParent.alphaActive = true
            m.posterMask.scale = [0.85, 0.85]
        end if
    end if
    if m.gridTitles = "showonhover"
        m.itemText.visible = m.top.itemHasFocus
    end if
end sub

'Hide backdrop and text when poster loaded
sub onPosterLoadStatusChanged()
    if m.itemPoster.loadStatus = "ready"
        m.backdrop.visible = false
        m.posterText.visible = false
    end if
end sub
