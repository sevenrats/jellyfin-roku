import "pkg:/source/utils/misc.brs"
import "pkg:/source/api/baserequest.brs"

'Device Capabilities for Roku.
'This will likely need further tweaking
function getDeviceCapabilities() as object

    return {
        "PlayableMediaTypes": [
            "Audio",
            "Video",
            "Photo"
        ],
        "SupportedCommands": [],
        "SupportsPersistentIdentifier": false,
        "SupportsMediaControl": false,
        "SupportsContentUploading": false,
        "SupportsSync": false,
        "DeviceProfile": getDeviceProfile(),
        "AppStoreUrl": "https://channelstore.roku.com/details/cc5e559d08d9ec87c5f30dcebdeebc12/jellyfin"
    }
end function

' Send Device Profile information to server
sub PostDeviceProfile()
    profile = getDeviceCapabilities()
    req = APIRequest("/Sessions/Capabilities/Full")
    req.SetRequest("POST")
    print "profile =", profile
    print "profile.DeviceProfile =", profile.DeviceProfile
    print "profile.DeviceProfile.CodecProfiles ="
    for each prof in profile.DeviceProfile.CodecProfiles
        print prof
        for each cond in prof.Conditions
            print cond
        end for
    end for
    print "profile.DeviceProfile.ContainerProfiles =", profile.DeviceProfile.ContainerProfiles
    print "profile.DeviceProfile.DirectPlayProfiles ="
    for each prof in profile.DeviceProfile.DirectPlayProfiles
        print prof
    end for
    print "profile.DeviceProfile.SubtitleProfiles ="
    for each prof in profile.DeviceProfile.SubtitleProfiles
        print prof
    end for
    print "profile.DeviceProfile.TranscodingProfiles ="
    for each prof in profile.DeviceProfile.TranscodingProfiles
        print prof
        if isValid(prof.Conditions)
            for each condition in prof.Conditions
                print condition
            end for
        end if
    end for
    print "profile.PlayableMediaTypes =", profile.PlayableMediaTypes
    print "profile.SupportedCommands =", profile.SupportedCommands
    postJson(req, FormatJson(profile))
end sub

function getDeviceProfile() as object
    return {
        "Name": "Official Roku Client",
        "Id": m.global.device.id,
        "Identification": {
            "FriendlyName": m.global.device.friendlyName,
            "ModelNumber": m.global.device.model,
            "SerialNumber": "string",
            "ModelName": m.global.device.name,
            "ModelDescription": "Type: " + m.global.device.modelType,
            "Manufacturer": m.global.device.modelDetails.VendorName
        },
        "FriendlyName": m.global.device.friendlyName,
        "Manufacturer": m.global.device.modelDetails.VendorName,
        "ModelName": m.global.device.name,
        "ModelDescription": "Type: " + m.global.device.modelType,
        "ModelNumber": m.global.device.model,
        "SerialNumber": m.global.device.serial,
        "MaxStreamingBitrate": 120000000,
        "MaxStaticBitrate": 100000000,
        "MusicStreamingTranscodingBitrate": 192000,
        "DirectPlayProfiles": GetDirectPlayProfiles(),
        "TranscodingProfiles": getTranscodingProfiles(),
        "ContainerProfiles": getContainerProfiles(),
        "CodecProfiles": getCodecProfiles(),
        "SubtitleProfiles": getSubtitleProfiles()
    }
end function

