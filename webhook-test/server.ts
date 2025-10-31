import express, { Request, Response } from "express";

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware to parse JSON bodies
app.use(express.json());

// Webhook route
app.post("/webhook", (req: Request, res: Response) => {
    console.log("Webhook received at:", new Date().toISOString());
    console.log("Headers:", req.headers);
    console.log("Body:", JSON.stringify(req.body, null, 2));

    // Send success response
    res.status(200).json({
        success: true,
        message: "Webhook received successfully",
        timestamp: new Date().toISOString(),
    });
});

// Health check route
app.get("/health", (req: Request, res: Response) => {
    res.status(200).json({ status: "ok" });
});

// Start server
app.listen(PORT, () => {
    console.log(`Webhook test server running on http://localhost:${PORT}`);
    console.log(`Webhook endpoint: http://localhost:${PORT}/webhook`);
});
