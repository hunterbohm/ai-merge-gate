// Example of what an AI agent ships when it "handles" errors. Both smells live here:
//   1. the raw error + stack go straight back to the client
//   2. nothing tags a log line to a single call, so prod logs are a guessing game
// ai-merge-gate's scanners are meant to FLAG this file. See ../run-demo.sh.

import express from "express";
const app = express();

app.post("/api/charge", async (req, res) => {
  try {
    const result = await chargeCard(req.body); // pretend this can throw
    res.json(result);
  } catch (err) {
    // leak: internal stack trace handed to the caller
    res.status(500).json({ error: err.stack });
    console.error(err.stack);
  }
});

export default app;
