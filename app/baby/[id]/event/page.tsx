"use client";

import { useState } from "react";
import { useParams, useRouter } from "next/navigation";
import { client } from "@/lib/amplify-utils";

const EVENT_TYPES = [
  { value: "VACCINE", label: "Vaccine" },
  { value: "TRAVEL", label: "Travel" },
  { value: "JET_LAG", label: "Jet lag" },
  { value: "ILLNESS", label: "Illness" },
  { value: "MILESTONE", label: "Milestone" },
  { value: "OTHER", label: "Other" },
];

export default function AddEvent() {
  const params = useParams();
  const router = useRouter();
  const babyId = params.id as string;

  const [type, setType] = useState("VACCINE");
  const [title, setTitle] = useState("");
  const [startDate, setStartDate] = useState("");
  const [endDate, setEndDate] = useState("");
  const [notes, setNotes] = useState("");
  const [saving, setSaving] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setSaving(true);

    try {
      const { data: baby } = await client.models.Baby.get({ id: babyId });
      if (!baby) throw new Error("Baby not found");

      await client.models.ContextEvent.create({
        babyId,
        type: type as "VACCINE" | "TRAVEL" | "JET_LAG" | "ILLNESS" | "MILESTONE" | "OTHER",
        title,
        startDate,
        endDate: endDate || undefined,
        notes: notes || undefined,
        familyOwners: baby.familyOwners as string[],
      });

      router.push(`/baby/${babyId}`);
    } catch (err) {
      console.error("Failed to create event:", err);
      setSaving(false);
    }
  }

  return (
    <div className="page">
      <h1>Add context event</h1>
      <div className="card">
        <form onSubmit={handleSubmit}>
          <div className="form-row">
            <div className="form-group">
              <label>Type</label>
              <select value={type} onChange={(e) => setType(e.target.value)}>
                {EVENT_TYPES.map((t) => (
                  <option key={t.value} value={t.value}>{t.label}</option>
                ))}
              </select>
            </div>
            <div className="form-group">
              <label>Title</label>
              <input
                type="text"
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                placeholder="e.g. DTaP vaccine 2nd dose"
                required
              />
            </div>
          </div>

          <div className="form-row">
            <div className="form-group">
              <label>Start date</label>
              <input
                type="date"
                value={startDate}
                onChange={(e) => setStartDate(e.target.value)}
                required
              />
            </div>
            <div className="form-group">
              <label>End date (optional)</label>
              <input
                type="date"
                value={endDate}
                onChange={(e) => setEndDate(e.target.value)}
              />
            </div>
          </div>

          <div className="form-group">
            <label>Notes (optional)</label>
            <textarea
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
              placeholder="Any details..."
            />
          </div>

          <div style={{ display: "flex", gap: "0.5rem" }}>
            <button type="submit" className="btn" disabled={saving}>
              {saving ? "Saving..." : "Save event"}
            </button>
            <button type="button" className="btn btn-secondary" onClick={() => router.push(`/baby/${babyId}`)}>
              Cancel
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
