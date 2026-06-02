# DocuSign eSignature — JWT Grant, envelopes, Connect

Node SDK: `docusign-esign` 9.0.0. API version path: `/restapi/v2.1`.

## JWT Grant auth (server / system integration)

Use JWT Grant when no human is present to do an interactive OAuth login — a backend impersonating a service user.

1. **Integration key + RSA keypair.** In the DocuSign admin console (Apps and Keys), create an integration key, then generate an RSA keypair. Keep the private key in a secret store; DocuSign keeps the public key.
2. **One-time consent.** JWT impersonation requires the impersonated user to have consented once. Build the consent URL and open it as that user:
   ```text
   https://account-d.docusign.com/oauth/auth?response_type=code
     &scope=signature%20impersonation
     &client_id=<INTEGRATION_KEY>
     &redirect_uri=<YOUR_REDIRECT>
   ```
   (`account-d.docusign.com` is the demo/sandbox auth host; prod is `account.docusign.com`.)
3. **Request a user token.** Sign a JWT assertion with the RSA private key, `scope: signature impersonation`, `sub` = impersonated user GUID, and exchange it at `/oauth/token` for an access token. The SDK's `requestJWTUserToken` does this.
4. **Discover the base path.** Call `GET /oauth/userinfo` with the token; read the account's `base_uri` and append `/restapi`. Do NOT hardcode the prod host while testing — sandbox is `https://demo.docusign.net/restapi`.
5. **Use token + base path** for all `EnvelopesApi` calls. Tokens expire (~1h); refresh before expiry.

```javascript
import docusign from "docusign-esign";
import fs from "node:fs";

const apiClient = new docusign.ApiClient();
apiClient.setOAuthBasePath("account-d.docusign.com"); // demo
const results = await apiClient.requestJWTUserToken(
  process.env.DOCUSIGN_INTEGRATION_KEY,
  process.env.DOCUSIGN_USER_ID,
  ["signature", "impersonation"],
  fs.readFileSync(process.env.DOCUSIGN_PRIVATE_KEY_PATH),
  3600,
);
const token = results.body.access_token;

const userInfo = await apiClient.getUserInfo(token);
const account  = userInfo.accounts.find(a => a.isDefault === "true");
apiClient.setBasePath(account.baseUri + "/restapi");
apiClient.addDefaultHeader("Authorization", "Bearer " + token);
```

## Envelope and tabs anatomy

- **Envelope** wraps documents + recipients + the lifecycle (`created` → `sent` → `delivered` → `completed`/`declined`/`voided`).
- **Documents**: base64 with `documentId`, `name`, `fileExtension`.
- **Recipients.signers**: each has `recipientId`, `routingOrder` (signing order), `email`, `name`.
- **Tabs**: `signHere`, `dateSigned`, `text`, etc. Place by `xPosition`/`yPosition` + `pageNumber`, or by `anchorString` (text already in the PDF, e.g. `/sig1/`) with `anchorXOffset`/`anchorYOffset`. Prefer anchors — they survive layout changes.
- `clientUserId` on a signer marks them as an **embedded** (captive) signer; you then request a recipient view URL.

## Templates

Reusable envelope skeletons. Send with `templateId` + `templateRoles` (map a role name to email/name + prefilled `tabs`), no raw document needed.

## Connect webhooks + HMAC verification

DocuSign Connect pushes envelope events to your endpoint. Enable HMAC in the Connect config to get a signing key; DocuSign sends `X-DocuSign-Signature-1` (and -2 during key rotation).

```javascript
import crypto from "node:crypto";

function verifyDocuSign(rawBody, headerSig, hmacKey) {
  const computed = crypto
    .createHmac("sha256", hmacKey)
    .update(rawBody, "utf8")
    .digest("base64");
  return crypto.timingSafeEqual(
    Buffer.from(computed), Buffer.from(headerSig));
}
```

Verify against the **raw** request body (not a re-serialized object). On a verified `Completed` event:

```javascript
const signedPdf   = await envelopesApi.getDocument(accountId, envelopeId, "combined");
const certificate = await envelopesApi.getDocument(accountId, envelopeId, "certificate");
```

`"certificate"` returns the **Certificate of Completion** — the court-facing audit trail. Store both.

## Demo → prod go-live

Build entirely on `demo.docusign.net`. To go live, submit the integration key for review / promote it to production through the admin console, then switch the OAuth host to `account.docusign.com` and base path to the prod `base_uri`. Re-grant consent in prod.
