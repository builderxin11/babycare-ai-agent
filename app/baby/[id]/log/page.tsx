"use client";

import { useState } from "react";
import { useParams, useRouter } from "next/navigation";
import { client } from "@/lib/amplify-utils";

const LOG_TYPES = [
  { value: "MILK_BREAST", label: "Breastfeed" },
  { value: "MILK_FORMULA", label: "Formula" },
  { value: "MILK_SOLID", label: "Solid food" },
  { value: "SLEEP", label: "Sleep" },
  { value: "DIAPER_WET", label: "Diaper (wet)" },
  { value: "DIAPER_DIRTY", label: "Diaper (dirty)" },
];

const UNIT_OPTIONS: Record<string, { value: string; label: string }[]> = {
  MILK_BREAST: [{ value: "MINUTES", label: "minutes" }],
  MILK_FORMULA: [
    { value: "ML", label: "ml" },
    { value: "OZ", label: "oz" },
  ],
  MILK_SOLID: [
    { value: "ML", label: "ml" },
    { value: "OZ", label: "oz" },
  ],
  SLEEP: [{ value: "MINUTES", label: "minutes" }],
  DIAPER_WET: [{ value: "COUNT", label: "count" }],
  DIAPER_DIRTY: [{ value: "COUNT", label: "count" }],
};

export default function AddLog() {
  const params = useParams();
  const router = useRouter();
  const babyId = params.id as string;

  const [type, setType] = useState("MILK_FORMULA");
  const [startTime, setStartTime] = useState("");
  const [endTime, setEndTime] = useState("");
  const [amount, setAmount] = useState("");
  const [unit, setUnit] = useState("ML");
  const [notes, setNotes] = useState("");
  const [saving, setSaving] = useState(false);

  function handleTypeChange(newType: string) {
    setType(newType);
    const units = UNIT_OPTIONS[newType];
    if (units && units.length > 0) {
      setUnit(units[0].value);
    }
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setSaving(true);

    try {
      // Get baby to copy familyOwners
      const { data: baby } = await client.models.Baby.get({ id: babyId });
      if (!baby) throw new Error("Baby not found");

      await client.models.PhysiologyLog.create({
        babyId,
        type: type as "MILK_BREAST" | "MILK_FORMULA" | "MILK_SOLID" | "SLEEP" | "DIAPER_WET" | "DIAPER_DIRTY",
        startTime: new Date(startTime).toISOString(),
        endTime: endTime ? new Date(endTime).toISOString() : undefined,
        amount: amount ? parseFloat(amount) : undefined,
        unit: (amount ? unit : undefined) as "ML" | "OZ" | "MINUTES" | "COUNT" | undefined,
        notes: notes || undefined,
        familyOwners: baby.familyOwners as string[],
      });

      router.push(`/baby/${babyId}`);
    } catch (err) {
      console.error("Failed to create log:", err);
      setSaving(false);
    }
  }

  const units = UNIT_OPTIONS[type] ?? [];

  return (
    <div className="page">
      <h1>Add physiology log</h1>
      <div className="card">
        <form onSubmit={handleSubmit}>
          <div className="form-group">
            <label>Type</label>
            <select value={type} onChange={(e) => handleTypeChange(e.target.value)}>
              {LOG_TYPES.map((t) => (
                <option key={t.value} value={t.value}>{t.label}</option>
              ))}
            </select>
          </div>

          <div className="form-row">
            <div className="form-group">
              <label>Start time</label>
              <input
                type="datetime-local"
                value={startTime}
                onChange={(e) => setStartTime(e.target.value)}
                required
              />
            </div>
            <div className="form-group">
              <label>End time (optional)</label>
              <input
                type="datetime-local"
                value={endTime}
                onChange={(e) => setEndTime(e.target.value)}
              />
            </div>
          </div>

          <div className="form-row">
            <div className="form-group">
              <label>Amount (optional)</label>
              <input
                type="number"
                step="any"
                value={amount}
                onChange={(e) => setAmount(e.target.value)}
                placeholder="e.g. 120"
              />
            </div>
            <div className="form-group">
              <label>Unit</label>
              <select value={unit} onChange={(e) => setUnit(e.target.value)}>
                {units.map((u) => (
                  <option key={u.value} value={u.value}>{u.label}</option>
                ))}
              </select>
            </div>
          </div>

          <div className="form-group">
            <label>Notes (optional)</label>
            <textarea
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
              placeholder="Any observations..."
            />
          </div>

          <div style={{ display: "flex", gap: "0.5rem" }}>
            <button type="submit" className="btn" disabled={saving}>
              {saving ? "Saving..." : "Save log"}
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
