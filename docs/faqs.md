# Frequently Asked Questions (FAQs)

## Plex: Secure Connection Issues

**Question:** I changed my Plex server to "Secure connections: Required" and now Posterizarr cannot reconnect. I tried using the server's IP address and port, but it doesn't work. What should I do?

**Answer:** 
When you require secure connections in Plex, you can no longer connect using a plain IP address because the SSL certificate is tied to a specific Plex domain name. 

To fix this, you must use your server's exact, secure domain name. This is a long string that looks something like this:
`https://192-168-1-50.abcdef1234567890.plex.direct:32400`

### How to find your secure Plex URL:

1.  Open your browser and navigate to the following URL (replace `YOUR_TOKEN_HERE` with your actual Plex token):
    `https://plex.tv/api/resources?includeHttps=1&X-Plex-Token=YOUR_TOKEN_HERE`
2.  Look for the `<Connection>` tag that has `protocol="https"` and `local="1"`.
3.  Copy the value of the `uri` attribute. It should look like the `plex.direct` example above.
4.  Use this full URI as your Plex URL in the Posterizarr configuration.

!!! tip "Finding your Plex Token"
    If you don't know how to find your Plex token, refer to the [official Plex documentation](https://support.plex.tv/articles/204059436-finding-an-authentication-token-x-plex-token/).
