# Credentials — <TOOL_NAME>

## Provider dashboard

- URL: https://...
- Account: <owner email>
- 2FA: <yes/no, where the second factor lives>

## Variables

| Variable | Type | Where to generate | Rotation |
|----------|------|-------------------|----------|
| `<TOOL>_API_KEY`     | secret | Dashboard → API → Create key       | <when and how> |
| `<TOOL>_API_SECRET`  | secret | Next to the API key                | same event as API_KEY |

## Exceptions to the `<TOOL>_<VAR>` naming convention

> Only if any. Document why.

## If a credential leaks

1. Revoke immediately in the provider dashboard.
2. Generate a new one and update local `.env`.
3. If the app consumes it at runtime: update deployment env vars and redeploy.
4. Log the incident with a date in this file.
