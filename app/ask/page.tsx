"use client";

import { useState, useEffect, useCallback } from "react";
import { client } from "@/lib/amplify-utils";
import { askAgent, type ParentingAdvice } from "@/lib/agent-api";

type Baby = {
  id: string;
  name: string;
  birthDate: string;
};

function calculateAgeMonths(birthDateStr: string): number {
  const birth = new Date(birthDateStr);
  const now = new Date();
  return (now.getFullYear() - birth.getFullYear()) * 12 + (now.getMonth() - birth.getMonth());
}

function RiskBadge({ level }: { level: string }) {
  const cls = level === "HIGH" ? "badge-high" : level === "MEDIUM" ? "badge-medium" : "badge-low";
  return <span className={`badge ${cls}`}>{level}</span>;
}

function SourceBadge({ status }: { status: string }) {
  const cls =
    status === "ok" ? "badge-ok" :
    status === "degraded" ? "badge-degraded" :
    status === "fallback" ? "badge-fallback" :
    "badge-skipped";
  return <span className={`badge ${cls}`}>{status}</span>;
}

export default function AskPage() {
  const [babies, setBabies] = useState<Baby[]>([]);
  const [selectedBabyId, setSelectedBabyId] = useState("");
  const [question, setQuestion] = useState("");
  const [loading, setLoading] = useState(false);
  const [advice, setAdvice] = useState<ParentingAdvice | null>(null);
  const [error, setError] = useState<string | null>(null);

  const loadBabies = useCallback(async () => {
    try {
      const { data } = await client.models.Baby.list();
      const babyList = data as Baby[];
      setBabies(babyList);
      if (babyList.length > 0) {
        setSelectedBabyId(babyList[0].id);
      }
    } catch (err) {
      console.error("Failed to load babies:", err);
    }
  }, []);

  useEffect(() => {
    loadBabies();
  }, [loadBabies]);

  async function handleAsk(e: React.FormEvent) {
    e.preventDefault();
    if (!selectedBabyId || !question.trim()) return;

    const baby = babies.find((b) => b.id === selectedBabyId);
    if (!baby) return;

    setLoading(true);
    setAdvice(null);
    setError(null);

    try {
      const result = await askAgent({
        question: question.trim(),
        baby_id: baby.id,
        baby_name: baby.name,
        baby_age_months: calculateAgeMonths(baby.birthDate),
      });
      setAdvice(result);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Unknown error");
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="page">
      <h1>Ask the agent</h1>

      <div className="card">
        <form onSubmit={handleAsk}>
          <div className="form-group">
            <label>Baby</label>
            <select
              value={selectedBabyId}
              onChange={(e) => setSelectedBabyId(e.target.value)}
              required
            >
              {babies.length === 0 && <option value="">No babies found</option>}
              {babies.map((b) => (
                <option key={b.id} value={b.id}>
                  {b.name} ({calculateAgeMonths(b.birthDate)}mo)
                </option>
              ))}
            </select>
          </div>

          <div className="form-group">
            <label>Your question</label>
            <textarea
              value={question}
              onChange={(e) => setQuestion(e.target.value)}
              placeholder="e.g. My baby got her vaccine 2 days ago and has been sleeping more and eating less. Is this normal?"
              required
              style={{ minHeight: "100px" }}
            />
          </div>

          <button type="submit" className="btn" disabled={loading || babies.length === 0}>
            {loading ? (
              <span style={{ display: "flex", alignItems: "center", gap: "0.5rem" }}>
                <span className="spinner" /> Running agent...
              </span>
            ) : (
              "Ask"
            )}
          </button>
        </form>
      </div>

      {error && (
        <div className="card" style={{ borderColor: "#dc2626" }}>
          <strong style={{ color: "#dc2626" }}>Error:</strong> {error}
        </div>
      )}

      {advice && (
        <div style={{ marginTop: "1.5rem" }}>
          <h2>Advice</h2>

          {/* Summary card */}
          <div className="card">
            <div style={{ display: "flex", gap: "0.75rem", alignItems: "center", marginBottom: "0.75rem" }}>
              <RiskBadge level={advice.risk_level} />
              <span style={{ fontSize: "0.85rem", color: "#666" }}>
                Confidence: {(advice.confidence_score * 100).toFixed(0)}%
              </span>
              {advice.is_degraded && (
                <span className="badge badge-fallback">Degraded</span>
              )}
            </div>
            <p>{advice.summary}</p>
          </div>

          {/* Key points */}
          {advice.key_points.length > 0 && (
            <div className="card">
              <h3>Key points</h3>
              <ul style={{ paddingLeft: "1.25rem" }}>
                {advice.key_points.map((point, i) => (
                  <li key={i} style={{ marginBottom: "0.35rem" }}>{point}</li>
                ))}
              </ul>
            </div>
          )}

          {/* Action items */}
          {advice.action_items.length > 0 && (
            <div className="card">
              <h3>Action items</h3>
              <ul style={{ paddingLeft: "1.25rem" }}>
                {advice.action_items.map((item, i) => (
                  <li key={i} style={{ marginBottom: "0.35rem" }}>{item}</li>
                ))}
              </ul>
            </div>
          )}

          {/* Sources */}
          {advice.sources_used.length > 0 && (
            <div className="card">
              <h3>Source status</h3>
              {advice.sources_used.map((src, i) => (
                <div key={i} style={{ display: "flex", gap: "0.5rem", alignItems: "center", marginBottom: "0.5rem" }}>
                  <SourceBadge status={src.status} />
                  <strong style={{ fontSize: "0.85rem" }}>{src.source}</strong>
                  <span style={{ fontSize: "0.8rem", color: "#666" }}>{src.message}</span>
                </div>
              ))}
            </div>
          )}

          {/* Citations */}
          {advice.citations.length > 0 && (
            <div className="card">
              <h3>Citations</h3>
              {advice.citations.map((cite, i) => (
                <div key={i} style={{ marginBottom: "0.5rem" }}>
                  <span className="badge" style={{ marginRight: "0.5rem", background: "#e0e7ff", color: "#4338ca" }}>
                    {cite.source_type}
                  </span>
                  <span style={{ fontSize: "0.85rem" }}>{cite.reference}</span>
                  {cite.detail && (
                    <p style={{ fontSize: "0.8rem", color: "#666", marginTop: "0.15rem" }}>{cite.detail}</p>
                  )}
                </div>
              ))}
            </div>
          )}

          {/* Disclaimer */}
          <div className="card" style={{ background: "#fffbeb", borderColor: "#fbbf24" }}>
            <p style={{ fontSize: "0.8rem", color: "#92400e" }}>{advice.disclaimer}</p>
          </div>
        </div>
      )}
    </div>
  );
}
