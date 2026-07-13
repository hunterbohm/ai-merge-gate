// The same handler, fixed. The client gets a safe message + a request id to
// quote in a support ticket; the full error stays in your logs, tagged with the
// same request id so you can actually find it. ai-merge-gate passes this file.

import express from "express";
import { randomUUID } from "node:crypto";

const app = express();

// attach a correlation id to every request
app.use((req, _res, next) => { req.requestId = req.get("x-request-id") || randomUUID(); next(); });

app.post("/api/charge", async (req, res) => {
  try {
    const result = await chargeCard(req.body);
    res.json(result);
  } catch (err) {
    // log the real error internally, tagged with the request id
    logger.error({ requestId: req.requestId, msg: "charge failed", err });
    // give the caller a safe message + the id to reference — never the stack
    res.status(500).json({ error: "Something went wrong.", requestId: req.requestId });
  }
});

export default app;
