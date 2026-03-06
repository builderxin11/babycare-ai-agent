"use client";

import "./globals.css";
import "@aws-amplify/ui-react/styles.css";
import { Amplify } from "aws-amplify";
import { Authenticator } from "@aws-amplify/ui-react";
import outputs from "@/amplify_outputs.json";
import Link from "next/link";

Amplify.configure(outputs, { ssr: true });

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>
        <Authenticator>
          {({ signOut, user }) => (
            <>
              <nav>
                <div className="nav-inner">
                  <div>
                    <Link href="/">Dashboard</Link>
                    <Link href="/ask">Ask Agent</Link>
                  </div>
                  <div>
                    <span style={{ fontSize: "0.85rem", color: "#666", marginRight: "1rem" }}>
                      {user?.signInDetails?.loginId}
                    </span>
                    <button className="btn btn-secondary" onClick={signOut} style={{ padding: "0.3rem 0.75rem" }}>
                      Sign out
                    </button>
                  </div>
                </div>
              </nav>
              {children}
            </>
          )}
        </Authenticator>
      </body>
    </html>
  );
}
