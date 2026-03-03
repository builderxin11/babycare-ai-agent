"use client";

import { useState, useEffect, useCallback } from "react";
import { useParams } from "next/navigation";
import { client } from "@/lib/amplify-utils";
import Link from "next/link";

type Baby = {
  id: string;
  name: string;
  birthDate: string;
};

type Report = {
  baby_id: string;
  baby_name: string;
  report_date: string;
  health_status: string;
  confidence_score: number;
  trend_direction: string;
  summary: string;
  observations: string[];
  action_items: string[];
  warnings: string[];
  citations: { source_type: string; reference: string; detail?: string }[];
  data_snapshot: Record<string, unknown>;
  generated_at: string;
  disclaimer: string;
};

const HEALTH_STATUS_LABELS: Record<string, string> = {
  healthy: "Healthy",
  monitor: "Monitor",
  concern: "Concern",
};

const TREND_LABELS: Record<string, string> = {
  improving: "Improving",
  stable: "Stable",
  declining: "Declining",
};

const API_BASE = process.env.NEXT_PUBLIC_AGENT_API_URL || "http://localhost:8000";

export default function ReportsPage() {
  const params = useParams();
  const babyId = params.id as string;

  const [baby, setBaby] = useState<Baby | null>(null);
  const [reports, setReports] = useState<Report[]>([]);
  const [loading, setLoading] = useState(true);
  const [generating, setGenerating] = useState(false);
  const [expandedId, setExpandedId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const loadBaby = useCallback(async () => {
    try {
      const { data: babyData } = await client.models.Baby.get({ id: babyId });
      if (babyData) setBaby(babyData as Baby);
    } catch (err) {
      console.error("Failed to load baby:", err);
    } finally {
      setLoading(false);
    }
  }, [babyId]);

  useEffect(() => {
    loadBaby();
  }, [loadBaby]);

  function calculateAgeMonths(birthDateStr: string): number {
    const birth = new Date(birthDateStr);
    const now = new Date();
    return (
      (now.getFullYear() - birth.getFullYear()) * 12 +
      (now.getMonth() - birth.getMonth())
    );
  }

  async function generateReport() {
    if (!baby) return;
    setGenerating(true);
    setError(null);

    try {
      const response = await fetch(`${API_BASE}/report`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          baby_id: baby.id,
          baby_name: baby.name,
          baby_age_months: calculateAgeMonths(baby.birthDate),
        }),
      });

      if (!response.ok) {
        const errData = await response.json().catch(() => ({}));
        throw new Error(errData.detail || `HTTP ${response.status}`);
      }

      const report: Report = await response.json();
      // Add to the beginning of the list
      setReports((prev) => [report, ...prev]);
      setExpandedId(report.report_date); // Auto-expand the new report
    } catch (err) {
      console.error("Failed to generate report:", err);
      setError(err instanceof Error ? err.message : "Failed to generate report");
    } finally {
      setGenerating(false);
    }
  }

  function formatDate(dateStr: string): string {
    return new Date(dateStr).toLocaleDateString(undefined, {
      weekday: "short",
      month: "short",
      day: "numeric",
      year: "numeric",
    });
  }

  function toggleExpand(reportDate: string) {
    setExpandedId((prev) => (prev === reportDate ? null : reportDate));
  }

  if (loading) {
    return (
      <div className="page">
        <div className="empty-state">
          <span className="spinner" />
        </div>
      </div>
    );
  }

  if (!baby) {
    return (
      <div className="page">
        <div className="empty-state">Baby not found.</div>
      </div>
    );
  }

  return (
    <div className="page">
      <div style={{ marginBottom: "1rem" }}>
        <Link href={`/baby/${babyId}`} style={{ color: "var(--color-primary)", fontSize: "0.9rem" }}>
          &larr; Back to {baby.name}
        </Link>
      </div>

      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "1.5rem" }}>
        <h1 style={{ marginBottom: 0 }}>Daily Reports</h1>
        <button className="btn" onClick={generateReport} disabled={generating}>
          {generating ? (
            <>
              <span className="spinner" style={{ marginRight: "0.5rem", width: "1rem", height: "1rem" }} />
              Generating...
            </>
          ) : (
            "Generate Report"
          )}
        </button>
      </div>

      {error && (
        <div className="warning-box" style={{ marginBottom: "1rem" }}>
          {error}
        </div>
      )}

      {reports.length === 0 ? (
        <div className="card">
          <div className="empty-state">
            <p>No reports yet.</p>
            <p style={{ fontSize: "0.85rem", marginTop: "0.5rem" }}>
              Click &quot;Generate Report&quot; to create a daily health summary based on logged data.
            </p>
          </div>
        </div>
      ) : (
        reports.map((report) => {
          const isExpanded = expandedId === report.report_date;
          return (
            <div
              key={report.report_date}
              className={`report-card ${isExpanded ? "expanded" : ""}`}
              onClick={() => !isExpanded && toggleExpand(report.report_date)}
            >
              <div className="report-header">
                <div>
                  <strong>{formatDate(report.report_date)}</strong>
                  <span style={{ marginLeft: "0.75rem" }}>
                    <span className={`badge badge-${report.health_status}`}>
                      {HEALTH_STATUS_LABELS[report.health_status] || report.health_status}
                    </span>
                  </span>
                  <span style={{ marginLeft: "0.5rem" }}>
                    <span className={`badge badge-${report.trend_direction}`}>
                      {TREND_LABELS[report.trend_direction] || report.trend_direction}
                    </span>
                  </span>
                </div>
                <div style={{ fontSize: "0.8rem", color: "var(--color-text-muted)" }}>
                  Confidence: {Math.round(report.confidence_score * 100)}%
                </div>
              </div>

              <p className="report-summary">{report.summary}</p>

              {isExpanded && (
                <div className="report-details" onClick={(e) => e.stopPropagation()}>
                  {report.warnings.length > 0 && (
                    <div className="warning-box">
                      <strong>Warnings:</strong>
                      <ul style={{ marginTop: "0.5rem", marginLeft: "1rem" }}>
                        {report.warnings.map((w, i) => (
                          <li key={i}>{w}</li>
                        ))}
                      </ul>
                    </div>
                  )}

                  {report.observations.length > 0 && (
                    <div className="report-section">
                      <h4>Observations</h4>
                      <ul>
                        {report.observations.map((obs, i) => (
                          <li key={i}>{obs}</li>
                        ))}
                      </ul>
                    </div>
                  )}

                  {report.action_items.length > 0 && (
                    <div className="report-section">
                      <h4>Recommendations</h4>
                      <ul>
                        {report.action_items.map((item, i) => (
                          <li key={i}>{item}</li>
                        ))}
                      </ul>
                    </div>
                  )}

                  {report.citations.length > 0 && (
                    <div className="report-section">
                      <h4>Sources</h4>
                      <ul>
                        {report.citations.slice(0, 5).map((c, i) => (
                          <li key={i}>
                            <span className="badge" style={{ marginRight: "0.5rem", fontSize: "0.7rem" }}>
                              {c.source_type}
                            </span>
                            {c.reference}
                          </li>
                        ))}
                        {report.citations.length > 5 && (
                          <li style={{ color: "var(--color-text-muted)" }}>
                            +{report.citations.length - 5} more sources
                          </li>
                        )}
                      </ul>
                    </div>
                  )}

                  <div style={{ marginTop: "1rem", fontSize: "0.75rem", color: "var(--color-text-muted)" }}>
                    {report.disclaimer}
                  </div>

                  <button
                    className="btn btn-secondary"
                    style={{ marginTop: "1rem", fontSize: "0.8rem", padding: "0.4rem 0.75rem" }}
                    onClick={() => setExpandedId(null)}
                  >
                    Collapse
                  </button>
                </div>
              )}
            </div>
          );
        })
      )}
    </div>
  );
}
