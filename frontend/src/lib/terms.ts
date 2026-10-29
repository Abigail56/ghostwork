// Terms of Service shown on /terms and in the sign-up form.
// Keep TERMS_VERSION in sync with TERMS_VERSION in backend/app/core/config.py.

export const TERMS_VERSION = "2026-10-30";
export const TERMS_EFFECTIVE = "October 30, 2026";

export interface TermsSection {
  id: string;
  title: string;
  paragraphs: string[];
  bullets?: string[];
}

export const TERMS_SUMMARY = [
  "You're responsible for your account and for what your workflows do.",
  "Only automate systems, accounts and data you're allowed to use.",
  "Your workflows and data belong to you. We use them only to run the service.",
  "GhostWork is in early access: it's free, and it comes without uptime guarantees.",
  "You can delete your account and all its data at any time from Settings.",
];

export const TERMS_SECTIONS: TermsSection[] = [
  {
    id: "agreement",
    title: "1. Agreement to these terms",
    paragraphs: [
      "These Terms of Service (the \"Terms\") are an agreement between you and the operator of this GhostWork service (\"GhostWork\", \"we\", \"us\"). By creating an account or using GhostWork, you agree to these Terms. If you don't agree, don't create an account or use the service.",
      "If you use GhostWork on behalf of a company or other organization, you confirm that you're authorized to accept these Terms for it, and \"you\" includes that organization.",
    ],
  },
  {
    id: "service",
    title: "2. What GhostWork is",
    paragraphs: [
      "GhostWork lets you build workflows that run automatically: they can be started manually, on a schedule, or by a webhook, and can call web APIs, transform data, evaluate conditions, send email through a mail server you connect, and post to Slack.",
      "GhostWork does exactly what your workflows are configured to do. It does not use artificial intelligence to make decisions on your behalf.",
    ],
  },
  {
    id: "eligibility",
    title: "3. Who can use GhostWork",
    paragraphs: [
      "You must be at least 16 years old (or the age of digital consent where you live, if higher) and able to form a binding agreement. You may not use GhostWork if you're barred from doing so by applicable law.",
    ],
  },
  {
    id: "account",
    title: "4. Your account and its security",
    paragraphs: ["You're responsible for everything that happens under your account. In particular, you agree to:"],
    bullets: [
      "provide accurate account information and keep your email address current;",
      "keep your password confidential and use a strong, unique password;",
      "sign out sessions you don't recognize (Settings → Sessions) and tell us promptly about any unauthorized use;",
      "not share your account or let others use it.",
    ],
  },
  {
    id: "acceptable-use",
    title: "5. Acceptable use",
    paragraphs: ["You may only automate systems, accounts and data that you own or are authorized to use. You agree not to use GhostWork to:"],
    bullets: [
      "break any law, or infringe anyone's privacy, intellectual property or other rights;",
      "send spam, unsolicited bulk messages, phishing or deceptive content;",
      "attack, scan, overload or gain unauthorized access to any system, including through repeated or high-volume requests;",
      "try to reach internal or private networks, other users' data, or GhostWork's own infrastructure;",
      "get around usage limits, rate limits or security controls, or reverse-engineer the service except where the law allows it;",
      "process data you're not permitted to process, including sensitive personal data without a lawful basis.",
    ],
  },
  {
    id: "responsibility",
    title: "6. Responsibility for your workflows",
    paragraphs: [
      "You decide what your workflows do and you're responsible for their effects, including requests they send, messages they deliver and data they change in other systems. Test workflows before activating them and pause any workflow that behaves unexpectedly.",
      "Don't use GhostWork as the only safeguard for safety-critical, medical, financial-settlement or legally required processes.",
    ],
  },
  {
    id: "content",
    title: "7. Your content and data",
    paragraphs: [
      "You keep all rights to the workflows you create and the data they process (\"Your Content\"). You give us permission to store, copy, transmit and process Your Content only as needed to run, secure and support GhostWork for you.",
      "You're responsible for having the rights and permissions needed for Your Content, including any personal data. Execution records, including step outputs, are stored so you can review runs; finished runs may be deleted automatically after the retention period shown in the product documentation (currently 90 days).",
      "How we handle personal data is described in our Privacy Policy.",
    ],
  },
  {
    id: "integrations",
    title: "8. Integrations and third-party services",
    paragraphs: [
      "When you connect a third-party service (for example an email server or Slack), you authorize GhostWork to use the credentials you provide to act on your behalf for the steps you configure. Credentials are encrypted when stored and are never shown back to you.",
      "Third-party services are governed by their own terms. We're not responsible for their availability, behavior, or changes to them.",
    ],
  },
  {
    id: "early-access",
    title: "9. Early access, fees and limits",
    paragraphs: [
      "GhostWork is currently in early access and free to use. We may introduce paid plans in the future; we'll tell you before any charge applies, and you'll never be charged without agreeing first.",
      "Usage limits apply to keep the service reliable for everyone, such as the number of steps per workflow, runs in progress at once, request timeouts and response sizes. Current limits are listed in the documentation and may change.",
      "Features may be added, changed or removed during early access. Features marked \"Planned\" are not available.",
    ],
  },
  {
    id: "ip",
    title: "10. Our intellectual property",
    paragraphs: [
      "GhostWork, including its software, design and branding, belongs to us and our licensors. These Terms give you a limited, personal, non-exclusive, non-transferable right to use the service while your account is in good standing. If you send us feedback, we may use it without obligation to you.",
    ],
  },
  {
    id: "termination",
    title: "11. Suspension, termination and deletion",
    paragraphs: [
      "You can stop using GhostWork at any time and delete your account from Settings → Security. Deleting your account permanently deletes your workflows, run history and stored credentials.",
      "We may suspend or close an account that breaks these Terms, puts other users or systems at risk, or is required to be closed by law. Where reasonable, we'll tell you first and give you a chance to fix the problem.",
    ],
  },
  {
    id: "disclaimers",
    title: "12. Disclaimers",
    paragraphs: [
      "GhostWork is provided \"as is\" and \"as available\". To the extent the law allows, we make no warranties of any kind, whether express or implied, including that the service will be uninterrupted, error-free, or that workflows will run at a particular time. Keep your own copies of important data.",
    ],
  },
  {
    id: "liability",
    title: "13. Limitation of liability",
    paragraphs: [
      "To the extent the law allows, we're not liable for indirect, incidental, special or consequential damages, or for lost profits, revenue or data, arising from your use of GhostWork. Our total liability for any claim relating to the service is limited to the greater of the amount you paid us in the 12 months before the claim or USD 50.",
      "Nothing in these Terms limits liability that can't be limited by law, such as liability for fraud or for death or personal injury caused by negligence.",
    ],
  },
  {
    id: "indemnity",
    title: "14. Your responsibility to us",
    paragraphs: [
      "If a third party makes a claim against us because of your workflows, Your Content, or your breach of these Terms, you agree to cover the reasonable costs and losses that result, to the extent the law allows.",
    ],
  },
  {
    id: "changes",
    title: "15. Changes to these terms",
    paragraphs: [
      "We may update these Terms as GhostWork evolves. For material changes we'll notify you in the app or by email before they take effect. If you keep using GhostWork after changes take effect, you accept the updated Terms; if you don't agree, you can delete your account.",
    ],
  },
  {
    id: "general",
    title: "16. General",
    paragraphs: [
      "These Terms are governed by the laws of the place where the operator of this GhostWork service is established, without regard to conflict-of-law rules. If part of these Terms is found unenforceable, the rest stays in effect. Not enforcing a right isn't a waiver of it. You may not transfer these Terms without our consent; we may transfer them as part of a reorganization or sale of the service.",
      "Questions about these Terms can be sent to the administrator of your GhostWork service.",
    ],
  },
];
