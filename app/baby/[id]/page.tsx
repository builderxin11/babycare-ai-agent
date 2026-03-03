"use client";

import { useState, useEffect, useCallback } from "react";
import { useParams } from "next/navigation";
import { client } from "@/lib/amplify-utils";
import Link from "next/link";

type Log = {
  id: string;
  type: string | null;
  startTime: string;
  endTime: string | null;
  amount: number | null;
  unit: string | null;
  notes: string | null;
};

type Event = {
  id: string;
  type: string | null;
  title: string;
  startDate: string;
  endDate: string | null;
  notes: string | null;
};

type Baby = {
  id: string;
  name: string;
  birthDate: string;
  gender: string | null;
};

const LOG_TYPE_LABELS: Record<string, string> = {
  MILK_BREAST: "Breastfeed",
  MILK_FORMULA: "Formula",
  MILK_SOLID: "Solid food",
  SLEEP: "Sleep",
  DIAPER_WET: "Diaper (wet)",
  DIAPER_DIRTY: "Diaper (dirty)",
};

const EVENT_TYPE_LABELS: Record<string, string> = {
  VACCINE: "Vaccine",
  TRAVEL: "Travel",
  JET_LAG: "Jet lag",
  ILLNESS: "Illness",
  MILESTONE: "Milestone",
  OTHER: "Other",
};

export default function BabyDetail() {
  const params = useParams();
  const babyId = params.id as string;

  const [baby, setBaby] = useState<Baby | null>(null);
  const [logs, setLogs] = useState<Log[]>([]);
  const [events, setEvents] = useState<Event[]>([]);
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    try {
      const { data: babyData } = await client.models.Baby.get({ id: babyId });
      if (babyData) setBaby(babyData as Baby);

      const { data: logData } = await client.models.PhysiologyLog.list({
        filter: { babyId: { eq: babyId } },
      });
      // Sort by startTime descending
      const sortedLogs = (logData as Log[]).sort(
        (a, b) => new Date(b.startTime).getTime() - new Date(a.startTime).getTime()
      );
      setLogs(sortedLogs.slice(0, 20));

      const { data: eventData } = await client.models.ContextEvent.list({
        filter: { babyId: { eq: babyId } },
      });
      const sortedEvents = (eventData as Event[]).sort(
        (a, b) => new Date(b.startDate).getTime() - new Date(a.startDate).getTime()
      );
      setEvents(sortedEvents.slice(0, 10));
    } catch (err) {
      console.error("Failed to load baby data:", err);
    } finally {
      setLoading(false);
    }
  }, [babyId]);

  useEffect(() => {
    load();
  }, [load]);

  function formatTime(iso: string): string {
    return new Date(iso).toLocaleString(undefined, {
      month: "short",
      day: "numeric",
      hour: "2-digit",
      minute: "2-digit",
    });
  }

  function formatDate(dateStr: string): string {
    return new Date(dateStr).toLocaleDateString(undefined, {
      month: "short",
      day: "numeric",
      year: "numeric",
    });
  }

  if (loading) {
    return (
      <div className="page">
        <div className="empty-state"><span className="spinner" /></div>
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
      <h1>{baby.name}</h1>
      <p style={{ color: "#666", marginBottom: "1rem" }}>
        Born {formatDate(baby.birthDate)}
        {baby.gender ? ` · ${baby.gender.toLowerCase()}` : ""}
      </p>

      <div style={{ display: "flex", gap: "0.5rem", marginBottom: "2rem" }}>
        <Link href={`/baby/${babyId}/log`} className="btn">+ Add log</Link>
        <Link href={`/baby/${babyId}/event`} className="btn btn-secondary">+ Add event</Link>
        <Link href={`/baby/${babyId}/reports`} className="btn btn-secondary">Daily Reports</Link>
      </div>

      <h2>Recent logs</h2>
      {logs.length === 0 ? (
        <div className="card"><p className="empty-state">No logs yet.</p></div>
      ) : (
        <div className="card">
          {logs.map((log) => (
            <div className="timeline-item" key={log.id}>
              <span className="timeline-time">{formatTime(log.startTime)}</span>
              <div className="timeline-content">
                <strong>{LOG_TYPE_LABELS[log.type ?? ""] ?? log.type}</strong>
                {log.amount != null && (
                  <span style={{ marginLeft: "0.5rem", color: "#666" }}>
                    {log.amount} {log.unit?.toLowerCase()}
                  </span>
                )}
                {log.notes && <p style={{ fontSize: "0.85rem", color: "#666" }}>{log.notes}</p>}
              </div>
            </div>
          ))}
        </div>
      )}

      <h2 style={{ marginTop: "2rem" }}>Recent events</h2>
      {events.length === 0 ? (
        <div className="card"><p className="empty-state">No events yet.</p></div>
      ) : (
        <div className="card">
          {events.map((ev) => (
            <div className="timeline-item" key={ev.id}>
              <span className="timeline-time">{formatDate(ev.startDate)}</span>
              <div className="timeline-content">
                <span className="badge" style={{ marginRight: "0.5rem" }}>
                  {EVENT_TYPE_LABELS[ev.type ?? ""] ?? ev.type}
                </span>
                <strong>{ev.title}</strong>
                {ev.notes && <p style={{ fontSize: "0.85rem", color: "#666" }}>{ev.notes}</p>}
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
