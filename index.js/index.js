const express = require('express');
const bodyParser = require('body-parser');

const app = express();
const port = process.env.PORT || 3000;

app.use(bodyParser.json());

// Endpoint to optimize text
app.post('/optimize-text', (req, res) => {
    const { text, audience } = req.body;

    if (!text || !audience) {
        return res.status(400).json({ error: 'Text and audience are required.' });
    }

    // Simulate text optimization (replace this with your actual logic)
    const optimizedText = `Optimized text for ${audience}: ${text}`;

    res.json({ optimizedText });
});

// Endpoint to get available audiences
app.get('/get-audiences', (req, res) => {
    const audiences = ["general-public", "medical-professionals", "children"];
    res.json({ audiences });
});

// Health check endpoint
app.get('/status', (req, res) => {
    res.json({ status: 'API is running' });
});

// Start the server
app.listen(port, () => {
    console.log(`API running on port ${port}`);
});
