const express = require("express");
const cors    = require("cors");
const path    = require("path");
const db      = require("./config/db");

const authRoutes     = require("./routes/auth");
const donationRoutes = require("./routes/donations");

const app = express();

app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, "public")));

app.use("/api/auth",      authRoutes);
app.use("/api/donations", donationRoutes);

app.get("/", (req, res) => {
    res.redirect("/login.html");
});

db.initialize()
    .then(() => {
        app.listen(8080, () => {
            console.log("Server running on http://localhost:8080");
        });
    })
    .catch(err => {
        console.error("Failed to connect to Oracle DB:", err);
        process.exit(1);
    });
