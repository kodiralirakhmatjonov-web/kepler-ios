# iumrah · DevSMS OTP setup

This update replaces the SMS placeholder with live server-side DevSMS OTP.

## One required secret

Create this GitHub Actions repository secret before running the backend deployment workflow:

- `DEVSMS_API_TOKEN` — API token from the DevSMS cabinet.

Do not put the token into Swift, source code, a ZIP update, `wrangler.generated.jsonc`, or a GitHub workflow input.

## Deployment order

1. Add `DEVSMS_API_TOKEN` in GitHub → Settings → Secrets and variables → Actions.
2. Run `Deploy iumrah Package Engine`.
3. The workflow validates the token against DevSMS balance API, applies `0008_devsms_phone_verification.sql`, deploys Package Engine, installs the Worker secret, and verifies `/api/package/health` reports DevSMS configured.
4. Only after the backend workflow succeeds, build the iOS/TestFlight app.

## Live behavior

- SMS is accepted only for Uzbekistan numbers in `+998XXXXXXXXX` format.
- OTP is generated on the server, valid for 10 minutes, and limited to 5 attempts.
- The raw OTP is never stored in D1; only a salted PBKDF2 hash is stored.
- The DevSMS API token never reaches the iOS app.
- Account activation uses the DevSMS universal registration OTP template.
- KYC/owner phone verification uses the universal operation-verification OTP template.
- A verified phone is linked to the canonical pilgrim/iumrah account and is restored when the KYC screen is opened again.
