
import "pkg:/source/utils/resolver/resolvers/local.brs"

' takes a string like "domain.tld",
' determines if a stub resolver exists for tld
' if it does, it attempts to resolve and return an ip
' if resolution fails or no stub resolver exists,
' returns the arguemnt it received.
' we get around the tls problem with .local, since most interfaces
' on the roku do not accept custom tls directives in 12.0
' such as the Poster, the agent that fetches bif files, etc.
' this means there is no way that the user has domain which both
' requires one of these resolvers and has a globally
' signed certificate. later, perhaps we can implement a custom
' httpAgent and do our own per-resolver verification.
function resolve(dn as string) as string
    parts = dn.tokenize(".")
    domain = parts[0]
    tld = parts[1]
    if tld = "local"
        localResolve(domain)
    end if
    return dn
end function
