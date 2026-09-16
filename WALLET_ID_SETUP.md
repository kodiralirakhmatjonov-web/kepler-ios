# iumrah ID — Apple Wallet production setup

The iOS client and PackageEngine endpoint are wired for a signed Apple Wallet pass. The only production-only step that cannot be committed to the repository is installing your Apple Pass Type ID certificate and private key as Cloudflare Worker secrets.

## Apple Developer

1. Create Pass Type ID: `pass.com.iumrah.id` in Apple Developer → Certificates, Identifiers & Profiles → Identifiers → Pass Type IDs.
2. Create a certificate for that Pass Type ID.
3. Export the certificate together with its private key from Keychain as `.p12`.
4. Download the current Apple Worldwide Developer Relations (WWDR) intermediate certificate from Apple.

## Convert locally to PEM

Never commit these files to Git.

```bash
openssl pkcs12 -in iumrah-wallet.p12 -clcerts -nokeys -out wallet-cert.pem
openssl pkcs12 -in iumrah-wallet.p12 -nocerts -nodes -out wallet-key-rsa.pem
openssl pkcs8 -topk8 -inform PEM -outform PEM -nocrypt -in wallet-key-rsa.pem -out wallet-key.pem
openssl x509 -inform DER -in AppleWWDRCAG*.cer -out wallet-wwdr.pem
```

`wallet-key.pem` must begin with `-----BEGIN PRIVATE KEY-----` because the Worker imports it as PKCS#8.

## Cloudflare secrets / vars

Set these on the `iumrah-package-api` Worker:

```bash
wrangler secret put WALLET_CERT_PEM
wrangler secret put WALLET_KEY_PEM
wrangler secret put WALLET_WWDR_CERT_PEM
```

Add these non-secret vars in Cloudflare or generated Wrangler config:

- `WALLET_PASS_TYPE_ID=pass.com.iumrah.id`
- `WALLET_TEAM_ID=2DQ678JTNG`
- `WALLET_ORGANIZATION_NAME=iumrah`

After secrets are installed, deploy PackageEngine. The authenticated endpoint is:

`GET /api/package/client/account/wallet-pass`

It returns `application/vnd.apple.pkpass`. The iOS Account screen fetches it only for the signed-in canonical iumrah account and opens Apple's native Add to Wallet controller.

## Security notes

- Pass certificates/private keys remain server-side only.
- The client never receives the signing key.
- The endpoint requires the existing bearer account session.
- The Wallet QR currently points to `https://iumrah.app`, matching the in-app ID card. The permanent six-digit iumrah ID is displayed on the pass itself.
- The pass is a digital iumrah membership/pilgrim card, not a government identity document.
