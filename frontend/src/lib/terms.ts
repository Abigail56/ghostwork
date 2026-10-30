// Terms of Service shown on /terms, in the web sign-up form and in the mobile app.
// The content lives in terms.json, shared with mobile/assets/terms.json (scripts/sync-shared.sh).
// Keep `version` in sync with TERMS_VERSION in backend/app/core/config.py.
import terms from "./terms.json";

export interface TermsSection {
  id: string;
  title: string;
  paragraphs: string[];
  bullets?: string[];
}

export const TERMS_VERSION: string = terms.version;
export const TERMS_EFFECTIVE: string = terms.effective;
export const TERMS_SUMMARY: string[] = terms.summary;
export const TERMS_SECTIONS: TermsSection[] = terms.sections;
