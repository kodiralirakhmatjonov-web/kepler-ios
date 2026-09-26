import type { D1Like, D1PreparedStatementLike } from "./d1";

export type Env = {
  IGNAV_API_KEY?: string;
  IGNAV_MONTHLY_REQUEST_BUDGET?: string;
  PACKAGE_QUOTE_SEAL_KEY?: string;
  APPLE_BUNDLE_ID?: string;
  APPLE_WEB_CLIENT_ID?: string;
  GOOGLE_SERVER_CLIENT_ID?: string;
  IUMRAH_PUBLIC_ID_ORIGIN?: string;
  RESEND_API_KEY?: string;
  ACCOUNT_EMAIL_FROM?: string;
  ACCOUNT_EMAIL_REPLY_TO?: string;
  DEVSMS_API_TOKEN?: string;
  WALLET_PASS_TYPE_ID?: string;
  WALLET_TEAM_ID?: string;
  WALLET_ORGANIZATION_NAME?: string;
  WALLET_CERT_PEM?: string;
  WALLET_KEY_PEM?: string;
  WALLET_WWDR_CERT_PEM?: string;
  HOTELS_DB?: D1Like;
  BOOKINGS_DB?: D1Like & { batch(statements: D1PreparedStatementLike[]): Promise<unknown[]> };
};