function GetDirectPlayProfiles() as object
    directPlayProfiles = []
    di = CreateObject("roDeviceInfo")
    ' all possible containers
    supportedCodecs = {
        mp4: {
            audio: [],
            video: []
        },
        hls: {
            audio: [],
            video: []
        },
        mkv: {
            audio: [],
            video: []
        },
        ism: {
            audio: [],
            video: []
        },
        dash: {
            audio: [],
            video: []
        },
        ts: {
            audio: [],
            video: []
        }
    }
    ' all possible codecs (besides those restricted by user settings)
    videoCodecs = ["h264", "mpeg4 avc", "vp8", "vp9", "h263", "mpeg1"]
    audioCodecs = ["mp3", "mp2", "pcm", "lpcm", "wav", "ac3", "ac4", "aiff", "wma", "flac", "alac", "aac", "opus", "dts", "wmapro", "vorbis", "eac3", "mpg123"]

    ' only try to direct play av1 if asked
    if m.global.session.user.settings["playback.av1"]
        videoCodecs.push("av1")
    end if

    ' check if hevc is disabled
    if m.global.session.user.settings["playback.compatibility.disablehevc"] = false
        videoCodecs.push("hevc")
    end if

    ' check video codecs for each container
    for each container in supportedCodecs
        for each videoCodec in videoCodecs
            if di.CanDecodeVideo({ Codec: videoCodec, Container: container }).Result
                if videoCodec = "hevc"
                    supportedCodecs[container]["video"].push("hevc")
                    supportedCodecs[container]["video"].push("h265")
                else
                    ' device profile string matches codec string
                    supportedCodecs[container]["video"].push(videoCodec)
                end if
            end if
        end for
    end for

    ' user setting overrides
    if m.global.session.user.settings["playback.mpeg4"]
        for each container in supportedCodecs
            supportedCodecs[container]["video"].push("mpeg4")
        end for
    end if
    if m.global.session.user.settings["playback.mpeg2"]
        for each container in supportedCodecs
            supportedCodecs[container]["video"].push("mpeg2video")
        end for
    end if

    ' check audio codecs for each container
    for each container in supportedCodecs
        for each audioCodec in audioCodecs
            if di.CanDecodeAudio({ Codec: audioCodec, Container: container }).Result
                supportedCodecs[container]["audio"].push(audioCodec)
            end if
        end for
    end for

    ' check audio codecs with no container
    supportedAudio = []
    for each audioCodec in audioCodecs
        if di.CanDecodeAudio({ Codec: audioCodec }).Result
            supportedAudio.push(audioCodec)
        end if
    end for

    ' build return array
    for each container in supportedCodecs
        videoCodecString = supportedCodecs[container]["video"].Join(",")
        if videoCodecString <> ""
            containerString = container

            if container = "mp4"
                containerString = "mp4,mov,m4v"
            else if container = "mkv"
                containerString = "mkv,webm"
            end if

            directPlayProfiles.push({
                "Container": containerString,
                "Type": "Video",
                "VideoCodec": videoCodecString,
                "AudioCodec": supportedCodecs[container]["audio"].Join(",")
            })
        end if
    end for

    directPlayProfiles.push({
        "Container": supportedAudio.Join(","),
        "Type": "Audio"
    })
    return directPlayProfiles
end function

