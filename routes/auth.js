const express = require("express");
const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const db = require("../config/db");
const { JWT_SECRET } = require("../middleware/auth");

const router = express.Router();

// Register
router.post("/register", async (req, res) => {
    const { username, password, role, restaurantName } = req.body;

    if (!username || !password || !role) {
        return res.status(400).json({ message: "All fields are required" });
    }

    if (!["restaurant", "ngo"].includes(role)) {
        return res.status(400).json({ message: "Role must be 'restaurant' or 'ngo'" });
    }

    if (role === "restaurant" && !restaurantName) {
        return res.status(400).json({ message: "Restaurant name is required for restaurant accounts" });
    }

    const hashedPassword = await bcrypt.hash(password, 10);

    const sql = "INSERT INTO users (username, password, role, restaurant_name) VALUES (?, ?, ?, ?)";
    db.query(sql, [username, hashedPassword, role, restaurantName || null], (err, result) => {
        if (err) {
            if (err.code === "ER_DUP_ENTRY") {
                return res.status(409).json({ message: "Username already exists" });
            }
            return res.status(500).json({ message: "Server error" });
        }

        const token = jwt.sign(
            { id: result.insertId, username, role, restaurantName: restaurantName || null },
            JWT_SECRET,
            { expiresIn: "24h" }
        );

        res.json({ token, role, restaurantName: restaurantName || null });
    });
});

// Login
router.post("/login", (req, res) => {
    const { username, password } = req.body;

    if (!username || !password) {
        return res.status(400).json({ message: "All fields are required" });
    }

    const sql = "SELECT * FROM users WHERE username = ?";
    db.query(sql, [username], async (err, results) => {
        if (err) return res.status(500).json({ message: "Server error" });

        if (results.length === 0) {
            return res.status(401).json({ message: "Invalid username or password" });
        }

        const user = results[0];
        const isMatch = await bcrypt.compare(password, user.password);

        if (!isMatch) {
            return res.status(401).json({ message: "Invalid username or password" });
        }

        const token = jwt.sign(
            { id: user.id, username: user.username, role: user.role, restaurantName: user.restaurant_name || null },
            JWT_SECRET,
            { expiresIn: "24h" }
        );

        res.json({ token, role: user.role, restaurantName: user.restaurant_name || null });
    });
});

module.exports = router;
