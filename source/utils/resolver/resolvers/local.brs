function localResolve(dn as string) as string
    print ".local resolver received domain " dn
    sendQuery(dn)
    ts = CreateObject("roTimespan")
    while ts.totalSeconds() < 10
        msg = Wait(5000, m.mdns.port)
        if msg <> invalid
            print "Message: "
            print msg
            ProcessMDNSResponse(msg)
            exit while
        end if
    end while
    return ""
end function

function processMdnsResponse(message)
    if Type(message) = "roSocketEvent"
        if message.GetSocketId() = m.mdns.socket.GetId()
            print "The status of the socket: " m.mdns.socket.eSuccess()
            if m.mdns.socket.IsReadable()
                response = CreateObject("roByteArray")
                r = m.mdns.socket.Receive(response, 0, 4096)
                print "Received MDNS response packet: "
                print response
                print r
            else
                print "m.mdns.socket is not readable"
            end if
        else
            print "message is not from m.mdns.socket"
        end if
    else
        print "message is not an roSocketEvent"
    end if
    return ""
end function

function rdRightShift(num as integer, count = 1 as integer) as integer
    mult = 2 ^ count
    summand = 1
    total = 0
    for i = count to 31
        if num and summand * mult
            total = total + summand
        end if
        summand = summand * 2
    end for
    return total
end function

function rdINTtoHEX(num as integer) as object
    ba = CreateObject("roByteArray")
    ba.setresize(4, false)
    ba[0] = rdRightShift(num, 24)
    ba[1] = rdRightShift(num, 16)
    ba[2] = rdRightShift(num, 8)
    ba[3] = num ' truncates
    return ba.toHexString().Right(2)
end function

sub printTests()
    print rdINTtoHEX(183)
end sub

function strToHex(name as string) as object
    ba = CreateObject("roByteArray")
    ba.FromAsciiString(name)
    return ba.toHexString()
end function

function createPacket(name as string)
    firstPart = "000000000001000000000000"
    secondPart = rdINTtoHEX(len(name)) + strToHex(name)
    lastPart = "056c6f63616c0000010001"
    packet = CreateObject("roByteArray")
    packet.fromHexString(firstPart + secondPart + lastPart)
    return packet
end function

sub sendQuery(name)
    m.mdns = {
        port: CreateObject("roMessagePort"),
        address: CreateObject("roSocketAddress"),
        group: CreateObject("roSocketAddress"),
        socket: CreateObject("roDatagramSocket"),
        urlTransfer: CreateObject("roUrlTransfer")
    }

    m.mdns.address.SetAddress("224.0.0.251:5353")
    m.mdns.group.SetAddress("224.0.0.251:5353")

    print "Succesfully joined group:" m.mdns.socket.JoinGroup(m.mdns.group)
    m.mdns.socket.SetBroadcast(false)
    m.mdns.socket.setaddress(m.mdns.address)
    m.mdns.socket.NotifyReadable(true)
    print "THE MULTICAST TTL: " m.mdns.socket.getMulticastTTL()
    m.mdns.socket.SetMessagePort(m.mdns.port)
    m.mdns.urlTransfer.SetPort(m.mdns.port)
    'm.mdns.socket.SetBroadcast(true)
    'print "Broadcast enabled: " m.mdns.socket.GetBroadcast()
    'print "Multicastloop: " m.mdns.socket.GetMulticastLoop()
    m.mdns.socket.SetSendToAddress(m.mdns.address)

    mdnsQueryPacket = createPacket(name)
    groupJoinPacket = CreateObject("roByteArray")
    groupJoinPacket.fromHexString("1100eeff00000000")
    m.mdns.socket.Send(groupJoinPacket, 0, mdnsQueryPacket.count())
    m.mdns.socket.Send(mdnsQueryPacket, 0, mdnsQueryPacket.count())
end sub
