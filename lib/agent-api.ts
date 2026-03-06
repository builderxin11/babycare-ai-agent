const AGENT_API_BASE = process.env.NEXT_PUBLIC_AGENT_API_URL ?? "http://localhost:8000";

export interface AgentRequest {
  question: string;
  baby_id: string;
  baby_name: string;
  baby_age_months: number;
}

export interface Citation {
  source_type: string;
  reference: string;
  detail: string | null;
}

export interface SourceStatus {
  source: string;
  status: "ok" | "degraded" | "fallback" | "skipped";
  message: string;
}

export interface ParentingAdvice {
  question: string;
  summary: string;
  key_points: string[];
  action_items: string[];
  risk_level: "LOW" | "MEDIUM" | "HIGH";
  confidence_score: number;
  citations: Citation[];
  sources_used: SourceStatus[];
  is_degraded: boolean;
  raw_sources: string[];
  disclaimer: string;
}

export async function askAgent(req: AgentRequest): Promise<ParentingAdvice> {
  const res = await fetch(`${AGENT_API_BASE}/ask`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(req),
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Agent API error ${res.status}: ${text}`);
  }

  return res.json();
}
