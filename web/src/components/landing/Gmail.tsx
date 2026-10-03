import "@/styles/sections-b.css";
import Reveal from "@/components/motion/Reveal";
import { asset } from "@/lib/config";
import GmailCard from "./b/GmailCard";

function GoogleG() {
  return (
    <svg viewBox="0 0 48 48" aria-hidden="true">
      <path fill="#EA4335" d="M24 9.5c3.5 0 6.6 1.2 9.1 3.6l6.8-6.8C35.8 2.4 30.3 0 24 0 14.6 0 6.5 5.4 2.6 13.2l7.9 6.1C12.4 13.6 17.7 9.5 24 9.5z" />
      <path fill="#4285F4" d="M46.5 24.5c0-1.6-.1-3.1-.4-4.5H24v9h12.7c-.6 3-2.3 5.5-4.8 7.2l7.5 5.8c4.4-4.1 7.1-10.1 7.1-17.5z" />
      <path fill="#FBBC05" d="M10.5 28.7A14.5 14.5 0 0 1 9.5 24c0-1.6.3-3.2.8-4.7l-7.9-6.1A24 24 0 0 0 0 24c0 3.9.9 7.5 2.6 10.8l7.9-6.1z" />
      <path fill="#34A853" d="M24 48c6.5 0 11.9-2.1 15.9-5.8l-7.5-5.8c-2.1 1.4-4.9 2.3-8.4 2.3-6.3 0-11.6-4.1-13.5-9.8l-7.9 6.1C6.5 42.6 14.6 48 24 48z" />
    </svg>
  );
}

export default function Gmail() {
  return (
    <section id="gmail" className="section">
      <div className="container gmail__grid">
        <Reveal>
          <div className="eyebrow">Gmail sender watchers</div>
          <h2 className="display">Watch a sender, not an inbox.</h2>
          <p className="gmail__p">
            Sign in with Google once. Then watch one address, several, or a whole domain. New mail from them becomes a
            single notification that counts up — and counts back down as you read in Gmail. Click it to open the message;
            Archive, Mark as Read, Delete and Spam work on every message it counted.
          </p>
          <a className="glink" href={asset("/docs/sign-in-with-google")}>
            <GoogleG />
            Sign in with Google
          </a>
          <p className="gmail__fine">
            Scope: gmail.modify only · tokens stay in your Keychain · the app ships its own OAuth client, nothing to
            configure
          </p>
        </Reveal>
        <Reveal delay={0.1}>
          <div className="gshot">
            <img
              src={asset("/shots/gmail-sender-editor.png")}
              srcSet={`${asset("/shots/gmail-sender-editor.png")} 1x, ${asset("/shots/gmail-sender-editor@2x.png")} 2x`}
              alt="The Gmail sender watcher editor in WebWatcher"
              width={560}
              height={732}
              loading="lazy"
            />
          </div>
          <GmailCard />
        </Reveal>
      </div>
    </section>
  );
}