function getTranscodingProfiles() as object
    transcodingProfiles = []

    di = CreateObject("roDeviceInfo")

    transcodingContainers = ["mp4", "ts"]
    ' use strings to preserve order
    mp4AudioCodecs = "aac"
    mp4VideoCodecs = "h264"
    tsAudioCodecs = "aac"
    tsVideoCodecs = "h264"

    ' does the users setup support surround sound?
    maxAudioChannels = "2" ' jellyfin expects this as a string
    ' in order of preference from left to right
    audioCodecs = ["mp3", "vorbis", "opus", "flac", "alac", "ac4", "pcm", "wma", "wmapro"]
    surroundSoundCodecs = ["eac3", "ac3", "dts"]
    if m.global.session.user.settings["playback.forceDTS"] = true
        surroundSoundCodecs = ["dts", "eac3", "ac3"]
    end if

    surroundSoundCodec = invalid
    if di.GetAudioOutputChannel() = "5.1 surround"
        maxAudioChannels = "6"
        for each codec in surroundSoundCodecs
            if di.CanDecodeAudio({ Codec: codec, ChCnt: 6 }).Result
                surroundSoundCodec = codec
                if di.CanDecodeAudio({ Codec: codec, ChCnt: 8 }).Result
                    maxAudioChannels = "8"
                end if
                exit for
            end if
        end for
    end if

    ' VIDEO CODECS
    '
    ' AVC / h264 / MPEG4 AVC
    for each container in transcodingContainers
        if di.CanDecodeVideo({ Codec: "h264", Container: container }).Result
            if container = "mp4"
                ' check for codec string before adding it
                if mp4VideoCodecs.Instr(0, ",h264") = -1
                    mp4VideoCodecs = mp4VideoCodecs + ",h264"
                end if
            else if container = "ts"
                ' check for codec string before adding it
                if tsVideoCodecs.Instr(0, ",h264") = -1
                    tsVideoCodecs = tsVideoCodecs + ",h264"
                end if
            end if
        end if
        if di.CanDecodeVideo({ Codec: "mpeg4 avc", Container: container }).Result
            if container = "mp4"
                ' check for codec string before adding it
                if mp4VideoCodecs.Instr(0, ",mpeg4 avc") = -1
                    mp4VideoCodecs = mp4VideoCodecs + ",mpeg4 avc"
                end if
            else if container = "ts"
                ' check for codec string before adding it
                if tsVideoCodecs.Instr(0, ",mpeg4 avc") = -1
                    tsVideoCodecs = tsVideoCodecs + ",mpeg4 avc"
                end if
            end if
        end if
    end for

    ' HEVC / h265
    if m.global.session.user.settings["playback.compatibility.disablehevc"] = false
        for each container in transcodingContainers
            if di.CanDecodeVideo({ Codec: "hevc", Container: container }).Result
                if container = "mp4"
                    ' check for codec string before adding it
                    if mp4VideoCodecs.Instr(0, "h265,") = -1
                        mp4VideoCodecs = "h265," + mp4VideoCodecs
                    end if
                    if mp4VideoCodecs.Instr(0, "hevc,") = -1
                        mp4VideoCodecs = "hevc," + mp4VideoCodecs
                    end if
                else if container = "ts"
                    ' check for codec string before adding it
                    if tsVideoCodecs.Instr(0, "h265,") = -1
                        tsVideoCodecs = "h265," + tsVideoCodecs
                    end if
                    if tsVideoCodecs.Instr(0, "hevc,") = -1
                        tsVideoCodecs = "hevc," + tsVideoCodecs
                    end if
                end if
            end if
        end for
    end if

    ' VP9
    for each container in transcodingContainers
        if di.CanDecodeAudio({ Codec: "vp9", Container: container }).Result
            if container = "mp4"
                ' check for codec string before adding it
                if mp4VideoCodecs.Instr(0, ",vp9") = -1
                    mp4VideoCodecs = mp4VideoCodecs + ",vp9"
                end if
            else if container = "ts"
                ' check for codec string before adding it
                if tsVideoCodecs.Instr(0, ",vp9") = -1
                    tsVideoCodecs = tsVideoCodecs + ",vp9"
                end if
            end if
        end if
    end for

    ' MPEG2
    if m.global.session.user.settings["playback.mpeg2"]
        for each container in transcodingContainers
            if di.CanDecodeVideo({ Codec: "mpeg2", Container: container }).Result
                if container = "mp4"
                    ' check for codec string before adding it
                    if mp4VideoCodecs.Instr(0, ",mpeg2video") = -1
                        mp4VideoCodecs = mp4VideoCodecs + ",mpeg2video"
                    end if
                else if container = "ts"
                    ' check for codec string before adding it
                    if tsVideoCodecs.Instr(0, ",mpeg2video") = -1
                        tsVideoCodecs = tsVideoCodecs + ",mpeg2video"
                    end if
                end if
            end if
        end for
    end if

    ' AV1
    for each container in transcodingContainers
        if di.CanDecodeVideo({ Codec: "av1", Container: container }).Result
            if container = "mp4"
                ' check for codec string before adding it
                if mp4VideoCodecs.Instr(0, ",av1") = -1
                    mp4VideoCodecs = mp4VideoCodecs + ",av1"
                end if
            else if container = "ts"
                ' check for codec string before adding it
                if tsVideoCodecs.Instr(0, ",av1") = -1
                    tsVideoCodecs = tsVideoCodecs + ",av1"
                end if
            end if
        end if
    end for

    ' AUDIO CODECS
    for each container in transcodingContainers
        for each codec in audioCodecs
            if di.CanDecodeAudio({ Codec: codec, Container: container }).result
                if container = "mp4"
                    mp4AudioCodecs = mp4AudioCodecs + "," + codec
                else if container = "ts"
                    tsAudioCodecs = tsAudioCodecs + "," + codec
                end if
            end if
        end for
    end for

    ' add mp3 to TranscodingProfile for music
    transcodingProfiles.push({
        "Container": "mp3",
        "Type": "Audio",
        "AudioCodec": "mp3",
        "Context": "Streaming",
        "Protocol": "http",
        "MaxAudioChannels": maxAudioChannels
    })
    transcodingProfiles.push({
        "Container": "mp3",
        "Type": "Audio",
        "AudioCodec": "mp3",
        "Context": "Static",
        "Protocol": "http",
        "MaxAudioChannels": maxAudioChannels
    })
    ' add aac to TranscodingProfile for stereo audio
    ' NOTE: multichannel aac is not supported. only decode to stereo on some devices
    transcodingProfiles.push({
        "Container": "ts",
        "Type": "Audio",
        "AudioCodec": "aac",
        "Context": "Streaming",
        "Protocol": "http",
        "MaxAudioChannels": "2"
    })
    transcodingProfiles.push({
        "Container": "ts",
        "Type": "Audio",
        "AudioCodec": "aac",
        "Context": "Static",
        "Protocol": "http",
        "MaxAudioChannels": "2"
    })

    tsArray = {
        "Container": "ts",
        "Context": "Streaming",
        "Protocol": "hls",
        "Type": "Video",
        "AudioCodec": tsAudioCodecs,
        "VideoCodec": tsVideoCodecs,
        "MaxAudioChannels": maxAudioChannels,
        "MinSegments": 1,
        "BreakOnNonKeyFrames": false
    }
    mp4Array = {
        "Container": "mp4",
        "Context": "Streaming",
        "Protocol": "hls",
        "Type": "Video",
        "AudioCodec": mp4AudioCodecs,
        "VideoCodec": mp4VideoCodecs,
        "MaxAudioChannels": maxAudioChannels,
        "MinSegments": 1,
        "BreakOnNonKeyFrames": false
    }

    ' apply max res to transcoding profile
    if m.global.session.user.settings["playback.resolution.max"] <> "off"
        tsArray.Conditions = [getMaxHeightArray(), getMaxWidthArray()]
        mp4Array.Conditions = [getMaxHeightArray(), getMaxWidthArray()]
    end if

    ' surround sound
    if surroundSoundCodec <> invalid
        ' add preferred surround sound codec to TranscodingProfile
        transcodingProfiles.push({
            "Container": surroundSoundCodec,
            "Type": "Audio",
            "AudioCodec": surroundSoundCodec,
            "Context": "Streaming",
            "Protocol": "http",
            "MaxAudioChannels": maxAudioChannels
        })
        transcodingProfiles.push({
            "Container": surroundSoundCodec,
            "Type": "Audio",
            "AudioCodec": surroundSoundCodec,
            "Context": "Static",
            "Protocol": "http",
            "MaxAudioChannels": maxAudioChannels
        })

        ' put codec in front of AudioCodec string
        if tsArray.AudioCodec = ""
            tsArray.AudioCodec = surroundSoundCodec
        else
            tsArray.AudioCodec = surroundSoundCodec + "," + tsArray.AudioCodec
        end if

        if mp4Array.AudioCodec = ""
            mp4Array.AudioCodec = surroundSoundCodec
        else
            mp4Array.AudioCodec = surroundSoundCodec + "," + mp4Array.AudioCodec
        end if
    end if

    transcodingProfiles.push(tsArray)
    transcodingProfiles.push(mp4Array)

    return transcodingProfiles
