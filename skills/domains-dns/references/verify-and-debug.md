# Verify & debug playbook

Always query the authoritative answer and the wire. Your laptop's resolver caches the old answer for the record's full TTL and will lie to you.

## dig — resolution

```bash
dig +short app.example.com                 # what your resolver returns right now
dig +short app.example.com @1.1.1.1         # what a public resolver returns (bypasses local cache)
dig +trace example.com                      # walk root → TLD → authoritative; reveals stale/wrong NS
dig NS example.com +short                   # the delegated nameservers
dig @ns1.provider.net example.com A +short  # ask the authoritative NS directly — the source of truth
dig CAA example.com +short                  # CA authorization at the apex
dig TXT _dmarc.example.com +short           # confirm a TXT row took
```

- `dig +short` shows the resolved value; drop `+short` to see the TTL counting down (low number = recently changed or short TTL).
- If `dig @<authoritative>` is correct but `dig +short` is wrong, it's **caching** — wait out the TTL or query a fresh resolver. Don't re-edit the record.

## openssl — the served chain

```bash
openssl s_client -connect example.com:443 -servername example.com </dev/null 2>/dev/null \
  | openssl x509 -noout -subject -issuer -dates
```

- `-servername` sends SNI; without it a multi-tenant host serves the wrong/default cert and you misdiagnose.
- Check `notAfter` is comfortably ahead. Check `issuer` matches your CAA.
- To see whether the **chain is complete**, look at the full handshake output for the intermediate; an incomplete chain is the curl/mobile-only failure.

## curl — the HTTP verdict

```bash
curl -vI https://example.com 2>&1 | grep -Ei 'HTTP/|location|SSL certificate'
curl -sI https://www.example.com -o /dev/null -w '%{http_code} %{redirect_url}\n'
```

- `SSL certificate verify ok` = chain validates from curl's bundle (catches missing intermediates browsers hide).
- Confirm www and apex resolve to the same canonical host and one 301s to the other.

## Propagation, the right way

Propagation is the **TTL**, not a fixed window (RFC 2181). To make a change land fast:

1. Lower the record's TTL to 300s **before** you change the value.
2. Wait for the old TTL to elapse so resolvers re-query at the new rate.
3. Change the value; new value is picked up within ~5 min.
4. Raise the TTL back afterward.

NS/registrar delegation changes can lag longer because of registry/TLD TTLs — that's the parent zone, outside your control.

## Error → cause → fix

| Symptom | Cause | Fix |
| --- | --- | --- |
| `NXDOMAIN` | Name doesn't exist in the zone, or wrong zone is authoritative | Confirm record exists; `dig NS` that delegation points at the right provider |
| `SERVFAIL` | Broken delegation, or DNSSEC DS mismatch | Match registrar NS to provider; fix/remove stale DS |
| `dig +short` right but browser wrong | Local/OS/browser cache | Flush OS cache or query `@1.1.1.1`; wait the TTL |
| `dig +trace` shows old IP | Authoritative zone not updated, or queried a stale secondary | Edit at the authoritative provider; bump SOA serial |
| `ERR_CERT_AUTHORITY_INVALID` (curl/mobile) | Incomplete chain | Serve `fullchain.pem` |
| `ERR_CERT_COMMON_NAME_INVALID` | Cert SAN doesn't cover the hostname | Reissue covering apex + www |
| ACME CAA error | CAA forbids your CA | Add `CAA 0 issue "<ca>"` |
| HTTPS warns despite valid cert | Mixed content | Serve all subresources over HTTPS |
| Redirect loop on HTTPS | Cloudflare SSL set to Flexible against an HTTPS origin | Set Full (strict) |
