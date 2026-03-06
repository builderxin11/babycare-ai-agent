"use client";

import { useState, useEffect, useCallback } from "react";
import { getCurrentUser } from "aws-amplify/auth";
import { client } from "@/lib/amplify-utils";
import Link from "next/link";

type Baby = {
  id: string;
  name: string;
  birthDate: string;
  gender: string | null;
  notes: string | null;
};

type Family = {
  id: string;
  familyName: string | null;
  owners: (string | null)[] | null;
};

export default function Dashboard() {
  const [family, setFamily] = useState<Family | null>(null);
  const [babies, setBabies] = useState<Baby[]>([]);
  const [loading, setLoading] = useState(true);
  const [showCreateFamily, setShowCreateFamily] = useState(false);
  const [showAddBaby, setShowAddBaby] = useState(false);

  // Family form
  const [familyName, setFamilyName] = useState("");

  // Baby form
  const [babyName, setBabyName] = useState("");
  const [birthDate, setBirthDate] = useState("");
  const [gender, setGender] = useState("OTHER");

  const loadData = useCallback(async () => {
    try {
      const user = await getCurrentUser();
      const userSub = user.userId;

      // Try to find existing family
      const { data: families } = await client.models.Family.list();
      const myFamily = families.find(
        (f) => f.owners && f.owners.includes(userSub)
      );

      if (myFamily) {
        setFamily(myFamily as Family);
        const { data: babyList } = await client.models.Baby.list({
          filter: { familyId: { eq: myFamily.id } },
        });
        setBabies(babyList as Baby[]);
      } else {
        setShowCreateFamily(true);
      }
    } catch (err) {
      console.error("Failed to load data:", err);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadData();
  }, [loadData]);

  async function handleCreateFamily(e: React.FormEvent) {
    e.preventDefault();
    try {
      const user = await getCurrentUser();
      const { data: newFamily } = await client.models.Family.create({
        familyName,
        owners: [user.userId],
      });
      if (newFamily) {
        setFamily(newFamily as Family);
        setShowCreateFamily(false);
        setFamilyName("");
      }
    } catch (err) {
      console.error("Failed to create family:", err);
    }
  }

  async function handleAddBaby(e: React.FormEvent) {
    e.preventDefault();
    if (!family) return;
    try {
      const { data: newBaby } = await client.models.Baby.create({
        familyId: family.id,
        name: babyName,
        birthDate,
        gender: gender as "MALE" | "FEMALE" | "OTHER",
        familyOwners: family.owners as string[],
      });
      if (newBaby) {
        setBabies((prev) => [...prev, newBaby as Baby]);
        setShowAddBaby(false);
        setBabyName("");
        setBirthDate("");
        setGender("OTHER");
      }
    } catch (err) {
      console.error("Failed to add baby:", err);
    }
  }

  function calculateAgeMonths(birthDateStr: string): number {
    const birth = new Date(birthDateStr);
    const now = new Date();
    return (now.getFullYear() - birth.getFullYear()) * 12 + (now.getMonth() - birth.getMonth());
  }

  if (loading) {
    return (
      <div className="page">
        <div className="empty-state"><span className="spinner" /></div>
      </div>
    );
  }

  if (showCreateFamily) {
    return (
      <div className="page">
        <h1>Welcome to NurtureMind</h1>
        <div className="card">
          <h3>Create your family</h3>
          <p style={{ marginBottom: "1rem" }}>Get started by setting up your family profile.</p>
          <form onSubmit={handleCreateFamily}>
            <div className="form-group">
              <label>Family name</label>
              <input
                type="text"
                value={familyName}
                onChange={(e) => setFamilyName(e.target.value)}
                placeholder="e.g. The Smiths"
                required
              />
            </div>
            <button type="submit" className="btn">Create family</button>
          </form>
        </div>
      </div>
    );
  }

  return (
    <div className="page">
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "1.5rem" }}>
        <h1 style={{ marginBottom: 0 }}>
          {family?.familyName ?? "My Family"}
        </h1>
        <button className="btn" onClick={() => setShowAddBaby(true)}>
          + Add baby
        </button>
      </div>

      {showAddBaby && (
        <div className="card" style={{ marginBottom: "1.5rem" }}>
          <h3>Add a baby</h3>
          <form onSubmit={handleAddBaby}>
            <div className="form-row">
              <div className="form-group">
                <label>Name</label>
                <input
                  type="text"
                  value={babyName}
                  onChange={(e) => setBabyName(e.target.value)}
                  required
                />
              </div>
              <div className="form-group">
                <label>Birth date</label>
                <input
                  type="date"
                  value={birthDate}
                  onChange={(e) => setBirthDate(e.target.value)}
                  required
                />
              </div>
              <div className="form-group">
                <label>Gender</label>
                <select value={gender} onChange={(e) => setGender(e.target.value)}>
                  <option value="MALE">Male</option>
                  <option value="FEMALE">Female</option>
                  <option value="OTHER">Other</option>
                </select>
              </div>
            </div>
            <div style={{ display: "flex", gap: "0.5rem" }}>
              <button type="submit" className="btn">Save</button>
              <button type="button" className="btn btn-secondary" onClick={() => setShowAddBaby(false)}>
                Cancel
              </button>
            </div>
          </form>
        </div>
      )}

      {babies.length === 0 ? (
        <div className="empty-state">
          <p>No babies yet. Add one to get started.</p>
        </div>
      ) : (
        babies.map((baby) => (
          <div className="card" key={baby.id}>
            <h3>{baby.name}</h3>
            <p>
              {calculateAgeMonths(baby.birthDate)} months old
              {baby.gender ? ` · ${baby.gender.toLowerCase()}` : ""}
            </p>
            <div className="link-row">
              <Link href={`/baby/${baby.id}`} className="btn btn-secondary" style={{ fontSize: "0.8rem", padding: "0.3rem 0.6rem" }}>
                View details
              </Link>
              <Link href={`/baby/${baby.id}/log`} className="btn btn-secondary" style={{ fontSize: "0.8rem", padding: "0.3rem 0.6rem" }}>
                + Log
              </Link>
              <Link href={`/baby/${baby.id}/event`} className="btn btn-secondary" style={{ fontSize: "0.8rem", padding: "0.3rem 0.6rem" }}>
                + Event
              </Link>
            </div>
          </div>
        ))
      )}
    </div>
  );
}