end function

function getContainerProfiles() as object
    containerProfiles = []

    return containerProfiles
end function

function getCodecProfiles() as object
    codecProfiles = []
    profileSupport = {
        "h264": {},
        "mpeg4 avc": {},
        "h265": {},
        "hevc": {},
        "vp9": {},
        "mpeg2": {},
        "av1": {}
    }
    maxResSetting = m.global.session.user.settings["playback.resolution.max"]
    di = CreateObject("roDeviceInfo")
    maxHeightArray = getMaxHeightArray()
    maxWidthArray = getMaxWidthArray()

    ' AUDIO
    ' test each codec to see how many channels are supported
    audioCodecs = ["aac", "mp3", "mp2", "opus", "pcm", "lpcm", "wav", "flac", "alac", "ac3", "ac4", "aiff", "dts", "wmapro", "vorbis", "eac3", "mpg123"]
    audioChannels = [8, 6, 2] ' highest first
    for each audioCodec in audioCodecs
        for each audioChannel in audioChannels
            channelSupportFound = false
            if di.CanDecodeAudio({ Codec: audioCodec, ChCnt: audioChannel }).Result
                channelSupportFound = true
                for each codecType in ["VideoAudio", "Audio"]
                    codecProfiles.push({
                        "Type": codecType,
                        "Codec": audioCodec,
                        "Conditions": [
                            {
                                "Condition": "LessThanEqual",
                                "Property": "AudioChannels",
                                "Value": audioChannel,
                                "IsRequired": true
                            }
                        ]
                    })

                end for
            end if
            if channelSupportFound
                ' if 8 channels are supported we don't need to test for 6 or 2
                ' if 6 channels are supported we don't need to test 2
                exit for
            end if
        end for
    end for

    ' check device for codec profile and level support
    ' AVC / h264 / MPEG4 AVC
    h264Profiles = ["main", "high"]
    h264Levels = ["4.1", "4.2"]
    for each profile in h264Profiles
        for each level in h264Levels
            if di.CanDecodeVideo({ Codec: "h264", Profile: profile, Level: level }).Result
                profileSupport = updateProfileArray(profileSupport, "h264", profile, level)
            end if
            if di.CanDecodeVideo({ Codec: "mpeg4 avc", Profile: profile, Level: level }).Result
                profileSupport = updateProfileArray(profileSupport, "mpeg4 avc", profile, level)
            end if
        end for
    end for

    ' HEVC / h265
    hevcProfiles = ["main", "main 10"]
    hevcLevels = ["4.1", "5.0", "5.1"]
    for each profile in hevcProfiles
        for each level in hevcLevels
            if di.CanDecodeVideo({ Codec: "hevc", Profile: profile, Level: level }).Result
                profileSupport = updateProfileArray(profileSupport, "h265", profile, level)
                profileSupport = updateProfileArray(profileSupport, "hevc", profile, level)
            end if
        end for
    end for

    ' VP9
    vp9Profiles = ["profile 0", "profile 2"]
    vp9Levels = ["4.1", "5.0", "5.1"]
    for each profile in vp9Profiles
        for each level in vp9Levels
            if di.CanDecodeVideo({ Codec: "vp9", Profile: profile, Level: level }).Result
                profileSupport = updateProfileArray(profileSupport, "vp9", profile, level)
            end if
        end for
    end for

    ' MPEG2
    ' mpeg2 uses levels with no profiles. see https://developer.roku.com/en-ca/docs/references/brightscript/interfaces/ifdeviceinfo.md#candecodevideovideo_format-as-object-as-object
    ' NOTE: the mpeg2 levels are being saved in the profileSupport array as if they were profiles
    mpeg2Levels = ["main", "high"]
    for each level in mpeg2Levels
        if di.CanDecodeVideo({ Codec: "mpeg2", Level: level }).Result
            profileSupport = updateProfileArray(profileSupport, "mpeg2", level)
        end if
    end for

    ' AV1
    av1Profiles = ["main", "main 10"]
    av1Levels = ["4.1", "5.0", "5.1"]
    for each profile in av1Profiles
        for each level in av1Levels
            if di.CanDecodeVideo({ Codec: "av1", Profile: profile, Level: level }).Result
                profileSupport = updateProfileArray(profileSupport, "av1", profile, level)
            end if
        end for
    end for

    ' HDR SUPPORT
    h264VideoRangeTypes = "SDR"
    hevcVideoRangeTypes = "SDR"
    vp9VideoRangeTypes = "SDR"
    av1VideoRangeTypes = "SDR"

    dp = di.GetDisplayProperties()
    if dp.Hdr10
        hevcVideoRangeTypes = hevcVideoRangeTypes + "|HDR10"
        vp9VideoRangeTypes = vp9VideoRangeTypes + "|HDR10"
        av1VideoRangeTypes = av1VideoRangeTypes + "|HDR10"
    end if
    if dp.Hdr10Plus
        av1VideoRangeTypes = av1VideoRangeTypes + "|HDR10+"
    end if
    if dp.HLG
        hevcVideoRangeTypes = hevcVideoRangeTypes + "|HLG"
        vp9VideoRangeTypes = vp9VideoRangeTypes + "|HLG"
        av1VideoRangeTypes = av1VideoRangeTypes + "|HLG"
    end if
    if dp.DolbyVision
        h264VideoRangeTypes = h264VideoRangeTypes + "|DOVI"
        hevcVideoRangeTypes = hevcVideoRangeTypes + "|DOVI"
        'vp9VideoRangeTypes = vp9VideoRangeTypes + ",DOVI" no evidence that vp9 can hold DOVI
        av1VideoRangeTypes = av1VideoRangeTypes + "|DOVI"
    end if

    ' H264
    h264LevelSupported = 0.0
    h264AssProfiles = {}
    for each profile in profileSupport["h264"]
        h264AssProfiles.AddReplace(profile, true)
        for each level in profileSupport["h264"][profile]
            levelFloat = level.ToFloat()
            if levelFloat > h264LevelSupported
                h264LevelSupported = levelFloat
            end if
        end for
    end for

    ' convert to string
    h264LevelString = h264LevelSupported.ToStr()
    ' remove decimals
    h264LevelString = removeDecimals(h264LevelString)

    h264ProfileArray = {
        "Type": "Video",
        "Codec": "h264",
        "Conditions": [
            {
                "Condition": "NotEquals",
                "Property": "IsAnamorphic",
                "Value": "true",
                "IsRequired": false
            },
            {
                "Condition": "LessThanEqual",
                "Property": "VideoBitDepth",
                "Value": "8",
                "IsRequired": false
            },
            {
                "Condition": "EqualsAny",
                "Property": "VideoProfile",
                "Value": h264AssProfiles.Keys().join("|"),
                "IsRequired": false
            },
            {
                "Condition": "EqualsAny",
                "Property": "VideoRangeType",
                "Value": h264VideoRangeTypes,
                "IsRequired": false
            }

        ]
    }

    ' check user setting before adding video level restrictions
    if not m.global.session.user.settings["playback.tryDirect.h264ProfileLevel"]
        h264ProfileArray.Conditions.push({
            "Condition": "LessThanEqual",
            "Property": "VideoLevel",
            "Value": h264LevelString,
            "IsRequired": false
        })
    end if

    ' set max resolution
    if m.global.session.user.settings["playback.resolution.mode"] = "everything" and maxResSetting <> "off"
        h264ProfileArray.Conditions.push(maxHeightArray)
        h264ProfileArray.Conditions.push(maxWidthArray)
    end if

    ' set bitrate restrictions based on user settings
    bitRateArray = GetBitRateLimit("h264")
    if bitRateArray.count() > 0
        h264ProfileArray.Conditions.push(bitRateArray)
    end if

    codecProfiles.push(h264ProfileArray)

    ' MPEG2
    ' NOTE: the mpeg2 levels are being saved in the profileSupport array as if they were profiles
    if m.global.session.user.settings["playback.mpeg2"]
        mpeg2Levels = []
        for each container in profileSupport
            for each level in profileSupport[container]["mpeg2"]
                if not arrayHasValue(mpeg2Levels, level)
                    mpeg2Levels.push(level)
                end if
            end for
        end for

        mpeg2ProfileArray = {
            "Type": "Video",
            "Codec": "mpeg2",
            "Conditions": [
                {
                    "Condition": "EqualsAny",
                    "Property": "VideoLevel",
                    "Value": mpeg2Levels.join("|"),
                    "IsRequired": false
                }
            ]
        }

        ' set max resolution
        if m.global.session.user.settings["playback.resolution.mode"] = "everything" and maxResSetting <> "off"
            mpeg2ProfileArray.Conditions.push(maxHeightArray)
            mpeg2ProfileArray.Conditions.push(maxWidthArray)
        end if

        ' set bitrate restrictions based on user settings
        bitRateArray = GetBitRateLimit("mpeg2")
        if bitRateArray.count() > 0
            mpeg2ProfileArray.Conditions.push(bitRateArray)
        end if

        codecProfiles.push(mpeg2ProfileArray)
    end if

    if di.CanDecodeVideo({ Codec: "av1" }).Result
        av1LevelSupported = 0.0
        av1AssProfiles = {}
        for each profile in profileSupport["av1"]
            av1AssProfiles.AddReplace(profile, true)
            for each level in profileSupport["av1"][profile]
                levelFloat = level.ToFloat()
                if levelFloat > av1LevelSupported
                    av1LevelSupported = levelFloat
                end if
            end for
        end for

        av1ProfileArray = {
            "Type": "Video",
            "Codec": "av1",
            "Conditions": [
                {
                    "Condition": "EqualsAny",
                    "Property": "VideoProfile",
                    "Value": av1AssProfiles.Keys().join("|"),
                    "IsRequired": false
                },
                {
                    "Condition": "EqualsAny",
                    "Property": "VideoRangeType",
                    "Value": av1VideoRangeTypes,
                    "IsRequired": false
                },
                {
                    "Condition": "LessThanEqual",
                    "Property": "VideoLevel",
                    "Value": (120 * av1LevelSupported).ToStr(),
                    "IsRequired": false
                }
            ]
        }

        ' set max resolution
        if m.global.session.user.settings["playback.resolution.mode"] = "everything" and maxResSetting <> "off"
            av1ProfileArray.Conditions.push(maxHeightArray)
            av1ProfileArray.Conditions.push(maxWidthArray)
        end if

        ' set bitrate restrictions based on user settings
        bitRateArray = GetBitRateLimit("av1")
        if bitRateArray.count() > 0
            av1ProfileArray.Conditions.push(bitRateArray)
        end if

        codecProfiles.push(av1ProfileArray)
    end if

    if not m.global.session.user.settings["playback.compatibility.disablehevc"] and di.CanDecodeVideo({ Codec: "hevc" }).Result
        hevcLevelSupported = 0.0
        hevcAssProfiles = {}
        print "profileSupport[hevc]", profileSupport["hevc"]
        for each profile in profileSupport["hevc"]
            hevcAssProfiles.AddReplace(profile, true)
            for each level in profileSupport["hevc"][profile]
                levelFloat = level.ToFloat()
                if levelFloat > hevcLevelSupported
                    hevcLevelSupported = levelFloat
                end if
            end for
        end for

        hevcLevelString = "120"
        if hevcLevelSupported = 5.1
            hevcLevelString = "153"
        end if

        hevcProfileArray = {
            "Type": "Video",
            "Codec": "hevc",
            "Conditions": [
                {
                    "Condition": "NotEquals",
                    "Property": "IsAnamorphic",
                    "Value": "true",
                    "IsRequired": false
                },
                {
                    "Condition": "EqualsAny",
                    "Property": "VideoProfile",
                    "Value": profileSupport["hevc"].Keys().join("|"),
                    "IsRequired": false
                },
                {
                    "Condition": "EqualsAny",
                    "Property": "VideoRangeType",
                    "Value": hevcVideoRangeTypes,
                    "IsRequired": false
                }
            ]
        }

        ' check user setting before adding VideoLevel restrictions
        if not m.global.session.user.settings["playback.tryDirect.hevcProfileLevel"]
            hevcProfileArray.Conditions.push({
                "Condition": "LessThanEqual",
                "Property": "VideoLevel",
                "Value": hevcLevelString,
                "IsRequired": false
            })
        end if

        ' set max resolution
        if m.global.session.user.settings["playback.resolution.mode"] = "everything" and maxResSetting <> "off"
            hevcProfileArray.Conditions.push(maxHeightArray)
            hevcProfileArray.Conditions.push(maxWidthArray)
        end if

        ' set bitrate restrictions based on user settings
        bitRateArray = GetBitRateLimit("h265")
        if bitRateArray.count() > 0
            hevcProfileArray.Conditions.push(bitRateArray)
        end if

        codecProfiles.push(hevcProfileArray)
    end if

    if di.CanDecodeVideo({ Codec: "vp9" }).Result
        vp9Profiles = []
        vp9LevelSupported = 0.0

        for each profile in profileSupport["vp9"]
            vp9Profiles.push(profile)
            for each level in profileSupport["vp9"][profile]
                levelFloat = level.ToFloat()
                if levelFloat > vp9LevelSupported
                    vp9LevelSupported = levelFloat
                end if
            end for
        end for

        vp9LevelString = "120"
        if vp9LevelSupported = 5.1
            vp9LevelString = "153"
        end if

        vp9ProfileArray = {
            "Type": "Video",
            "Codec": "vp9",
            "Conditions": [
                {
                    "Condition": "EqualsAny",
                    "Property": "VideoProfile",
                    "Value": vp9Profiles.join("|"),
                    "IsRequired": false
                },
                {
                    "Condition": "EqualsAny",
                    "Property": "VideoRangeType",
                    "Value": vp9VideoRangeTypes,
                    "IsRequired": false
                },
                {
                    "Condition": "LessThanEqual",
                    "Property": "VideoLevel",
                    "Value": vp9LevelString,
                    "IsRequired": false
                }
            ]
        }

        ' set max resolution
        if m.global.session.user.settings["playback.resolution.mode"] = "everything" and maxResSetting <> "off"
            vp9ProfileArray.Conditions.push(maxHeightArray)
            vp9ProfileArray.Conditions.push(maxWidthArray)
        end if

        ' set bitrate restrictions based on user settings
        bitRateArray = GetBitRateLimit("vp9")
        if bitRateArray.count() > 0
            vp9ProfileArray.Conditions.push(bitRateArray)
        end if

        codecProfiles.push(vp9ProfileArray)
    end if

    return codecProfiles
