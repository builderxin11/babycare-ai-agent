import { type ClientSchema, a, defineData } from "@aws-amplify/backend";

const schema = a.schema({
  /**
   * Family — The sharing unit that ties two parents together.
   * Both parents' Cognito user subs go into `owners` for multi-tenant access.
   */
  Family: a
    .model({
      familyName: a.string(),
      owners: a.string().array(),
      babies: a.hasMany("Baby", "familyId"),
    })
    .authorization((allow) => [allow.ownersDefinedIn("owners")]),

  /**
   * Baby — Profile for each child.
   * Authorization inherited via denormalized `familyOwners` from Family.
   */
  Baby: a
    .model({
      familyId: a.id().required(),
      name: a.string().required(),
      birthDate: a.date().required(),
      gender: a.enum(["MALE", "FEMALE", "OTHER"]),
      notes: a.string(),
      family: a.belongsTo("Family", "familyId"),
      familyOwners: a.string().array(),
      physiologyLogs: a.hasMany("PhysiologyLog", "babyId"),
      contextEvents: a.hasMany("ContextEvent", "babyId"),
    })
    .authorization((allow) => [allow.ownersDefinedIn("familyOwners")]),

  /**
   * PhysiologyLog — Time-series routine data (feeding, sleep, diaper).
   * GSI on babyId + startTime enables efficient trend queries for the Data Scientist Agent.
   */
  PhysiologyLog: a
    .model({
      babyId: a.id().required(),
      familyOwners: a.string().array(),
      type: a.enum([
        "MILK_BREAST",
        "MILK_FORMULA",
        "MILK_SOLID",
        "SLEEP",
        "DIAPER_WET",
        "DIAPER_DIRTY",
      ]),
      startTime: a.datetime().required(),
      endTime: a.datetime(),
      amount: a.float(),
      unit: a.enum(["ML", "OZ", "MINUTES", "COUNT"]),
      notes: a.string(),
      baby: a.belongsTo("Baby", "babyId"),
    })
    .secondaryIndexes((index) => [
      index("babyId").sortKeys(["startTime"]),
    ])
    .authorization((allow) => [allow.ownersDefinedIn("familyOwners")]),

  /**
   * ContextEvent — Non-routine events that affect trends (vaccines, travel, etc.).
   * GSI on babyId + startDate for time-range lookups.
   */
  ContextEvent: a
    .model({
      babyId: a.id().required(),
      familyOwners: a.string().array(),
      type: a.enum([
        "VACCINE",
        "TRAVEL",
        "JET_LAG",
        "ILLNESS",
        "MILESTONE",
        "OTHER",
      ]),
      title: a.string().required(),
      startDate: a.date().required(),
      endDate: a.date(),
      metadata: a.json(),
      notes: a.string(),
      baby: a.belongsTo("Baby", "babyId"),
    })
    .secondaryIndexes((index) => [
      index("babyId").sortKeys(["startDate"]),
    ])
    .authorization((allow) => [allow.ownersDefinedIn("familyOwners")]),

  /**
   * AgentSession — Tracks AI agent interactions.
   * References LangGraph checkpoints stored in DynamoDB.
   */
  AgentSession: a
    .model({
      babyId: a.id().required(),
      familyOwners: a.string().array(),
      sessionType: a.enum([
        "DATA_ANALYSIS",
        "MEDICAL_ADVICE",
        "SOCIAL_SEARCH",
        "GENERAL",
      ]),
      status: a.enum(["ACTIVE", "COMPLETED", "INTERRUPTED"]),
      langgraphCheckpointId: a.string(),
      summary: a.string(),
      confidenceScore: a.float(),
      createdAt: a.datetime(),
    })
    .authorization((allow) => [allow.ownersDefinedIn("familyOwners")]),
});

export type Schema = ClientSchema<typeof schema>;

export const data = defineData({
  schema,
  authorizationModes: {
    defaultAuthorizationMode: "userPool",
  },
});
