const express = require("express");
const cors = require("cors");
const path = require("path");

const authRoutes = require("./routes/auth");
const donationRoutes = require("./routes/donations");

const app = express();

app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, "public")));

// Routes
app.use("/api/auth", authRoutes);
app.use("/api/donations", donationRoutes);

// Redirect root to login page
app.get("/", (req, res) => {
    res.redirect("/login.html");
});

app.listen(8080, () => {
    console.log("Server running on http://localhost:8080");
});