end function

function getSubtitleProfiles() as object
    subtitleProfiles = []

    subtitleProfiles.push({
        "Format": "vtt",
        "Method": "External"
    })
    subtitleProfiles.push({
        "Format": "srt",
        "Method": "External"
    })
    subtitleProfiles.push({
        "Format": "ttml",
        "Method": "External"
    })
    subtitleProfiles.push({
        "Format": "sub",
        "Method": "External"
    })

    return subtitleProfiles
end function

function GetBitRateLimit(codec as string) as object
    if m.global.session.user.settings["playback.bitrate.maxlimited"] = true
        userSetLimit = m.global.session.user.settings["playback.bitrate.limit"].ToInt()
        if isValid(userSetLimit) and type(userSetLimit) = "Integer" and userSetLimit > 0
            userSetLimit *= 1000000
            return {
                "Condition": "LessThanEqual",
                "Property": "VideoBitrate",
                "Value": userSetLimit.ToStr(),
                "IsRequired": true
            }
        else
            codec = Lcase(codec)
            ' Some repeated values (e.g. same "40mbps" for several codecs)
            ' but this makes it easy to update in the future if the bitrates start to deviate.
            if codec = "h264"
                ' Roku only supports h264 up to 10Mpbs
                return {
                    "Condition": "LessThanEqual",
                    "Property": "VideoBitrate",
                    "Value": "10000000",
                    "IsRequired": true
                }
            else if codec = "av1"
                ' Roku only supports AV1 up to 40Mpbs
                return {
                    "Condition": "LessThanEqual",
                    "Property": "VideoBitrate",
                    "Value": "40000000",
                    "IsRequired": true
                }
            else if codec = "h265"
                ' Roku only supports h265 up to 40Mpbs
                return {
                    "Condition": "LessThanEqual",
                    "Property": "VideoBitrate",
                    "Value": "40000000",
                    "IsRequired": true
                }
            else if codec = "vp9"
                ' Roku only supports VP9 up to 40Mpbs
                return {
                    "Condition": "LessThanEqual",
                    "Property": "VideoBitrate",
                    "Value": "40000000",
                    "IsRequired": true
                }
            end if
        end if
    end if
    return {}
