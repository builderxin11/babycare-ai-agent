"use client";

import { Amplify } from "aws-amplify";
import { generateClient } from "aws-amplify/data";
import type { Schema } from "$amplify/data/resource";
import outputs from "@/amplify_outputs.json";

Amplify.configure(outputs, { ssr: true });

export const client = generateClient<Schema>();