end function

function getMaxHeightArray() as object
    maxResSetting = m.global.session.user.settings["playback.resolution.max"]
    if maxResSetting = "off" then return {}

    maxVideoHeight = maxResSetting

    if maxResSetting = "auto"
        maxVideoHeight = m.global.device.videoHeight
    end if

    return {
        "Condition": "LessThanEqual",
        "Property": "Height",
        "Value": maxVideoHeight,
        "IsRequired": true
    }
end function

function getMaxWidthArray() as object
    maxResSetting = m.global.session.user.settings["playback.resolution.max"]
    if maxResSetting = "off" then return {}

    maxVideoWidth = invalid

    if maxResSetting = "auto"
        maxVideoWidth = m.global.device.videoWidth
    else if maxResSetting = "360"
        maxVideoWidth = "480"
    else if maxResSetting = "480"
        maxVideoWidth = "640"
    else if maxResSetting = "720"
        maxVideoWidth = "1280"
    else if maxResSetting = "1080"
        maxVideoWidth = "1920"
    else if maxResSetting = "2160"
        maxVideoWidth = "3840"
    else if maxResSetting = "4320"
        maxVideoWidth = "7680"
    end if

    return {
        "Condition": "LessThanEqual",
        "Property": "Width",
        "Value": maxVideoWidth,
        "IsRequired": true
    }
end function

' Recieves and returns an assArray of supported profiles and levels for each video codec
function updateProfileArray(profileArray as object, videoCodec as string, videoProfile as string, profileLevel = "" as string) as object
    ' validate params
    if profileArray = invalid then return {}
    if videoCodec = "" or videoProfile = "" then return profileArray

    if profileArray[videoCodec] = invalid
        profileArray[videoCodec] = {}
    end if

    if profileArray[videoCodec][videoProfile] = invalid
        profileArray[videoCodec][videoProfile] = {}
    end if

    ' add profileLevel if a value was provided
    if profileLevel <> ""
        if profileArray[videoCodec][videoProfile][profileLevel] = invalid
            profileArray[videoCodec][videoProfile].AddReplace(profileLevel, true)
        end if
    end if

    return profileArray
end function

' Remove all decimals from a string
function removeDecimals(value as string) as string
    r = CreateObject("roRegex", "\.", "")
    value = r.ReplaceAll(value, "")
    return value
end function
